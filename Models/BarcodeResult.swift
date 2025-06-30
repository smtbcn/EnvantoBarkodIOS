import Foundation

struct BarcodeResult: Identifiable, Codable {
    let id: UUID
    let barcodeValue: String
    let timestamp: Date
    let customerCode: String?
    let imageData: Data?
    
    init(barcodeValue: String, customerCode: String? = nil, imageData: Data? = nil) {
        self.id = UUID()
        self.barcodeValue = barcodeValue
        self.timestamp = Date()
        self.customerCode = customerCode
        self.imageData = imageData
    }
}

extension BarcodeResult {
    static var empty: BarcodeResult {
        BarcodeResult(barcodeValue: "", customerCode: nil, imageData: nil)
    }
}

// MARK: - Extensions
extension BarcodeResult {
    var isURL: Bool {
        return barcodeValue.hasPrefix("http://") || barcodeValue.hasPrefix("https://")
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    var shortContent: String {
        return barcodeValue.count > 50 ? String(barcodeValue.prefix(50)) + "..." : barcodeValue
    }
} 