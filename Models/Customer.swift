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



// MARK: - CustomerImageGroup Model
struct CustomerImageGroup: Identifiable {
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
        self.lastImageDate = images.map { $0.date }.max() ?? Date()
        
        // WhatsApp paylaşım kontrolü (sınır kaldırıldı - her zaman yeşil kalacak)
        let prefs = UserDefaults.standard
        let key = "whatsapp_shared_time_\(customerName.replacingOccurrences(of: " ", with: "_"))"
        let lastSharedTime = prefs.double(forKey: key)
        
        // Eğer daha önce paylaşım yapılmışsa her zaman yeşil göster
        self.isSharedToday = lastSharedTime > 0
    }
} 