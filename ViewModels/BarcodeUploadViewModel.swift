import SwiftUI
import Foundation
import PhotosUI

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
        // Müşteri listesini yükle
        loadCustomerCache()
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
        
        if searchText.count < 2 {
            return
        }
        
        isSearching = true
        showDropdown = true
        
        Task {
            await performCustomerSearch()
        }
    }
    
    @MainActor
    private func performCustomerSearch() async {
        do {
            // Önce offline arama yap
            let offlineResults = searchOfflineCustomers(query: searchText)
            
            if !offlineResults.isEmpty {
                customers = offlineResults
                isSearching = false
                return
            }
            
            // Online arama
            let onlineResults = try await searchCustomersOnline(query: searchText)
            customers = onlineResults
            isSearching = false
            
        } catch {
            print("🔍 Müşteri arama hatası: \(error.localizedDescription)")
            // Fallback: Offline arama
            customers = searchOfflineCustomers(query: searchText)
            isSearching = false
        }
    }
    
    // MARK: - Online Customer Search
    private func searchCustomersOnline(query: String) async throws -> [Customer] {
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: "\(baseURL)/customers_search.php") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let bodyString = "search=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError
        }
        
        return try JSONDecoder().decode([Customer].self, from: data)
    }
    
    // MARK: - Offline Customer Search
    private func searchOfflineCustomers(query: String) -> [Customer] {
        // UserDefaults'tan cache'lenmiş müşterileri al
        guard let data = UserDefaults.standard.data(forKey: "cached_customers"),
              let cachedCustomers = try? JSONDecoder().decode([Customer].self, from: data) else {
            return []
        }
        
        let lowercaseQuery = query.lowercased()
        return cachedCustomers.filter { customer in
            customer.name.lowercased().contains(lowercaseQuery) ||
            customer.code?.lowercased().contains(lowercaseQuery) == true
        }
    }
    
    // MARK: - Load Customer Cache
    private func loadCustomerCache() {
        // İlk açılışta müşteri cache'ini kontrol et
        checkAndUpdateCustomerCache()
    }
    
    private func checkAndUpdateCustomerCache() {
        let lastCacheTime = UserDefaults.standard.double(forKey: "customer_cache_time")
        let currentTime = Date().timeIntervalSince1970
        let cacheAge = currentTime - lastCacheTime
        
        // 1 saat = 3600 saniye cache süresi
        if cacheAge > 3600 {
            Task {
                await fetchAndCacheAllCustomers()
            }
        }
    }
    
    @MainActor
    private func fetchAndCacheAllCustomers() async {
        do {
            let allCustomers = try await fetchAllCustomersFromServer()
            
            // Cache'e kaydet
            if let data = try? JSONEncoder().encode(allCustomers) {
                UserDefaults.standard.set(data, forKey: "cached_customers")
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "customer_cache_time")
            }
            
            print("📦 \(allCustomers.count) müşteri cache'e kaydedildi")
            
        } catch {
            print("🔍 Müşteri cache güncelleme hatası: \(error.localizedDescription)")
        }
    }
    
    private func fetchAllCustomersFromServer() async throws -> [Customer] {
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: "\(baseURL)/customers_all.php") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError
        }
        
        return try JSONDecoder().decode([Customer].self, from: data)
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
    
    // MARK: - Handle Selected Photos (PhotosPicker için)
    func handleSelectedPhotos(_ photos: [PhotosPickerItem]) async {
        guard let customer = selectedCustomer else {
            await MainActor.run {
                showError("Lütfen önce bir müşteri seçin")
            }
            return
        }
        
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
        }
        
        do {
            var uploadedImages: [UIImage] = []
            
            for photo in photos {
                if let data = try await photo.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    uploadedImages.append(image)
                }
            }
            
            await performImageUpload(images: uploadedImages, customer: customer)
            
        } catch {
            await MainActor.run {
                isUploading = false
                showError("Fotoğraf yükleme hatası: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Refresh Saved Images
    func refreshSavedImages() {
        if let customer = selectedCustomer {
            loadSavedImagesForCustomer(customer.name)
        } else {
            loadSavedImages()
        }
    }
    
    // MARK: - Delete Image
    func deleteImage(_ image: SavedImage) {
        savedImages.removeAll { $0.id == image.id }
        
        // TODO: Gerçek dosya silme implementasyonu
        // FileManager ile dosyayı sil
        do {
            try FileManager.default.removeItem(atPath: image.localPath)
            print("🗑️ Resim silindi: \(image.localPath)")
        } catch {
            print("🗑️ Resim silme hatası: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Handle Captured Image (Kamera için)
    func handleCapturedImage(_ image: UIImage, customer: Customer) async {
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
            showingCamera = false
        }
        
        await performImageUpload(images: [image], customer: customer)
    }
}

// MARK: - SavedImage Model
struct SavedImage: Identifiable {
    let id = UUID()
    let customerName: String
    let imagePath: String
    let localPath: String
    let uploadDate: Date
    let isUploaded: Bool
}

// NetworkError DeviceAuthManager'da tanımlı 