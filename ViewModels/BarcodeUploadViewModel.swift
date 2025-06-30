import SwiftUI
import Foundation

// MARK: - Custom Errors
enum CustomerAPIError: Error {
    case invalidURL
    case serverError
    case decodingError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Geçersiz URL"
        case .serverError:
            return "Sunucu hatası"
        case .decodingError:
            return "Veri dönüştürme hatası"
        }
    }
}

// MARK: - Customer Model (API'den gelen format: {"musteri_adi":"..."})
struct Customer: Codable, Identifiable {
    let id = UUID()
    let name: String
    let code: String?
    let address: String?
    
    // Normal init for manual creation
    init(name: String, code: String? = nil, address: String? = nil) {
        self.name = name
        self.code = code
        self.address = address
    }
    
    private enum CodingKeys: String, CodingKey {
        case name = "musteri_adi"
    }
    
    // Custom init from decoder - API'den sadece musteri_adi geliyor
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // API'den gelen musteri_adi field'ını name olarak ata
        self.name = try container.decode(String.self, forKey: .name)
        
        // code ve address API'de yok, nil ata
        self.code = nil
        self.address = nil
    }
    
    // Encoder - Sadece name field'ını encode et
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
    }
}

// MARK: - SavedImage Model (Android'deki database kayıtlarına benzer)
struct SavedImage: Identifiable, Codable {
    let id = UUID()
    let customerName: String
    let imagePath: String
    let uploadDate: Date
    let isUploaded: Bool
}

// MARK: - BarcodeUploadViewModel
class BarcodeUploadViewModel: ObservableObject, DeviceAuthCallback {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var isDeviceAuthorized = false
    @Published var searchText = ""
    @Published var customers: [Customer] = []
    @Published var selectedCustomer: Customer?
    @Published var showingImagePicker = false
    @Published var showingCamera = false
    @Published var uploadProgress: Float = 0.0
    @Published var isUploading = false
    @Published var savedImages: [SavedImage] = []
    
    // MARK: - Error Handling
    @Published var showingError = false
    @Published var errorMessage = ""
    
    // MARK: - Search State
    @Published var isSearching = false
    @Published var showDropdown = false
    
    init() {
        checkDeviceAuthorization()
    }
    
    // MARK: - Cihaz yetkilendirme kontrolü (Android template ile aynı)
    func checkDeviceAuthorization() {
        DeviceAuthManager.checkDeviceAuthorization(callback: self)
    }
    
    // MARK: - DeviceAuthCallback implementasyonu
    func onAuthSuccess() {
        DispatchQueue.main.async {
            self.isDeviceAuthorized = true
            // Cihaz yetkilendirme başarılı, sayfa özel işlemleri
            self.onDeviceAuthSuccess()
        }
    }
    
    func onAuthFailure() {
        DispatchQueue.main.async {
            self.isDeviceAuthorized = false
            // Activity kapanacak
            self.onDeviceAuthFailure()
        }
    }
    
    func onShowLoading() {
        DispatchQueue.main.async {
            self.isLoading = true
            // Cihaz yetkilendirme yükleme başladı - sayfa özel işlemleri
            self.onDeviceAuthShowLoading()
        }
    }
    
    func onHideLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
            // Cihaz yetkilendirme yükleme bitti - sayfa özel işlemleri
            self.onDeviceAuthHideLoading()
        }
    }
    
    // MARK: - Sayfa özel cihaz yetkilendirme metodları (Android template)
    private func onDeviceAuthSuccess() {
        // Android'deki gibi: cihaz yetkilendirme başarılı olunca müşteri cache'ini kontrol et
        checkAndUpdateCustomerCache()
        loadSavedImages()
    }
    
    private func onDeviceAuthFailure() {
        // Activity zaten kapanacak
    }
    
    private func onDeviceAuthShowLoading() {
        // Progress bar göster (DetailedProgressBar gibi)
        updateProgress(current: 30, total: 100)
    }
    
    private func onDeviceAuthHideLoading() {
        // Progress bar gizle
        updateProgress(current: 100, total: 100)
    }
    
    // MARK: - Customer Search (Android'deki searchCustomers metoduna benzer)
    func searchCustomers() {
        guard !searchText.isEmpty else {
            customers = []
            showDropdown = false
            return
        }
        
        // Android'deki gibi minimum 2 karakter kontrolü
        if searchText.count < 2 {
            customers = []
            showDropdown = false
            return
        }
        
        print("🔍 Müşteri arama başlatıldı: '\(searchText)'")
        isSearching = true
        showDropdown = true
        
        Task {
            await performCustomerSearch()
        }
    }
    
    @MainActor
    private func performCustomerSearch() async {
        // Android'deki gibi önce hemen offline arama yap
        let offlineResults = searchOfflineCustomers(query: searchText)
        customers = offlineResults
        
        print("🔍 Offline arama: \(offlineResults.count) müşteri bulundu")
        
        // Paralel olarak online arama yap (Android'deki gibi)
        Task {
            do {
                let onlineResults = try await searchCustomersOnline(query: searchText)
                print("🌐 Online arama: \(onlineResults.count) müşteri bulundu")
                
                // Online sonuçlar varsa, offline sonuçları güncelle (Android'deki gibi)
                if !onlineResults.isEmpty {
                    await MainActor.run {
                        customers = onlineResults
                        print("✅ Online sonuçlar ile güncellendi")
                    }
                } else {
                    print("📱 Online sonuç boş, offline sonuçlar korunuyor")
                }
                
            } catch {
                print("🔍 Online arama hatası: \(error.localizedDescription)")
                print("📱 Offline sonuçlar korunuyor")
            }
            
            await MainActor.run {
                isSearching = false
            }
        }
    }
    
    // MARK: - Online Customer Search (Android searchCustomers metoduna benzer)
    private func searchCustomersOnline(query: String) async throws -> [Customer] {
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: "\(baseURL)/customers.asp") else {
            throw CustomerAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 3.0  // Android'deki gibi 3 saniye timeout
        
        // API'ye uygun parametreler: action=search&query=aramakelimesi
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyString = "action=search&query=\(encodedQuery)"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CustomerAPIError.serverError
        }
        
        // Debug: API response'unu logla
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 API Response (search): \(responseString)")
        }
        
        // JSON decode - API format: [{"musteri_adi":"..."}]
        do {
            return try JSONDecoder().decode([Customer].self, from: data)
        } catch {
            print("❌ Customer search JSON decode hatası: \(error)")
            throw CustomerAPIError.decodingError
        }
    }
    
    // MARK: - Offline Customer Search (Android searchOfflineCustomers metoduna benzer)
    private func searchOfflineCustomers(query: String) -> [Customer] {
        // UserDefaults'tan cache'lenmiş müşterileri al
        guard let data = UserDefaults.standard.data(forKey: "cached_customers"),
              let cachedCustomers = try? JSONDecoder().decode([Customer].self, from: data) else {
            return []
        }
        
        let lowercaseQuery = query.lowercased()
        let results = cachedCustomers.filter { customer in
            customer.name.lowercased().contains(lowercaseQuery) ||
            customer.code?.lowercased().contains(lowercaseQuery) == true
        }
        
        // Android'deki gibi alfabetik sırala ve en fazla 50 sonuç döndür
        return Array(results.sorted { $0.name < $1.name }.prefix(50))
    }
    

    
    // MARK: - Customer Cache Management (Android checkAndUpdateCustomerCache metoduna benzer)
    private func checkAndUpdateCustomerCache() {
        Task {
            await performCustomerCacheCheck()
        }
    }
    
    @MainActor
    private func performCustomerCacheCheck() async {
        // Android'deki gibi: önce cache'de kaç müşteri var kontrol et
        let cachedCustomerCount = getCachedCustomerCount()
        print("📦 Cache'de \(cachedCustomerCount) müşteri var")
        
        if cachedCustomerCount == 0 {
            // Android'deki gibi: hiç müşteri yoksa ilk kez yükle
            print("📦 Hiç müşteri yok, ilk kez yükleniyor...")
            await fetchAndCacheAllCustomers()
        } else {
            // Android'deki gibi: belirli aralıklarla güncelle (6 saat geçmişse)
            let lastCacheTime = UserDefaults.standard.double(forKey: "customer_cache_time")
            let currentTime = Date().timeIntervalSince1970
            let cacheAge = currentTime - lastCacheTime
            
            print("📦 Son güncelleme: \(Date(timeIntervalSince1970: lastCacheTime))")
            print("📦 Şu anki zaman: \(Date())")
            print("📦 Geçen süre: \(Int(cacheAge/60)) dakika")
            
            // Android'deki gibi 6 saat = 21600 saniye (Android'de CUSTOMER_CACHE_UPDATE_INTERVAL)
            let updateIntervalSeconds: Double = 6 * 60 * 60 // 6 saat
            
            if cacheAge > updateIntervalSeconds {
                print("📦 6 saat geçti, müşteri listesi güncelleniyor...")
                await fetchAndCacheAllCustomers()
            } else {
                let remainingTime = updateIntervalSeconds - cacheAge
                let remainingHours = Int(remainingTime / 3600)
                let remainingMinutes = Int((remainingTime.truncatingRemainder(dividingBy: 3600)) / 60)
                print("📦 Müşteri listesi güncel. Sonraki güncelleme: \(remainingHours) saat \(remainingMinutes) dakika sonra")
            }
        }
    }
    
    // Android'deki getCachedMusteriCount metoduna benzer
    private func getCachedCustomerCount() -> Int {
        guard let data = UserDefaults.standard.data(forKey: "cached_customers"),
              let cachedCustomers = try? JSONDecoder().decode([Customer].self, from: data) else {
            return 0
        }
        return cachedCustomers.count
    }
    
    @MainActor
    private func fetchAndCacheAllCustomers() async {
        // Android'deki gibi progress göster
        isLoading = true
        updateProgress(current: 0, total: 100)
        
        do {
            print("📦 Tüm müşteri listesi getiriliyor ve cache'e alınıyor...")
            updateProgress(current: 30, total: 100)
            
            let allCustomers = try await fetchAllCustomersFromServer()
            updateProgress(current: 70, total: 100)
            
            print("📦 \(allCustomers.count) müşteri alındı, cache'e kaydediliyor")
            
            // Cache'e kaydet
            if let data = try? JSONEncoder().encode(allCustomers) {
                UserDefaults.standard.set(data, forKey: "cached_customers")
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "customer_cache_time")
            }
            
            updateProgress(current: 100, total: 100)
            print("📦 \(allCustomers.count) müşteri başarıyla cache'e kaydedildi")
            
        } catch {
            print("🔍 Müşteri cache güncelleme hatası: \(error.localizedDescription)")
        }
        
        // Android'deki gibi progress'i gizle
        isLoading = false
    }
    
    // MARK: - Fetch All Customers (Android fetchAndCacheAllCustomers metoduna benzer)
    private func fetchAllCustomersFromServer() async throws -> [Customer] {
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: "\(baseURL)/customers.asp") else {
            throw CustomerAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        // API'ye uygun parametreler: action=getall
        let bodyString = "action=getall"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CustomerAPIError.serverError
        }
        
        // Debug: API response'unu logla
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 API Response (getall): \(responseString)")
        }
        
        // JSON decode - API format: [{"musteri_adi":"..."}]
        do {
            return try JSONDecoder().decode([Customer].self, from: data)
        } catch {
            print("❌ Customer getall JSON decode hatası: \(error)")
            throw CustomerAPIError.decodingError
        }
    }
    
    // MARK: - Customer Selection
    func selectCustomer(_ customer: Customer) {
        selectedCustomer = customer
        searchText = customer.name
        showDropdown = false
        
        // Seçilen müşterinin kayıtlı resimlerini yükle
        loadSavedImagesForCustomer(customer.name)
    }
    
    // MARK: - Image Management
    func loadSavedImages() {
        // Tüm kayıtlı resimleri yükle
        savedImages = loadAllSavedImages()
    }
    
    private func loadSavedImagesForCustomer(_ customerName: String) {
        // Belirli müşterinin resimlerini yükle
        savedImages = loadAllSavedImages().filter { $0.customerName == customerName }
    }
    
    private func loadAllSavedImages() -> [SavedImage] {
        // TODO: Core Data veya dosya sistemi ile implement edilecek
        return []
    }
    
    // MARK: - Progress Management (Android'deki gibi)
    private func updateProgress(current: Int, total: Int) {
        let progress = Float(current) / Float(total)
        uploadProgress = progress
    }
    
    // MARK: - Image Upload
    func uploadImages(_ images: [UIImage]) {
        guard let customer = selectedCustomer else {
            showError("Lütfen önce bir müşteri seçin")
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        
        Task {
            await performImageUpload(images: images, customer: customer)
        }
    }
    
    @MainActor
    private func performImageUpload(images: [UIImage], customer: Customer) async {
        do {
            for (index, image) in images.enumerated() {
                // Her resim için progress güncelle
                updateProgress(current: index, total: images.count)
                
                // Resmi sunucuya yükle
                try await uploadSingleImage(image: image, customer: customer)
                
                // Kısa bekleme
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 saniye
            }
            
            // Tamamlandı
            updateProgress(current: images.count, total: images.count)
            isUploading = false
            
            // Kayıtlı resimleri yenile
            loadSavedImages()
            
        } catch {
            isUploading = false
            showError("Yükleme hatası: \(error.localizedDescription)")
        }
    }
    
    private func uploadSingleImage(image: UIImage, customer: Customer) async throws {
        // TODO: Gerçek API ile implement edilecek
        // Şimdilik mock delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 saniye
    }
    
    // MARK: - Error Handling
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
} 