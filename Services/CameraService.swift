import AVFoundation
import Vision
import Combine

class CameraService: NSObject, ObservableObject {
    @Published var captureSession = AVCaptureSession()
    @Published var isRunning = false
    @Published var hasError = false
    @Published var errorMessage = ""
    
    private var captureDevice: AVCaptureDevice?
    private var videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // Gelişmiş odaklama sistemi - background thread'de çalışacak
    private var autoFocusTimer: Timer?
    private var currentFocusZone = 0
    private let focusZones: [CGPoint] = [
        CGPoint(x: 0.5, y: 0.5),   // Merkez
        CGPoint(x: 0.35, y: 0.4),  // Sol üst
        CGPoint(x: 0.65, y: 0.4),  // Sağ üst
        CGPoint(x: 0.35, y: 0.6),  // Sol alt
        CGPoint(x: 0.65, y: 0.6)   // Sağ alt
    ]
    
    // Ses sistemi
    private var audioPlayer: AVAudioPlayer?
    
    weak var delegate: CameraServiceDelegate?
    
    override init() {
        super.init()
        setupAudioPlayer()
        setupCamera()
    }
    
    private func setupAudioPlayer() {
        guard let soundURL = Bundle.main.url(forResource: "beep", withExtension: "mp3") else {
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 0.8
        } catch {
            // Ses dosyası yüklenemedi, sessiz çalışacak
        }
    }
    
    func playBeepSound() {
        DispatchQueue.main.async { [weak self] in
            self?.audioPlayer?.stop()
            self?.audioPlayer?.currentTime = 0
            self?.audioPlayer?.play()
        }
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureCaptureSession()
        }
    }
    
    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        
        // En iyi kalite için session preset ayarla
        if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
        }
        
        // Kamera cihazını seç
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            setError("Kamera bulunamadı")
            return
        }
        
        captureDevice = device
        
        do {
            // Kamera girişini ayarla
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            // Video çıkışını ayarla - barkod tarama için optimize
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output.queue"))
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            
            // Gelişmiş kamera optimizasyonları
            try device.lockForConfiguration()
            
            // Sürekli otomatik odaklama (en iyi barkod tarama performansı)
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Otomatik pozlama
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // Beyaz dengesi
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            // Video stabilizasyon (destekleniyorsa)
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
            
            // ISO ve shutter speed optimizasyonu (barkod okuma için)
            if device.isExposureModeSupported(.custom) {
                // Orta düzey ISO (gürültü vs netlik dengesi)
                let minISO = device.activeFormat.minISO
                let maxISO = device.activeFormat.maxISO
                let targetISO = min(maxISO, max(minISO, 400))
                
                // Hızlı shutter (hareket bulanıklığını önler)
                let minDuration = device.activeFormat.minExposureDuration
                let maxDuration = device.activeFormat.maxExposureDuration
                let targetDuration = CMTimeMake(value: 1, timescale: 120) // 1/120 saniye
                
                let clampedDuration = CMTimeClampToRange(targetDuration, range: CMTimeRangeFromTimeToTime(start: minDuration, end: maxDuration))
                
                device.setExposureModeCustom(duration: clampedDuration, iso: targetISO, completionHandler: nil)
            }
            
            device.unlockForConfiguration()
            
        } catch {
            setError("Kamera yapılandırılamadı: \(error.localizedDescription)")
            return
        }
        
        captureSession.commitConfiguration()
    }
    
    func startRunning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                
                DispatchQueue.main.async {
                    self.isRunning = true
                }
                
                // AutoFocus'u background thread'de başlat
                self.startAdvancedAutoFocus()
            }
        }
    }
    
    func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Önce AutoFocus'u durdur
            self.stopAdvancedAutoFocus()
            
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }
    
    private func startAdvancedAutoFocus() {
        // Bu metod sessionQueue'da çalışıyor (background thread)
        stopAdvancedAutoFocus() // Önceki timer'ı temizle
        
        // İlk odaklama merkez noktada
        focusAt(point: focusZones[0])
        
        // Timer'ı background thread'de oluştur
        autoFocusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.performMultiZoneFocus()
        }
        
        // Timer'ı current run loop'a ekle
        if let timer = autoFocusTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopAdvancedAutoFocus() {
        // Bu metod sessionQueue'da çalışıyor
        autoFocusTimer?.invalidate()
        autoFocusTimer = nil
    }
    
    private func performMultiZoneFocus() {
        // Bu metod timer callback'i olarak background thread'de çalışıyor
        guard let device = captureDevice else { return }
        
        currentFocusZone = (currentFocusZone + 1) % focusZones.count
        let focusPoint = focusZones[currentFocusZone]
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
                device.focusPointOfInterest = focusPoint
            }
            
            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
                device.exposurePointOfInterest = focusPoint
            }
            
            device.unlockForConfiguration()
            
        } catch {
            // Sessizce devam et
        }
    }
    
    func toggleFlash() -> Bool {
        guard let device = captureDevice, device.hasTorch else { return false }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .off {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            
            device.unlockForConfiguration()
            return device.torchMode == .on
            
        } catch {
            setError("Flash ayarlanamadı: \(error.localizedDescription)")
            return false
        }
    }
    
    func focusAt(point: CGPoint) {
        // Bu metod herhangi bir thread'den çağrılabilir
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.captureDevice else { return }
            
            do {
                try device.lockForConfiguration()
                
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                    device.focusPointOfInterest = point
                }
                
                if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                    device.exposurePointOfInterest = point
                }
                
                device.unlockForConfiguration()
                
            } catch {
                self.setError("Odaklama ayarlanamadı: \(error.localizedDescription)")
            }
        }
    }
    
    private func setError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.hasError = true
        }
    }
    
    deinit {
        stopAdvancedAutoFocus()
        stopRunning()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        delegate?.cameraService(self, didCapture: pixelBuffer)
    }
}

// MARK: - CameraServiceDelegate
protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didCapture pixelBuffer: CVPixelBuffer)
} 
