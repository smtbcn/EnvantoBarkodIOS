import Foundation

struct BarcodeResult: Identifiable, Codable {
    let id = UUID()
    let content: String
    let format: BarcodeFormat
    let timestamp: Date
    let location: BarcodeLocation?
    
    enum BarcodeFormat: String, CaseIterable, Codable {
        case qr = "QR"
        case dataMatrix = "DataMatrix"
        case ean13 = "EAN-13"
        case ean8 = "EAN-8"
        case code128 = "Code128"
        case code39 = "Code39"
        case unknown = "Unknown"
        
        var displayName: String {
            switch self {
            case .qr:
                return "QR Kod"
            case .dataMatrix:
                return "Data Matrix"
            case .ean13:
                return "EAN-13"
            case .ean8:
                return "EAN-8"
            case .code128:
                return "Code 128"
            case .code39:
                return "Code 39"
            case .unknown:
                return "Bilinmeyen"
            }
        }
    }
    
    struct BarcodeLocation: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }
    
    init(content: String, format: BarcodeFormat = .unknown, location: BarcodeLocation? = nil) {
        self.content = content
        self.format = format
        self.timestamp = Date()
        self.location = location
    }
}

// MARK: - Extensions
extension BarcodeResult {
    var isURL: Bool {
        return content.hasPrefix("http://") || content.hasPrefix("https://")
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    var shortContent: String {
        return content.count > 50 ? String(content.prefix(50)) + "..." : content
    }
} 