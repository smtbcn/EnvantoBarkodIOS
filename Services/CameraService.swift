import AVFoundation
import Vision
import Combine
import UIKit
import Foundation

class CameraService: NSObject, ObservableObject {
    @Published var captureSession = AVCaptureSession()
    @Published var isRunning = false
    @Published var hasError = false
    @Published var errorMessage = ""
    
    private var captureDevice: AVCaptureDevice?
    private var videoOutput = AVCaptureVideoDataOutput()
    private var photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // YENİ: Orientation tracking için
    internal var deviceOrientation: UIDeviceOrientation = .portrait
    private var orientationObserver: NSObjectProtocol?
    
    weak var delegate: CameraServiceDelegate?
    
    override init() {
        super.init()
        setupCamera()
        setupOrientationTracking()
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureCaptureSession()
        }
    }
    
    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        
        // Pil optimizasyonu: Orta çözünürlük kullan
        if captureSession.canSetSessionPreset(.medium) {
            captureSession.sessionPreset = .medium
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
            
            // Video çıkışını ayarla
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output.queue"))
            
            // Pil optimizasyonu: Frame rate'i düşür
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            
            // YENİ: Photo output ekle
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
            
            // Kamera ayarlarını optimize et
            try device.lockForConfiguration()
            
            device.unlockForConfiguration()
            
            // Pil optimizasyonu: Akıllı ayarlar
            BatteryOptimizer.shared.optimizeCameraSettings(for: device)
            
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
        
        // Orientation observer'ı temizle
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Device orientation notifications'ı durdur
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    // MARK: - Orientation Tracking
    
    private func setupOrientationTracking() {
        // Device orientation notifications'ı etkinleştir
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // Device orientation değişikliklerini dinle
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleOrientationChange()
        }
        
        // İlk orientation değerini al
        updateDeviceOrientation()
    }
    
    private func handleOrientationChange() {
        updateDeviceOrientation()
        updateCameraOrientation()
    }
    
    private func updateDeviceOrientation() {
        let newOrientation = UIDevice.current.orientation
        
        // Sadece valid orientation'ları kabul et
        if newOrientation != .unknown && newOrientation != .faceUp && newOrientation != .faceDown {
            deviceOrientation = newOrientation
            print("📱 [CameraService] Device orientation güncellendi: \(getOrientationName(deviceOrientation))")
        } else {
            print("⚠️ [CameraService] Invalid orientation ignored: \(getOrientationName(newOrientation))")
        }
    }
    
    private func updateCameraOrientation() {
        guard let connection = photoOutput.connection(with: .video) else { return }
        
        // Video orientation'ı güncelle
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = getVideoOrientation(from: deviceOrientation)
            print("📷 Camera orientation güncellendi: \(connection.videoOrientation)")
        }
    }
    
    private func getVideoOrientation(from deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch deviceOrientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return .portrait
        }
    }
    
    private func getOrientationName(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait: return "PORTRAIT (0°)"
        case .landscapeLeft: return "LANDSCAPE_LEFT (90°)"
        case .portraitUpsideDown: return "PORTRAIT_UPSIDE_DOWN (180°)"
        case .landscapeRight: return "LANDSCAPE_RIGHT (270°)"
        default: return "UNKNOWN"
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto(completion: @escaping (URL?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Photo settings oluştur
            let photoSettings = AVCapturePhotoSettings()
            
            // Orientation ayarlarını ekle
            if let connection = self.photoOutput.connection(with: .video) {
                connection.videoOrientation = self.getVideoOrientation(from: self.deviceOrientation)
            }
            
            // Delegate ile resim çek
            let captureDelegate = PhotoCaptureDelegate(completion: completion, cameraService: self)
            self.photoOutput.capturePhoto(with: photoSettings, delegate: captureDelegate)
        }
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

// MARK: - Photo Capture Delegate
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (URL?) -> Void
    private weak var cameraService: CameraService?
    
    init(completion: @escaping (URL?) -> Void, cameraService: CameraService) {
        self.completion = completion
        self.cameraService = cameraService
        super.init()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard error == nil else {
            print("❌ Resim çekme hatası: \(error!)")
            DispatchQueue.main.async { self.completion(nil) }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ Image data alınamadı")
            DispatchQueue.main.async { self.completion(nil) }
            return
        }
        
        // Geçici dosya oluştur
        let tempURL = createTempImageFile()
        
        do {
            try imageData.write(to: tempURL)
            
            // Arka planda orientation düzeltmesi yap
            DispatchQueue.global(qos: .userInitiated).async {
                self.processImageOrientation(at: tempURL.path)
            }
            
        } catch {
            print("❌ Resim kaydetme hatası: \(error)")
            DispatchQueue.main.async { self.completion(nil) }
        }
    }
    
    private func createTempImageFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "temp_camera_\(UUID().uuidString).jpg"
        return tempDir.appendingPathComponent(fileName)
    }
    
    private func processImageOrientation(at imagePath: String) {
        print("🔄 Resim orientation işleniyor: \(imagePath)")
        
        // Android mantığı ile orientation düzeltmesi
        guard let cameraService = self.cameraService else {
            print("❌ CameraService referansı bulunamadı")
            DispatchQueue.main.async { self.completion(URL(fileURLWithPath: imagePath)) }
            return
        }
        
        let fixedPath = ImageOrientationUtils.fixImageOrientationWithDeviceOrientation(
            imagePath: imagePath, 
            deviceOrientation: cameraService.deviceOrientation
        )
        
        // Ana thread'de sonucu döndür
        DispatchQueue.main.async {
            self.completion(URL(fileURLWithPath: fixedPath))
        }
    }
    
    private func needsManualRotation() -> Bool {
        // Her durumda manuel kontrol yap (AVFoundation bazen orientation'ı doğru ayarlamıyor)
        return true
    }
    
    private func applyManualRotation(imagePath: String) {
        guard let image = UIImage(contentsOfFile: imagePath) else { return }
        
        let imageSize = image.size
        let isImageLandscape = imageSize.width > imageSize.height
        let deviceOrientation = UIDevice.current.orientation
        
        print("📐 Resim boyutları: \(imageSize.width)x\(imageSize.height) (landscape: \(isImageLandscape))")
        
        var shouldRotate = false
        var rotationAngle: CGFloat = 0
        
        switch deviceOrientation {
        case .portrait:
            // Cihaz portrait, resim landscape ise 90° döndür
            if isImageLandscape {
                shouldRotate = true
                rotationAngle = 90
            }
        case .landscapeLeft:
            // Cihaz landscape left, resim portrait ise 270° döndür
            if !isImageLandscape {
                shouldRotate = true
                rotationAngle = 270
            }
        case .portraitUpsideDown:
            // Cihaz upside down, resim landscape ise 270° döndür
            if isImageLandscape {
                shouldRotate = true
                rotationAngle = 270
            }
        case .landscapeRight:
            // Cihaz landscape right, resim portrait ise 90° döndür
            if !isImageLandscape {
                shouldRotate = true
                rotationAngle = 90
            }
        default:
            break
        }
        
        if shouldRotate && rotationAngle != 0 {
            print("🔄 Manuel rotation uygulanıyor: \(rotationAngle)°")
            
            let rotatedImage = ImageOrientationUtils.rotateImage(image, angle: rotationAngle)
            
            // Döndürülmüş resmi kaydet
            if let imageData = rotatedImage.jpegData(compressionQuality: 0.9) {
                do {
                    try imageData.write(to: URL(fileURLWithPath: imagePath))
                    print("✅ Manuel rotation başarıyla uygulandı: \(rotationAngle)°")
                } catch {
                    print("❌ Manuel rotation kaydetme hatası: \(error)")
                }
            }
        } else {
            print("ℹ️ Manuel rotation gerekmiyor, resim zaten doğru yönde")
        }
    }
}