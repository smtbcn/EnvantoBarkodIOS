import Vision
import Combine

class BarcodeService: ObservableObject {
    @Published var detectedBarcode: BarcodeResult?
    @Published var isProcessing = false
    
    private var lastDetectionTime = Date()
    private let detectionCooldown: TimeInterval = 2.0
    
    // Ses çalmak için CameraService referansı
    weak var cameraService: CameraService?
    
    func detectBarcode(in pixelBuffer: CVPixelBuffer) {
        // Cooldown kontrolü
        let now = Date()
        if now.timeIntervalSince(lastDetectionTime) < detectionCooldown {
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            defer {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
            
            if let error = error {
                return
            }
            
            guard let results = request.results as? [VNBarcodeObservation],
                  let firstBarcode = results.first,
                  let barcodeValue = firstBarcode.payloadStringValue else {
                return
            }
            
            let format = self.mapVisionFormatToBarcodeFormat(firstBarcode.symbology)
            let location = self.extractLocation(from: firstBarcode)
            
            let barcodeResult = BarcodeResult(
                content: barcodeValue,
                format: format,
                location: location
            )
            
            self.lastDetectionTime = now
            
            DispatchQueue.main.async {
                // Barkod bulundu - ses çal
                self.cameraService?.playBeepSound()
                self.detectedBarcode = barcodeResult
            }
        }
        
        // Desteklenen barkod formatları - sadece QR ve Data Matrix
        request.symbologies = [
            .qr,
            .dataMatrix
        ]
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func mapVisionFormatToBarcodeFormat(_ symbology: VNBarcodeSymbology) -> BarcodeResult.BarcodeFormat {
        switch symbology {
        case .qr:
            return .qr
        case .dataMatrix:
            return .dataMatrix
        default:
            return .unknown
        }
    }
    
    private func extractLocation(from observation: VNBarcodeObservation) -> BarcodeResult.BarcodeLocation {
        let boundingBox = observation.boundingBox
        
        return BarcodeResult.BarcodeLocation(
            x: Double(boundingBox.origin.x),
            y: Double(boundingBox.origin.y),
            width: Double(boundingBox.size.width),
            height: Double(boundingBox.size.height)
        )
    }
    
    func resetDetection() {
        DispatchQueue.main.async {
            self.detectedBarcode = nil
        }
        lastDetectionTime = Date()
    }
} 
