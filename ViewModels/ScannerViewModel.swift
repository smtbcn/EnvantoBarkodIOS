import SwiftUI
import AVFoundation
import Vision
import AudioToolbox

class ScannerViewModel: NSObject, ObservableObject {
    @Published var isFlashOn = false
    @Published var isAutoFocusing = false
    @Published var scannedBarcode = ""
    @Published var scannerLineOffset: CGFloat = -140
    // Android logic: finish() gibi - ScannerView'ı kapat ve external browser aç
    @Published var shouldDismissToMain = false
    @Published var showWebBrowser = false
    @Published var currentURL = ""
    
    let captureSession = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var captureDevice: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    private var lastScanTime: Date = Date()
    private let scanCooldown: TimeInterval = 2.0 // 2 saniye bekleme süresi
    
    // Pil optimizasyonu için frame skipping
    private var frameCounter = 0
    private var frameSkipInterval = 3 // Dinamik olarak ayarlanacak
    
    override init() {
        super.init()
        setupCamera()
        setupScannerAnimation()
        setupBackgroundObservers()
        updateFrameSkipInterval() // İlk değeri ayarla
    }
    
    private func setupBackgroundObservers() {
        // Pil izlemeyi başlat
        BatteryOptimizer.shared.startBatteryMonitoring()
        
        // Uygulama arka plana geçtiğinde kamerayı durdur
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopScanning()
        }
        
        // Uygulama ön plana geçtiğinde kamerayı başlat
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.startScanning()
            }
        }
        
        // Pil seviyesi değiştiğinde frame skip interval'ı güncelle
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateFrameSkipInterval()
        }
    }
    
    private func updateFrameSkipInterval() {
        frameSkipInterval = BatteryOptimizer.shared.getOptimalScanInterval()
        print("🔋 Frame skip interval güncellendi: \(frameSkipInterval)")
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("🔧 [ScannerViewModel] Kamera kurulumu başlıyor")
            
            self.captureSession.beginConfiguration()
            
            // Kamera cihazını ayarla
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ [ScannerViewModel] Kamera cihazı bulunamadı")
                return
            }
            
            self.captureDevice = device
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    print("✅ [ScannerViewModel] Kamera input eklendi")
                }
            } catch {
                print("❌ [ScannerViewModel] Kamera input hatası: \(error)")
                return
            }
            
            // Video output'u ayarla
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output.queue"))
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
                print("✅ [ScannerViewModel] Video output eklendi")
            }
            
            self.captureSession.commitConfiguration()
            print("✅ [ScannerViewModel] Kamera kurulumu tamamlandı")
        }
    }
    
    // Kamera session'ını yeniden kur (crash durumunda)
    private func reconfigureCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("🔄 [ScannerViewModel] Kamera yeniden yapılandırılıyor")
            
            // Önce mevcut session'ı temizle
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            
            // Tüm input ve output'ları kaldır
            for input in self.captureSession.inputs {
                self.captureSession.removeInput(input)
            }
            
            for output in self.captureSession.outputs {
                self.captureSession.removeOutput(output)
            }
            
            // Video output'u yeniden oluştur
            self.videoOutput = AVCaptureVideoDataOutput()
            
            // Kamerayı yeniden kur
            self.setupCamera()
        }
    }
    
    private func setupScannerAnimation() {
        // Scanner çizgisi animasyonunu başlat
        DispatchQueue.main.async {
            self.scannerLineOffset = 140
        }
    }
    
    func startScanning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("🎥 [ScannerViewModel] startScanning çağrıldı - Session running: \(self.captureSession.isRunning)")
            
            // Session'ın input/output'larını kontrol et
            if self.captureSession.inputs.isEmpty || self.captureSession.outputs.isEmpty {
                print("⚠️ [ScannerViewModel] Session input/output eksik, yeniden yapılandırılıyor")
                self.reconfigureCamera()
                
                // Yeniden yapılandırma sonrası başlat
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startScanning()
                }
                return
            }
            
            // Güvenli başlatma: Session'ın durumunu kontrol et
            if !self.captureSession.isRunning {
                // Video output delegate'ini yeniden ayarla
                self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output.queue"))
                
                // Session'ı başlat
                self.captureSession.startRunning()
                print("✅ [ScannerViewModel] Kamera session başlatıldı")
            } else {
                print("ℹ️ [ScannerViewModel] Kamera session zaten çalışıyor")
            }
        }
    }
    
    func stopScanning() {
        print("🛑 [ScannerViewModel] stopScanning çağrıldı - Session running: \(captureSession.isRunning)")
        
        // Video output delegate'ini hemen temizle (hızlı)
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        
        // Session durdurma işlemini arka planda yap
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Güvenli durdurma: Session'ın durumunu kontrol et
            if self.captureSession.isRunning {
                // iOS'un internal process'lerinin hazır olması için kısa bekleme
                Thread.sleep(forTimeInterval: 0.05)
                
                self.captureSession.stopRunning()
                print("✅ [ScannerViewModel] Kamera session durduruldu")
                
                // Cleanup için ek bekleme
                Thread.sleep(forTimeInterval: 0.05)
            } else {
                print("ℹ️ [ScannerViewModel] Kamera session zaten durmuş")
            }
        }
    }
    
    func toggleFlash() {
        guard let device = captureDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if isFlashOn {
                device.torchMode = .off
            } else {
                device.torchMode = .on
            }
            
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.isFlashOn.toggle()
            }
        } catch {
        }
    }
    
    func resetScanning() {
        print("🔄 [ScannerViewModel] resetScanning çağrıldı")
        
        DispatchQueue.main.async {
            self.scannedBarcode = ""
            self.lastScanTime = Date()
            self.frameCounter = 0 // Frame counter'ı sıfırla
        }
    }
    
    func handleBarcodeDetection(_ barcode: String) {
        // Android'deki beep.mp3 dosyasını çal
        AudioManager.shared.playBeepSound()
        
        // Titreşim
        AudioManager.shared.playVibration()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func openWebsite(with barcodeContent: String) {
        let baseURL = UserDefaults.standard.string(forKey: Constants.UserDefaults.baseURL) ?? Constants.Network.defaultBaseURL
        let fullURL = "\(baseURL)\(barcodeContent)"
        
            DispatchQueue.main.async {
            self.currentURL = fullURL
            self.showWebBrowser = true
        }
    }
    
	
    
    private func performBarcodeDetection(on image: CVPixelBuffer) {
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                return
            }
            
            guard let results = request.results as? [VNBarcodeObservation],
                  let firstBarcode = results.first,
                  let barcodeValue = firstBarcode.payloadStringValue else {
                return
            }
            
            // Cooldown kontrolü
            let now = Date()
            if now.timeIntervalSince(self.lastScanTime) < self.scanCooldown {
                return
            }
            
            self.lastScanTime = now
            
            DispatchQueue.main.async {
                self.scannedBarcode = barcodeValue
            }
        }
        
        // QR kod ve Data Matrix'i destekle
        request.symbologies = [.qr, .dataMatrix]
        
        let handler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
        }
    }
    
    deinit {
        print("🗑️ [ScannerViewModel] deinit çağrıldı")
        
        // Observer'ları hemen temizle (main thread'de güvenli)
        NotificationCenter.default.removeObserver(self)
        
        // Pil izlemeyi durdur (main thread'de güvenli)
        BatteryOptimizer.shared.stopBatteryMonitoring()
        
        // Ağır işlemleri arka planda yap - main thread'i bloklamayacak şekilde
        let session = captureSession
        let videoOutput = self.videoOutput
        
        DispatchQueue.global(qos: .background).async {
            print("🧹 [ScannerViewModel] Arka planda temizlik başlıyor")
            
            // Video output delegate'ini temizle
            videoOutput.setSampleBufferDelegate(nil, queue: nil)
            
            // Session'ı daha nazik şekilde durdur
            if session.isRunning {
                session.stopRunning()
                print("🛑 [ScannerViewModel] Session durduruldu")
                
                // iOS'un internal cleanup'ı için kısa bekleme
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            // Input ve output'ları daha nazik şekilde temizle
            session.beginConfiguration()
            
            for input in session.inputs {
                session.removeInput(input)
            }
            
            for output in session.outputs {
                session.removeOutput(output)
            }
            
            session.commitConfiguration()
            
            print("✅ [ScannerViewModel] Temizlik tamamlandı")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension ScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Pil optimizasyonu: Her frame'i işleme, sadece belirli aralıklarla
        frameCounter += 1
        if frameCounter % frameSkipInterval != 0 {
            return
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        performBarcodeDetection(on: pixelBuffer)
    }
} 
