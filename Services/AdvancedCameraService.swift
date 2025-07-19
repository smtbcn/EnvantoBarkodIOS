import AVFoundation
import UIKit
import CoreMotion

// MARK: - Professional Camera Service
class AdvancedCameraService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isSessionRunning = false
    @Published var isImageStabilizationAvailable = false
    @Published var isFlashAvailable = false
    @Published var isWideAngleAvailable = false
    @Published var isUltraWideAvailable = false
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var maxZoomFactor: CGFloat = 1.0
    @Published var isCapturing = false
    @Published var currentCameraType: CameraType = .wide
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let motionManager = CMMotionManager()
    
    // Device references
    private var wideAngleDevice: AVCaptureDevice?
    private var ultraWideDevice: AVCaptureDevice?
    private var currentDevice: AVCaptureDevice?
    
    // Stabilization
    private var isStabilizationActive = false
    private var lastMotionData: CMAccelerometerData?
    private var stabilizationThreshold: Double = 0.1
    
    // Completion handlers
    private var photoCompletionHandler: ((Result<UIImage, CameraError>) -> Void)?
    
    // MARK: - Camera Types
    enum CameraType: String, CaseIterable {
        case wide = "Wide"
        case ultraWide = "Ultra Wide"
        
        var deviceType: AVCaptureDevice.DeviceType {
            switch self {
            case .wide:
                return .builtInWideAngleCamera
            case .ultraWide:
                return .builtInUltraWideCamera
            }
        }
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    // MARK: - Camera Errors
    enum CameraError: Error, LocalizedError {
        case deviceNotFound
        case inputCreationFailed
        case configurationFailed
        case captureSessionNotRunning
        case imageCreationFailed
        case stabilizationTimeout
        case orientationDetectionFailed
        
        var errorDescription: String? {
            switch self {
            case .deviceNotFound:
                return "Kamera cihazı bulunamadı"
            case .inputCreationFailed:
                return "Kamera girişi oluşturulamadı"
            case .configurationFailed:
                return "Kamera yapılandırması başarısız"
            case .captureSessionNotRunning:
                return "Kamera oturumu çalışmıyor"
            case .imageCreationFailed:
                return "Resim oluşturulamadı"
            case .stabilizationTimeout:
                return "Stabilizasyon zaman aşımı"
            case .orientationDetectionFailed:
                return "Yönelim algılanamadı"
            }
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupAvailableDevices()
        requestPermissions()
    }
    
    deinit {
        stopSession()
        motionManager.stopAccelerometerUpdates()
    }
    
    // MARK: - Setup Methods
    private func setupAvailableDevices() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Wide-angle camera (her iPhone'da var)
            self.wideAngleDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            
            // Ultra-wide camera (iPhone 11+ models)
            if #available(iOS 13.0, *) {
                self.ultraWideDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            }
            
            DispatchQueue.main.async {
                self.isWideAngleAvailable = (self.wideAngleDevice != nil)
                self.isUltraWideAvailable = (self.ultraWideDevice != nil)
                
                // Default to wide-angle
                self.currentDevice = self.wideAngleDevice
                self.updateCameraCapabilities()
            }
        }
    }
    
    private func updateCameraCapabilities() {
        guard let device = currentDevice else { return }
        
        isFlashAvailable = device.hasFlash
        maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 5.0) // Limit to 5x
        
        // Image stabilization availability
        isImageStabilizationAvailable = device.activeFormat.isVideoStabilizationModeSupported(.auto)
    }
    
    private func requestPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupSession()
                } else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Kamera izni gerekli"
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Kamera erişimi reddedildi"
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - Session Management
    private func setupSession() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        
        // Session preset for high quality
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        }
        
        // Configure input
        guard configureCameraInput() else {
            captureSession.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Kamera girişi yapılandırılamadı"
            }
            return
        }
        
        // Configure output
        guard configurePhotoOutput() else {
            captureSession.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Fotoğraf çıkışı yapılandırılamadı"
            }
            return
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = nil
        }
    }
    
    private func configureCameraInput() -> Bool {
        guard let device = currentDevice else { return false }
        
        do {
            // Remove existing input
            if let existingInput = videoDeviceInput {
                captureSession.removeInput(existingInput)
            }
            
            // Add new input
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                videoDeviceInput = input
                
                // Configure device settings
                try device.lockForConfiguration()
                configureDeviceSettings(device)
                device.unlockForConfiguration()
                
                return true
            }
        } catch {
            print("❌ Camera input error: \(error)")
        }
        
        return false
    }
    
    private func configureDeviceSettings(_ device: AVCaptureDevice) {
        // Continuous autofocus
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        
        // Auto exposure
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        
        // Auto white balance
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        
        // Image stabilization if available
        if device.activeFormat.isVideoStabilizationModeSupported(.auto) {
            // Note: This applies to video preview, photo stabilization is different
            print("✅ Video stabilization available")
        }
        
        // Low light boost if available
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = true
        }
    }
    
    private func configurePhotoOutput() -> Bool {
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            
            // Configure photo output settings
            if #available(iOS 13.0, *) {
                photoOutput.maxPhotoQualityPrioritization = .quality
            }
            
            // Enable high resolution capture
            photoOutput.isHighResolutionCaptureEnabled = true
            
            return true
        }
        return false
    }
    
    // MARK: - Session Control
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                
                DispatchQueue.main.async {
                    self.isSessionRunning = self.captureSession.isRunning
                }
                
                // Start motion monitoring for stabilization
                self.startMotionMonitoring()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
                
                // Stop motion monitoring
                self.stopMotionMonitoring()
            }
        }
    }
    
    // MARK: - Camera Switching
    func switchCamera(to type: CameraType) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let targetDevice: AVCaptureDevice?
            
            switch type {
            case .wide:
                targetDevice = self.wideAngleDevice
            case .ultraWide:
                targetDevice = self.ultraWideDevice
            }
            
            guard let device = targetDevice, device != self.currentDevice else { return }
            
            self.captureSession.beginConfiguration()
            
            // Remove current input
            if let input = self.videoDeviceInput {
                self.captureSession.removeInput(input)
            }
            
            // Add new input
            do {
                let newInput = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.videoDeviceInput = newInput
                    self.currentDevice = device
                    
                    // Configure new device
                    try device.lockForConfiguration()
                    self.configureDeviceSettings(device)
                    device.unlockForConfiguration()
                }
            } catch {
                print("❌ Camera switch error: \(error)")
            }
            
            self.captureSession.commitConfiguration()
            
            DispatchQueue.main.async {
                self.currentCameraType = type
                self.currentZoomFactor = 1.0
                self.updateCameraCapabilities()
            }
        }
    }
    
    // MARK: - Motion Monitoring for Stabilization
    private func startMotionMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            self.lastMotionData = data
            self.updateStabilizationStatus(with: data)
        }
    }
    
    private func stopMotionMonitoring() {
        motionManager.stopAccelerometerUpdates()
    }
    
    private func updateStabilizationStatus(with data: CMAccelerometerData) {
        let acceleration = sqrt(pow(data.acceleration.x, 2) + 
                              pow(data.acceleration.y, 2) + 
                              pow(data.acceleration.z, 2))
        
        let deltaAcceleration = abs(acceleration - 1.0) // 1.0 is gravity baseline
        isStabilizationActive = deltaAcceleration < stabilizationThreshold
    }
    
    // MARK: - Zoom Control
    func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.currentDevice else { return }
            
            let clampedFactor = max(1.0, min(factor, self.maxZoomFactor))
            
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedFactor
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.currentZoomFactor = clampedFactor
                }
            } catch {
                print("❌ Zoom error: \(error)")
            }
        }
    }
    
    // MARK: - Focus and Exposure
    func focusAt(point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.currentDevice else { return }
            
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
                print("❌ Focus error: \(error)")
            }
        }
    }
    
    // MARK: - Flash Control
    func toggleFlash() -> Bool {
        guard let device = currentDevice, device.hasFlash else { return false }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .off ? .on : .off
            device.unlockForConfiguration()
            return device.torchMode == .on
        } catch {
            print("❌ Flash error: \(error)")
            return false
        }
    }
    
    // MARK: - Photo Capture with Advanced Features
    func capturePhoto(completion: @escaping (Result<UIImage, CameraError>) -> Void) {
        guard !isCapturing else { 
            completion(.failure(.captureSessionNotRunning))
            return 
        }
        
        guard captureSession.isRunning else {
            completion(.failure(.captureSessionNotRunning))
            return
        }
        
        photoCompletionHandler = completion
        
        sessionQueue.async { [weak self] in
            self?.performPhotoCapture()
        }
    }
    
    private func performPhotoCapture() {
        isCapturing = true
        
        // Wait for stabilization if motion is detected
        if !isStabilizationActive {
            waitForStabilization { [weak self] success in
                if success {
                    self?.executePhotoCapture()
                } else {
                    self?.completeCapture(.failure(.stabilizationTimeout))
                }
            }
        } else {
            executePhotoCapture()
        }
    }
    
    private func waitForStabilization(completion: @escaping (Bool) -> Void) {
        let startTime = Date()
        let maxWaitTime: TimeInterval = 2.0
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.isStabilizationActive {
                timer.invalidate()
                completion(true)
            } else if Date().timeIntervalSince(startTime) > maxWaitTime {
                timer.invalidate()
                completion(false)
            }
        }
        
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private func executePhotoCapture() {
        let settings = AVCapturePhotoSettings()
        
        // High quality capture
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .quality
        }
        
        // Flash configuration
        if let device = currentDevice, device.hasFlash {
            settings.flashMode = device.torchMode == .on ? .on : .off
        }
        
        // Enable high resolution
        settings.isHighResolutionPhotoEnabled = true
        
        // Image stabilization (if available)
        if #available(iOS 14.0, *) {
            settings.isAutoStillImageStabilizationEnabled = true
        }
        
        // Proper orientation handling
        if let connection = photoOutput.connection(with: .video) {
            updateOrientationForConnection(connection)
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func updateOrientationForConnection(_ connection: AVCaptureConnection) {
        let deviceOrientation = UIDevice.current.orientation
        let videoOrientation: AVCaptureVideoOrientation
        
        switch deviceOrientation {
        case .portrait:
            videoOrientation = .portrait
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            videoOrientation = .landscapeRight // Counter-intuitive but correct
        case .landscapeRight:
            videoOrientation = .landscapeLeft  // Counter-intuitive but correct
        default:
            videoOrientation = .portrait
        }
        
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
    }
    
    private func completeCapture(_ result: Result<UIImage, CameraError>) {
        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = false
            self?.photoCompletionHandler?(result)
            self?.photoCompletionHandler = nil
        }
    }
    
    // MARK: - Session Access
    var session: AVCaptureSession {
        return captureSession
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension AdvancedCameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ Photo processing error: \(error)")
            completeCapture(.failure(.imageCreationFailed))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completeCapture(.failure(.imageCreationFailed))
            return
        }
        
        // Apply additional processing if needed
        let processedImage = processImage(image)
        completeCapture(.success(processedImage))
    }
    
    private func processImage(_ image: UIImage) -> UIImage {
        // Here we can add additional image processing
        // such as noise reduction, sharpening, etc.
        return image
    }
} 