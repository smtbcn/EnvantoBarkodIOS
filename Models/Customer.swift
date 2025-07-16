import Foundation

// MARK: - Customer Model
struct Customer: Codable, Identifiable, Equatable {
    let id = UUID()
    let name: String
    let code: String?
    let address: String?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case code
        case address
    }
    
    // Equatable conformance
    static func == (lhs: Customer, rhs: Customer) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.code == rhs.code
    }
}

// MARK: - CustomerResponse (ASP API Response)
struct CustomerResponse: Codable {
    let musteri_adi: String
}

// MARK: - SavedCustomerImage Model
struct SavedCustomerImage: Codable, Identifiable {
    let id: Int
    let customerName: String
    let imagePath: String
    let date: Date
    let uploadedBy: String
    
    // Computed properties for compatibility
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

// MARK: - CustomerImageGroup Model
struct CustomerImageGroup: Codable, Identifiable {
    let id = UUID()
    let customerName: String
    let images: [SavedCustomerImage]
    let imageCount: Int
    let lastImageDate: Date
    let isSharedToday: Bool
    
    init(customerName: String, images: [SavedCustomerImage]) {
        self.customerName = customerName
        self.images = images
        self.imageCount = images.count
        self.lastImageDate = images.map(\.date).max() ?? Date()
        
        // WhatsApp paylaşım kontrolü (5 dakika geçerliliği)
        let prefs = UserDefaults.standard
        let key = "whatsapp_shared_time_\(customerName.replacingOccurrences(of: " ", with: "_"))"
        let lastSharedTime = prefs.double(forKey: key)
        let currentTime = Date().timeIntervalSince1970
        let fiveMinutesInSeconds: Double = 5 * 60
        
        self.isSharedToday = (currentTime - lastSharedTime) < fiveMinutesInSeconds
    }
} 