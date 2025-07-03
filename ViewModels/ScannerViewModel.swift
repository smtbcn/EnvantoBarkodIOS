import SwiftUI
import AVFoundation
import Vision
import Combine

class ScannerViewModel: NSObject, ObservableObject {
    @Published var isFlashOn = false
    @Published var isAutoFocusing = false
    @Published var scannedBarcode = ""
    @Published var scannerLineOffset: CGFloat = -140
    // Android logic: finish() gibi - ScannerView'ı kapat ve external browser aç
    @Published var shouldDismissToMain = false
    @Published var showWebBrowser = false
    @Published var currentURL = ""
    
    // Optimize edilmiş servisler
    private let cameraService = CameraService()
    private let barcodeService = BarcodeService()
    private var cancellables = Set<AnyCancellable>()
    
    private var lastScanTime: Date = Date()
    private let scanCooldown: TimeInterval = 2.0 // 2 saniye bekleme süresi
    
    override init() {
        super.init()
        setupServices()
        setupScannerAnimation()
    }
    
    private func setupServices() {
        // CameraService ile BarcodeService'i bağla
        cameraService.delegate = self
        barcodeService.cameraService = cameraService
        
        // Barkod algılama dinleyicisi
        barcodeService.$detectedBarcode
            .compactMap { $0 }
            .sink { [weak self] barcodeResult in
                self?.handleBarcodeDetection(barcodeResult.content)
            }
            .store(in: &cancellables)
    }
    
    private func setupScannerAnimation() {
        // Scanner çizgisi animasyonunu başlat
        DispatchQueue.main.async {
            self.scannerLineOffset = 140
        }
    }
    
    // CameraService'e yönlendirme
    var captureSession: AVCaptureSession {
        return cameraService.captureSession
    }
    
    func startScanning() {
        cameraService.startRunning()
    }
    
    func stopScanning() {
        cameraService.stopRunning()
    }
    
    func toggleFlash() {
        let newFlashState = cameraService.toggleFlash()
        DispatchQueue.main.async {
            self.isFlashOn = newFlashState
        }
    }
    
    func resetScanning() {
        scannedBarcode = ""
        lastScanTime = Date()
        barcodeService.resetDetection()
    }
    
    func handleBarcodeDetection(_ barcode: String) {
        // Cooldown kontrolü
        let now = Date()
        if now.timeIntervalSince(lastScanTime) < scanCooldown {
            return
        }
        
        lastScanTime = now
        
        DispatchQueue.main.async {
            self.scannedBarcode = barcode
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    func openWebsite(with barcodeContent: String) {
        let baseURL = UserDefaults.standard.string(forKey: Constants.UserDefaults.baseURL) ?? Constants.Network.defaultBaseURL
        let fullURL = "\(baseURL)\(barcodeContent)"
        
        DispatchQueue.main.async {
            self.currentURL = fullURL
            self.showWebBrowser = true
        }
    }
    
    func focusAt(point: CGPoint) {
        cameraService.focusAt(point: point)
    }
}

// MARK: - CameraServiceDelegate
extension ScannerViewModel: CameraServiceDelegate {
    func cameraService(_ service: CameraService, didCapture pixelBuffer: CVPixelBuffer) {
        barcodeService.detectBarcode(in: pixelBuffer)
    }
} 
