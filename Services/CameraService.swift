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
    
    weak var delegate: CameraServiceDelegate?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureCaptureSession()
        }
    }
    
    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        
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
            
            // Video çıkışını ayarla
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output.queue"))
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            
            // Kamera ayarlarını optimize et
            try device.lockForConfiguration()
            
            // Otomatik odaklama
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Otomatik pozlama
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
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
            }
        }
    }
    
    func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }
    
    func toggleFlash() -> Bool {
        guard let device = captureDevice, device.hasTorch else { return false }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .off {
                device.torchMode = .on
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
        guard let device = captureDevice else { return }
        
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
            setError("Odaklama ayarlanamadı: \(error.localizedDescription)")
        }
    }
    
    private func setError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.hasError = true
        }
    }
    
    deinit {
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
