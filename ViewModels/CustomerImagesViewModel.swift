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
    @Published var customerImageGroups: [CustomerImageGroup] = []
    
    // MARK: - Error Handling
    @Published var showingError = false
    @Published var errorMessage = ""
    
    // MARK: - Search State
    @Published var isSearching = false
    @Published var showDropdown = false
    
    init() {
        checkDeviceAuthorization()
        loadCustomerImageGroups()
        initializeDatabase()
    }
    
    // MARK: - Database Initialization
    private func initializeDatabase() {
        let dbManager = DatabaseManager.getInstance()
        // Database'in müşteri resimleri için hazır olduğundan emin ol
    }
    
    // MARK: - Device Authorization (DeviceAuthCallback)
    func checkDeviceAuthorization() {
        isLoading = true
        
        DeviceAuthManager.checkDeviceAuthorization { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success:
                    self.onAuthSuccess()
                case .failure:
                    self.onAuthFailure()
                }
            }
        }
    }
    
    func onAuthSuccess() {
        isDeviceAuthorized = true
        refreshSavedImages()
    }
    
    func onAuthFailure() {
        isDeviceAuthorized = false
    }
    
    func onShowLoading() {
        isLoading = true
    }
    
    func onHideLoading() {
        isLoading = false
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
                    return
                }
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
        do {
            let dbManager = DatabaseManager.getInstance()
            return dbManager.searchCachedCustomers(query: query)
        } catch {
            print("Offline müşteri arama hatası: \(error)")
            return []
        }
    }
    
    // MARK: - Customer Selection
    func selectCustomer(_ customer: Customer) {
        selectedCustomer = customer
        clearSearch()
    }
    
    func clearSelectedCustomer() {
        selectedCustomer = nil
        clearSearch()
    }
    
    private func clearSearch() {
        searchText = ""
        customers.removeAll()
        showDropdown = false
        isSearching = false
    }
    
    // MARK: - Image Management
    func saveImageLocally(_ image: UIImage, customerName: String) {
        Task {
            do {
                // ImageStorageManager kullanarak resmi kaydet
                let imagePath = try ImageStorageManager.saveMusteriResmi(image, customerName: customerName)
                
                // Database'e kaydet
                let dbManager = DatabaseManager.getInstance()
                let deviceOwner = UserDefaults.standard.string(forKey: Constants.UserDefaults.deviceOwner) ?? "Bilinmeyen"
                
                try dbManager.insertMusteriResmi(
                    customerName: customerName,
                    imagePath: imagePath,
                    uploadedBy: deviceOwner
                )
                
                await MainActor.run {
                    refreshSavedImages()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Resim kaydedilemedi: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Saved Images Management
    func refreshSavedImages() {
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
    
    private func loadCustomerImageGroups() {
        Task {
            let groups = await loadCustomerImageGroupsFromDatabase()
            await MainActor.run {
                customerImageGroups = groups
            }
        }
    }
    
    // MARK: - Delete Operations
    func deleteImage(imagePath: String) {
        Task {
            do {
                let dbManager = DatabaseManager.getInstance()
                
                // Database'den sil
                try dbManager.deleteMusteriResmiByPath(imagePath: imagePath)
                
                // Dosyayı sil
                try ImageStorageManager.deleteMusteriResmi(imagePath: imagePath)
                
                await MainActor.run {
                    refreshSavedImages()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Resim silinemedi: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    func deleteCustomerImages(customerName: String) {
        Task {
            do {
                let dbManager = DatabaseManager.getInstance()
                
                // Müşteriye ait tüm resimleri getir
                let customerImages = try dbManager.getMusteriResimleriByCustomer(customerName: customerName)
                
                // Dosyaları sil
                for image in customerImages {
                    try? ImageStorageManager.deleteMusteriResmi(imagePath: image.imagePath)
                }
                
                // Database'den sil
                try dbManager.deleteMusteriResimleriByCustomer(customerName: customerName)
                
                await MainActor.run {
                    refreshSavedImages()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Müşteri resimleri silinemedi: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - WhatsApp Sharing
    func shareToWhatsApp(customerName: String, imagePaths: [String]) {
        // WhatsApp paylaşım fonksiyonunu implement et
        let shareText = createShareText(customerName: customerName, imageCount: imagePaths.count)
        
        // Metni panoya kopyala
        UIPasteboard.general.string = shareText
        
        // Paylaşım zamanını kaydet
        markCustomerAsShared(customerName: customerName)
        
        // Sistem paylaşım sayfasını aç
        if let firstImagePath = imagePaths.first {
            shareImageWithSystemChooser(imagePath: firstImagePath, text: shareText)
        }
        
        // Listeyi yenile (paylaşım buton durumunu güncelle)
        refreshSavedImages()
    }
    
    private func createShareText(customerName: String, imageCount: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        let currentDate = dateFormatter.string(from: Date())
        
        return "\(customerName)\n"
    }
    
    private func markCustomerAsShared(customerName: String) {
        let normalizedCustomerName = customerName.replacingOccurrences(of: " ", with: "_")
        let key = "whatsapp_shared_time_\(normalizedCustomerName)"
        let currentTime = Date().timeIntervalSince1970
        
        UserDefaults.standard.set(currentTime, forKey: key)
        UserDefaults.standard.synchronize()
    }
    
    private func shareImageWithSystemChooser(imagePath: String, text: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let url = URL(fileURLWithPath: imagePath)
        let activityViewController = UIActivityViewController(activityItems: [url, text], applicationActivities: nil)
        
        // iPad için popover ayarları
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true)
    }
}

 