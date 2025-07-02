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
    
    override init() {
        super.init()
        setupCamera()
        setupScannerAnimation()
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            
            // Kamera cihazını ayarla
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                return
            }
            
            self.captureDevice = device
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }
            } catch {
                return
            }
            
            // Video output'u ayarla
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output.queue"))
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }
            
            self.captureSession.commitConfiguration()
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
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopScanning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
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
        scannedBarcode = ""
        lastScanTime = Date()
    }
    
    func handleBarcodeDetection(_ barcode: String) {
        // Ses çal
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        AudioServicesPlaySystemSound(1004) // Beep sesi
        
        // Kısa bir titreşim
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
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension ScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        performBarcodeDetection(on: pixelBuffer)
    }
} 
