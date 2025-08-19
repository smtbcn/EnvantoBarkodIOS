import SwiftUI
import Foundation
import PhotosUI

// MARK: - CustomerImagesViewModel
class CustomerImagesViewModel: ObservableObject, DeviceAuthCallback {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var isDeviceAuthorized = false
    @Published var searchText = ""
    @Published var customers: [Customer] = []
    @Published var selectedCustomer: Customer?
    @Published var showingImagePicker = false
    @Published var showingCamera = false
    @Published var savedImages: [SavedCustomerImage] = []
    @Published var customerImageGroups: [CustomerImageGroup] = []
    
    // MARK: - Error Handling
    @Published var errorMessage = ""
    
    // MARK: - Search State
    @Published var isSearching = false
    @Published var showDropdown = false
    
    init() {
        checkDeviceAuthorization()
        // Başlangıçta müşteri gruplarını yükle
        loadCustomerImageGroups()
        // Database'i başlat
        initializeDatabase()
    }
    
    // MARK: - Database Initialization
    private func initializeDatabase() {
        // Database'in müşteri resimleri için hazır olduğundan emin ol
        _ = DatabaseManager.getInstance()
    }
    
    // MARK: - Device Info (Yukleyen bilgisi için)
    private func getDeviceOwnerInfo() -> String {
        // Sunucudan alınan cihaz sahibi bilgisini kullan (Android ile aynı mantık)
        let deviceOwner = UserDefaults.standard.string(forKey: "device_owner") ?? 
                         UserDefaults.standard.string(forKey: Constants.UserDefaults.deviceOwner) ?? ""
        
        return deviceOwner.isEmpty ? "Bilinmeyen Kullanıcı" : deviceOwner
    }
    
    // MARK: - Device Authorization (DeviceAuthCallback)
    func checkDeviceAuthorization() {
        isLoading = true
        DeviceAuthManager.checkDeviceAuthorization(callback: self)
    }
    
    // MARK: - Customer Search
    func searchCustomers() {
        guard searchText.count >= 2 else {
            customers.removeAll()
            showDropdown = false
            return
        }
        
        isSearching = true
        showDropdown = true
        
        Task {
            await performCustomerSearch()
        }
    }
    
    private func performCustomerSearch() async {
        do {
            // Önce offline arama yap
            let offlineResults = searchOfflineCustomers(query: searchText)
            
            await MainActor.run {
                if !offlineResults.isEmpty {
                    customers = offlineResults
                    isSearching = false
                }
            }
            
            // Eğer offline sonuç varsa online aramaya gerek yok
            if !offlineResults.isEmpty {
                return
            }
            
            // Online arama
            let onlineResults = try await searchCustomersOnline(query: searchText)
            await MainActor.run {
                customers = onlineResults
                isSearching = false
            }
            
        } catch {
            // Fallback: Offline arama
            await MainActor.run {
                customers = searchOfflineCustomers(query: searchText)
                isSearching = false
            }
        }
    }
    
    // MARK: - Online Customer Search (Envanto API)
    private func searchCustomersOnline(query: String) async throws -> [Customer] {
        // Envanto API endpoint
        let baseURL = "https://envanto.app/barkod_yukle_android"
        guard let url = URL(string: "\(baseURL)/customers.asp") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        // ASP dosyasına uygun parametreler
        let bodyString = "action=search&query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError
        }
        
        // ASP yanıtını decode et
        let decoder = JSONDecoder()
        let customerResponses = try decoder.decode([CustomerResponse].self, from: data)
        
        return customerResponses.map { response in
            Customer(name: response.musteri_adi, code: nil, address: nil)
        }
    }
    
    // MARK: - Offline Customer Search
    private func searchOfflineCustomers(query: String) -> [Customer] {
        let dbManager = DatabaseManager.getInstance()
        return dbManager.searchCachedCustomers(query: query)
    }
    
    // MARK: - Customer Selection
    func selectCustomer(_ customer: Customer) {
        selectedCustomer = customer
        clearSearch()
    }
    
    func clearSelectedCustomer() {
        selectedCustomer = nil
    }
    
    func clearSearch() {
        searchText = ""
        customers.removeAll()
        showDropdown = false
        isSearching = false
    }
    
    // MARK: - Image Handling (Müşteri Resimleri için özel)
    func handleSelectedPhotos(_ photos: [PhotosPickerItem]) async {
        guard let customer = selectedCustomer else {
            await MainActor.run {
                showError("Lütfen önce bir müşteri seçin")
            }
            return
        }
        
        // Eşzamanlı yükleme için güvenli sayaç
        var successfulUploads = 0
        var failedUploads = 0
        
        // Tüm resimleri seri olarak yükle
        for photo in photos {
            do {
                if let data = try await photo.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let result = await saveImageLocally(image, customer: customer)
                    
                    await MainActor.run {
                        if result {
                            successfulUploads += 1
                        } else {
                            failedUploads += 1
                        }
                    }
                } else {
                    await MainActor.run {
                        failedUploads += 1
                    }
                }
            } catch {
                print("Resim yükleme hatası: \(error.localizedDescription)")
                await MainActor.run {
                    failedUploads += 1
                }
            }
        }
        
        // Sonuçları göster
        await MainActor.run {
            if failedUploads > 0 {
                showError("Toplam \(photos.count) resimden \(successfulUploads) tanesi yüklendi, \(failedUploads) tanesi yüklenemedi.")
            }
            refreshSavedImages()
        }
    }
    
    func handleCapturedImage(_ image: UIImage, customer: Customer) async {
        // Kamerayı açık bırak, sadece background'da kaydet (BarcodeUploadView ile aynı mantık)
        
        let _ = await saveImageLocally(image, customer: customer)
        await MainActor.run {
            // Kamerayı KAPATMA - açık bırak (showingCamera = false YOK)
            refreshSavedImages()
        }
    }
    
    // MARK: - Image Storage (Local Only - Android mantığı)
    private func saveImageLocally(_ image: UIImage, customer: Customer) async -> Bool {
        do {
            // Önce çift kayıt kontrolü
            let dbManager = DatabaseManager.getInstance()
            
            // Resmi kaydet
            let result = try ImageStorageManager.saveMusteriResmi(image, customerName: customer.name)
            
            // Çift kayıt kontrolü
            if try dbManager.isCustomerImageAlreadyInDatabase(imagePath: result.relativePath, customerName: customer.name) {
                // Zaten var, kaydetme
                print("🚫 Resim zaten mevcut: \(result.relativePath)")
                return false
            }
            
            // Database'e RELATIVE PATH kaydet
            let deviceOwner = getDeviceOwnerInfo()
            
            try dbManager.insertMusteriResmi(
                customerName: customer.name,
                imagePath: result.relativePath, // ✅ Relative path kaydet
                uploadedBy: deviceOwner
            )
            
            return true
            
        } catch {
            print("❌ Resim kaydetme hatası: \(error.localizedDescription)")
            await MainActor.run {
                showError("Resim kaydedilemedi: \(error.localizedDescription)")
            }
            return false
        }
    }
    
    // MARK: - Saved Images Management
    func refreshSavedImages() {
        loadCustomerImageGroups()
    }
    
    func loadCustomerImageGroups() {
        Task {
            let groups = await loadCustomerImageGroupsFromDatabase()
            await MainActor.run {
                customerImageGroups = groups
            }
        }
    }
    
    private func loadCustomerImageGroupsFromDatabase() async -> [CustomerImageGroup] {
        do {
            let dbManager = DatabaseManager.getInstance()
            let savedImages = try dbManager.getAllMusteriResimleri()
            
            // Müşteri adına göre grupla
            let groupedImages = Dictionary(grouping: savedImages) { $0.customerName }
            
            // CustomerImageGroup'lara dönüştür
            let groups = groupedImages.map { (customerName, images) in
                CustomerImageGroup(customerName: customerName, images: images)
            }
            
            // Tarihe göre sırala (en yeni üstte)
            return groups.sorted { $0.lastImageDate > $1.lastImageDate }
            
        } catch {
            print("Müşteri resim grupları yükleme hatası: \(error)")
            return []
        }
    }
    
    // MARK: - Image Deletion
    func deleteImageByPath(_ imagePath: String) {
        // Path boş veya geçersizse işlem yapma
        guard !imagePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Geçersiz resim yolu: \(imagePath)")
            return
        }
        
        // Path'in doğruluğunu kontrol et
        print("🔍 Silinecek resim yolu: \(imagePath)")
        
        Task {
            do {
                // 1. Veritabanı kaydını sil
                let dbManager = DatabaseManager.getInstance()
                try dbManager.deleteMusteriResmiByPath(imagePath: imagePath)
                
                // 2. Dosyayı sil
                try ImageStorageManager.deleteMusteriResmi(imagePath: imagePath)
                
                await MainActor.run {
                    refreshSavedImages()
                }
                
            } catch {
                await MainActor.run {
                    showError("Resim silinemedi: \(error.localizedDescription)")
                }
                print("❌ Resim silme hatası: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Customer Folder Deletion
    func deleteCustomerFolder(_ customerName: String) {
        Task {
            do {
                let dbManager = DatabaseManager.getInstance()
                
                // Database'den müşteri resimleri sil
                try dbManager.deleteMusteriResimleriByCustomer(customerName: customerName)
                
                await MainActor.run {
                    refreshSavedImages()
                }
                
            } catch {
                await MainActor.run {
                    showError("Müşteri resimleri silinemedi: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - WhatsApp Sharing
    func shareToWhatsApp(customerName: String, imagePaths: [String]) {
        Task {
            // WhatsApp paylaşım zamanını kaydet (5 dakikalık sınır kaldırıldı)
            let prefs = UserDefaults.standard
            let key = "whatsapp_shared_time_\(customerName.replacingOccurrences(of: " ", with: "_"))"
            let currentTime = Date().timeIntervalSince1970
            
            // Paylaşım zamanını kaydet (buton yeşil kalması için)
            prefs.set(currentTime, forKey: key)
            
            await MainActor.run {
                shareToWhatsAppInternal(customerName: customerName, imagePaths: imagePaths)
                // Paylaşım sonrası grupları yenile (buton rengini güncellemek için)
                refreshSavedImages()
            }
        }
    }
    
    private func shareToWhatsAppInternal(customerName: String, imagePaths: [String]) {
        let shareText = createShareText(customerName: customerName, imageCount: imagePaths.count)
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        // TÜM resimleri paylaş (birden fazla resim desteği)
        guard !imagePaths.isEmpty else { return }
        
        // Tüm resim yollarını URL listesine çevir
        let imageURLs: [URL] = imagePaths.compactMap { path in
            // Dosya var mı kontrol et
            guard FileManager.default.fileExists(atPath: path) else {
                print("⚠️ Dosya bulunamadı: \(path)")
                return nil
            }
            return URL(fileURLWithPath: path)
        }
        
        guard !imageURLs.isEmpty else {
            print("❌ Paylaşılacak geçerli resim bulunamadı")
            return
        }
        
        // Activity items: Text + Tüm resim URL'leri
        var activityItems: [Any] = [shareText]
        activityItems.append(contentsOf: imageURLs)
        
        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // iPad için popover ayarları
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true)
    }
    
    private func createShareText(customerName: String, imageCount: Int) -> String {
        return "\(customerName)\n"
    }
    
    // MARK: - Error Handling
    private func showError(_ message: String) {
        errorMessage = message
    }
    
    // MARK: - DeviceAuthCallback Implementation
    func onAuthSuccess() {
        DispatchQueue.main.async {
            self.isDeviceAuthorized = true
            self.isLoading = false
            self.refreshSavedImages()
        }
    }
    
    func onAuthFailure() {
        DispatchQueue.main.async {
            self.isDeviceAuthorized = false
            self.isLoading = false
            // Sadece unauthorizedDeviceView göster, popup gösterme
        }
    }
    
    func onShowLoading() {
        DispatchQueue.main.async {
            self.isLoading = true
        }
    }
    
    func onHideLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
}