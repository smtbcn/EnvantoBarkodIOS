import Foundation

// MARK: - SavedCustomerImage Model
struct SavedCustomerImage: Codable, Identifiable {
    let id: Int
    let customerName: String
    private let _imagePath: String // Database'den gelen path (relative olabilir)
    let date: Date
    let uploadedBy: String
    
    // Coding keys for database compatibility
    private enum CodingKeys: String, CodingKey {
        case id, customerName, date, uploadedBy
        case _imagePath = "imagePath"
    }
    
    // Public initializer
    init(id: Int, customerName: String, imagePath: String, date: Date, uploadedBy: String) {
        self.id = id
        self.customerName = customerName
        self._imagePath = imagePath
        self.date = date
        self.uploadedBy = uploadedBy
    }
    
    // Computed properties for compatibility
    var imagePath: String {
        // Eğer relative path ise absolute path'e çevir
        if _imagePath.hasPrefix("/") {
            return _imagePath // Zaten absolute path
        } else {
            // Relative path'i absolute path'e çevir
            return PathHelper.getAbsolutePath(for: _imagePath) ?? _imagePath
        }
    }
    
    var localPath: String {
        return imagePath
    }
    
    var fileExists: Bool {
        return FileManager.default.fileExists(atPath: imagePath)
    }
    
    var isUploaded: Bool {
        // Müşteri resimleri local-only olduğu için her zaman false
        return false
    }
}