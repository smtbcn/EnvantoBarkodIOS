import Vision
import Combine

class BarcodeService: ObservableObject {
    @Published var detectedBarcode: BarcodeResult?
    @Published var isProcessing = false
    
    private var lastDetectionTime = Date()
    private let detectionCooldown: TimeInterval = 2.0
    
    func detectBarcode(in pixelBuffer: CVPixelBuffer) {
        // Cooldown kontrolü
        let now = Date()
        if now.timeIntervalSince(lastDetectionTime) < detectionCooldown {
            return
        }
        
        isProcessing = true
        
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            defer {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
            
            if let error = error {
                print("Barkod tarama hatası: \(error.localizedDescription)")
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
                self.detectedBarcode = barcodeResult
            }
        }
        
        // Desteklenen barkod formatları
        request.symbologies = [
            .qr,
            .dataMatrix,
            .ean13,
            .ean8,
            .code128,
            .code39,
            .pdf417,
            .aztec
        ]
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Barkod tarama gerçekleştirilemedi: \(error.localizedDescription)")
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
        case .ean13:
            return .ean13
        case .ean8:
            return .ean8
        case .code128:
            return .code128
        case .code39:
            return .code39
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
        detectedBarcode = nil
        lastDetectionTime = Date()
    }
} 