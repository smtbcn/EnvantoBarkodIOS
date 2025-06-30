import Foundation

struct BarcodeResult: Identifiable, Codable {
    var id: UUID
    let content: String
    let format: BarcodeFormat
    let timestamp: Date
    let location: BarcodeLocation?
    
    enum CodingKeys: String, CodingKey {
        case content, format, timestamp, location
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.content = try container.decode(String.self, forKey: .content)
        self.format = try container.decode(BarcodeFormat.self, forKey: .format)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.location = try container.decodeIfPresent(BarcodeLocation.self, forKey: .location)
    }
    
    enum BarcodeFormat: String, CaseIterable, Codable {
        case qr = "QR"
        case dataMatrix = "DataMatrix"
        case unknown = "Unknown"
        
        var displayName: String {
            switch self {
            case .qr:
                return "QR Kod"
            case .dataMatrix:
                return "Data Matrix"
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
        self.id = UUID()
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