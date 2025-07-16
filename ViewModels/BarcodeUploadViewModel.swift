import SwiftUI
import Foundation
import PhotosUI



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
    @Published var customerImageGroups: [CustomerImageGroup] = []
    
    // MARK: - Error Handling
    @Published var showingError = false
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
        // Database başlatılması artık DatabaseManager.getInstance() çağrısında otomatik oluyor
    }
    

    
    // MARK: - Device Info (Yukleyen bilgisi için)
    private func getDeviceOwnerInfo() -> String {
        // Sunucudan alınan cihaz sahibi bilgisini kullan (Android ile aynı mantık)
        let deviceOwner = UserDefaults.standard.string(forKey: "device_owner") ?? 
                         UserDefaults.standard.string(forKey: Constants.UserDefaults.deviceOwner) ?? ""
        
        if !deviceOwner.isEmpty {
            return deviceOwner
        } else {
            // Fallback: Cihaz bilgisi (sadece cihaz sahibi bilgisi yoksa)
            let deviceName = UIDevice.current.name
            let deviceModel = UIDevice.current.model
            let fallbackInfo = "\(deviceName) (\(deviceModel))"
            return fallbackInfo
        }
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
        // Müşteri gruplarını da yükle
        loadCustomerImageGroups()
        
        // 🚀 Upload service'i başlat (background upload için)
        startUploadServiceIfNeeded()
    }
    
    // MARK: - Upload Service Management
    private func startUploadServiceIfNeeded() {
        let wifiOnly = UserDefaults.standard.bool(forKey: Constants.UserDefaults.wifiOnly)
        
        // Upload service'i başlat
        UploadService.shared.startUploadService(wifiOnly: wifiOnly)

        
        // Background manager'a da bilgi ver
        BackgroundUploadManager.shared.checkPendingUploadsImmediately()
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
            // Fallback: Offline arama
            customers = searchOfflineCustomers(query: searchText)
            isSearching = false
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
        
        // JSON string'i debug için yazdır
        if let jsonString = String(data: data, encoding: .utf8) {
        }
        
        // ASP yanıtını decode et
        return try JSONDecoder().decode([CustomerResponse].self, from: data).map { response in
            Customer(name: response.musteri_adi, code: nil, address: nil)
        }
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
            
            
        } catch {
        }
    }
    
    private func fetchAllCustomersFromServer() async throws -> [Customer] {
        // Envanto API endpoint (getall action)
        let baseURL = "https://envanto.app/barkod_yukle_android"
        guard let url = URL(string: "\(baseURL)/customers.asp") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        // ASP dosyasına getall action gönder
        let bodyString = "action=getall"
        request.httpBody = bodyString.data(using: .utf8)
        
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError
        }
        
        // JSON string'i debug için yazdır
        if let jsonString = String(data: data, encoding: .utf8) {
        }
        
        // ASP yanıtını decode et
        return try JSONDecoder().decode([CustomerResponse].self, from: data).map { response in
            Customer(name: response.musteri_adi, code: nil, address: nil)
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
        // Müşteri bazlı gruplandırma yap
        loadCustomerImageGroups()
    }
    
    // MARK: - Customer Image Groups (Müşteri bazlı resim gruplandırması)
    func loadCustomerImageGroups() {
        Task {
            await loadAllCustomerImages()
        }
    }
    
    @MainActor
    private func loadAllCustomerImages() async {
        // ImageStorageManager'dan tüm müşteri klasörlerini al
        if let storageInfo = await getStorageInfo() {
        }
        
        let dbManager = DatabaseManager.getInstance()
        var groups: [CustomerImageGroup] = []
        
        // 🗄️ DATABASE-FIRST YAKLAŞIM: Database'deki tüm resimleri al
        let allDatabaseImages = dbManager.getAllImages()  // Tüm resimler (pending + uploaded)
        
        // Müşterileri gruplara ayır
        let customerGroups = Dictionary(grouping: allDatabaseImages) { record in
            record.musteriAdi
        }
        
        for (customerName, imageRecords) in customerGroups {
            
            let savedImages = imageRecords.compactMap { record -> SavedImage? in
                // Dosya var mı kontrol et ama dosya yoksa da kayıt göster
                let fileExists = FileManager.default.fileExists(atPath: record.resimYolu)
                
                // 🎯 Display format customer name
                let displayCustomerName = record.musteriAdi.replacingOccurrences(of: "_", with: " ")
                
                // 🗄️ Database verilerinden SavedImage oluştur (dosya var/yok farketmez)
                return SavedImage(
                    customerName: displayCustomerName,  // 📝 SAMET_BICEN → SAMET BICEN
                    imagePath: record.resimYolu,
                    localPath: record.resimYolu,
                    uploadDate: parseDatabaseDate(record.tarih),  // 📅 Database'den tarih
                    isUploaded: record.isUploaded,  // ✅ Database'den upload durumu
                    yukleyen: record.yukleyen,  // 👤 Database'den yükleyen bilgisi
                    databaseId: record.id,  // 🆔 Database ID referansı
                    fileExists: fileExists  // 📁 Dosya varlık durumu
                )
            }
            
            if !savedImages.isEmpty {
                // SavedImage'ları SavedCustomerImage'a dönüştür
                let customerImages = savedImages.map { savedImage in
                    SavedCustomerImage(
                        id: savedImage.databaseId,
                        customerName: savedImage.customerName,
                        imagePath: savedImage.imagePath,
                        date: savedImage.uploadDate,
                        uploadedBy: savedImage.yukleyen
                    )
                }
                
                let group = CustomerImageGroup(
                    customerName: customerName.replacingOccurrences(of: "_", with: " "),  // Display format
                    images: customerImages.sorted { $0.date > $1.date }
                )
                groups.append(group)
            }
        }
        
        // Gruplari tarih sırasına göre sırala (en yeni önce)
        customerImageGroups = groups.sorted { $0.lastImageDate > $1.lastImageDate }
        
    }
    
    // 📅 Database tarih string'ini Date'e çevir
    private func parseDatabaseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: dateString) ?? Date()
    }
    
    // MARK: - Database Upload Status Check
    private func checkDatabaseUploadStatus(path: String, customerName: String, dbManager: DatabaseManager) -> Bool {
        // Müşteri adı format dönüşümü (File system vs Database format)
        let dbCustomerName = customerName.replacingOccurrences(of: "_", with: " ") // SAMET_BICEN -> SAMET BICEN
        let fsCustomerName = customerName.replacingOccurrences(of: " ", with: "_") // SAMET BICEN -> SAMET_BICEN
        
        
        // Önce database formatıyla dene
        var allImages = dbManager.getCustomerImages(musteriAdi: dbCustomerName)
        if allImages.isEmpty && dbCustomerName != customerName {
            // Eğer boş gelirse original formatla da dene
            allImages = dbManager.getCustomerImages(musteriAdi: customerName)
        }
        if allImages.isEmpty && fsCustomerName != customerName {
            // Son çare file system formatıyla dene
            allImages = dbManager.getCustomerImages(musteriAdi: fsCustomerName)
        }
        
        
        // Dosya yoluna göre eşleştir
        for (index, imageRecord) in allImages.enumerated() {
            
            if imageRecord.resimYolu == path {
                return imageRecord.isUploaded
            }
            
            // Dosya adı bazlı eşleştirme de dene (path formatı farklı olabilir)
            let dbFileName = URL(fileURLWithPath: imageRecord.resimYolu).lastPathComponent
            let fileSystemFileName = URL(fileURLWithPath: path).lastPathComponent
            
            if dbFileName == fileSystemFileName {
                return imageRecord.isUploaded
            }
        }
        
        // Database'de bulunamadıysa yüklenmemiş kabul et
        return false
    }
    
    private func getStorageInfo() async -> String? {
        return await ImageStorageManager.getStorageInfo()
    }
    
    private func loadSavedImagesForCustomer(_ customerName: String) {
        Task {
            let dbManager = DatabaseManager.getInstance()
            
            // 🗄️ DATABASE-FIRST: Müşteri adı format denemesi
            let dbCustomerName = customerName.replacingOccurrences(of: "_", with: " ") // SAMET_BICEN → SAMET BICEN
            let fsCustomerName = customerName.replacingOccurrences(of: " ", with: "_") // SAMET BICEN → SAMET_BICEN
            
            // Müşterinin database kayıtlarını al
            var customerImages = dbManager.getCustomerImages(musteriAdi: dbCustomerName)
            if customerImages.isEmpty && dbCustomerName != customerName {
                customerImages = dbManager.getCustomerImages(musteriAdi: customerName)
            }
            if customerImages.isEmpty && fsCustomerName != customerName {
                customerImages = dbManager.getCustomerImages(musteriAdi: fsCustomerName)
            }
            
            await MainActor.run {
                savedImages = customerImages.compactMap { record in
                                    // Dosya var mı kontrol et ama dosya yoksa da kayıt göster
                let fileExists = FileManager.default.fileExists(atPath: record.resimYolu)
                    
                    // 🎯 Display format customer name
                    let displayCustomerName = record.musteriAdi.replacingOccurrences(of: "_", with: " ")
                    
                    return SavedImage(
                        customerName: displayCustomerName,  // 📝 SAMET_BICEN → SAMET BICEN
                        imagePath: record.resimYolu,
                        localPath: record.resimYolu,
                        uploadDate: parseDatabaseDate(record.tarih),  // 📅 Database'den tarih
                        isUploaded: record.isUploaded,  // ✅ Database'den upload durumu
                        yukleyen: record.yukleyen,  // 👤 Database'den yükleyen bilgisi
                        databaseId: record.id,  // 🆔 Database ID referansı
                        fileExists: fileExists  // 📁 Dosya varlık durumu
                    )
                }
                
            }
        }
    }
    
    private func loadAllSavedImages() -> [SavedImage] {
        // Şimdilik sadece seçili müşterinin resimlerini döndür
        if let customer = selectedCustomer {
            return savedImages.filter { $0.customerName == customer.name }
        }
        return []
    }
    
    private func getFileCreationDate(path: String) -> Date {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.creationDate] as? Date ?? Date()
        } catch {
            return Date()
        }
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
                
                // Android'deki direktSaveImage mantığı - Önce cihaza kaydet
                await directSaveImage(image: image, customer: customer, isGallery: true)
                
                // Kısa bekleme
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 saniye
            }
            
            // Tamamlandı
            updateProgress(current: images.count, total: images.count)
            isUploading = false
            
            // Kayıtlı resimleri yenile
            loadSavedImagesForCustomer(customer.name)
            // Müşteri gruplarını güncelle
            loadCustomerImageGroups()
            
        } catch {
            isUploading = false
            showError("Yükleme hatası: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Direct Save Image (Android Pattern)
    @MainActor
    private func directSaveImage(image: UIImage, customer: Customer, isGallery: Bool) async {
        // Cihaz sahibi bilgisini al
        let yukleyen = getDeviceOwnerInfo()
        
        
        // ImageStorageManager ile resmi Documents klasörüne kaydet ve veritabanına ekle
        if let savedPath = await ImageStorageManager.saveImage(
            image: image, 
            customerName: customer.name, 
            isGallery: isGallery,
            yukleyen: yukleyen
        ) {
            
            // TODO: Sunucuya upload işlemi burada yapılacak
            // Android'deki gibi: server upload ve yuklendi durumu güncelleme
            
        } else {
            showError("❌ Resim kaydetme hatası")
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
            for (index, photo) in photos.enumerated() {
                // Progress güncelle
                await MainActor.run {
                    updateProgress(current: index, total: photos.count)
                }
                
                // PhotosPickerItem'den resim yükle ve kaydet
                if let data = try await photo.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    
                    // Galeri resmini direk kaydet (Android directSaveImage mantığı)
                    await directSaveImage(image: image, customer: customer, isGallery: true)
                }
            }
            
            await MainActor.run {
                // Tamamlandı
                updateProgress(current: photos.count, total: photos.count)
                isUploading = false
                
                // Kayıtlı resimleri yenile
                loadSavedImagesForCustomer(customer.name)
                // Müşteri gruplarını güncelle
                loadCustomerImageGroups()
            }
            
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
        // Her durumda müşteri gruplarını da güncelle
        loadCustomerImageGroups()
    }
    
    // MARK: - Delete Image
    func deleteImage(_ image: SavedCustomerImage) {
        Task {
            let dbManager = DatabaseManager.getInstance()
            
            // 1️⃣ Önce database kaydını sil
            let dbDeleteSuccess = dbManager.deleteBarkodResim(id: image.id)
            
            // 2️⃣ Sonra dosyayı sil (ImageStorageManager)
            let fileDeleteSuccess = await ImageStorageManager.deleteImage(at: image.imagePath)
            
            await MainActor.run {
                if dbDeleteSuccess || fileDeleteSuccess {
                    // En az birisi başarılıysa UI'dan kaldır
                    savedImages.removeAll { $0.id == image.id }
                    
                    // Müşteri gruplarını güncelle
                    loadCustomerImageGroups()
                } else {
                    // Her ikisi de başarısızsa hata mesajı
                    showError("Resim silme hatası: Hem database hem dosya silme başarısız")
                }
            }
        }
    }
    
    // MARK: - Delete Customer Folder (Sadece yüklenmiş resimleri sil - toplu silme)
    func deleteCustomerFolder(_ customerName: String) {
        Task {
            let dbManager = DatabaseManager.getInstance()
            
            // 🎯 Database'den direkt müşterinin tüm resimlerini al (Format denemesi)
            let dbCustomerName = customerName.replacingOccurrences(of: " ", with: "_") // SAMET BICEN → SAMET_BICEN
            let displayCustomerName = customerName // UI format
            
            // Müşterinin database kayıtlarını al (her iki format için de dene)
            var customerRecords = dbManager.getCustomerImages(musteriAdi: displayCustomerName)
            if customerRecords.isEmpty {
                customerRecords = dbManager.getCustomerImages(musteriAdi: dbCustomerName)
            }
            
            // ⚠️ SADECE YÜKLENMİŞ RESİMLERİ FİLTRELE (yuklendi = 1)
            let uploadedRecords = customerRecords.filter { $0.isUploaded }
            let pendingRecords = customerRecords.filter { !$0.isUploaded }
            
            if uploadedRecords.isEmpty {
                await MainActor.run {
                    showError("Bu müşteriye ait yüklenmiş resim bulunamadı. Sadece bekleyen resimler var.")
                }
                return
            }
            
            // Yüklenmiş resimlerin ID'lerini topla
            let uploadedIds = uploadedRecords.map { $0.id }
            let uploadedPaths = uploadedRecords.map { $0.resimYolu }
            
            // 1️⃣ Database'den sadece yüklenmiş resimleri sil
            let dbDeleteSuccess = dbManager.deleteImagesByIds(uploadedIds)
            
            // 2️⃣ Sadece yüklenmiş resim dosyalarını sil
            var fileDeleteSuccess = true
            var deletedFileCount = 0
            
            for imagePath in uploadedPaths {
                let success = await ImageStorageManager.deleteImage(at: imagePath)
                if success {
                    deletedFileCount += 1
                } else {
                    fileDeleteSuccess = false
                }
            }
            
            await MainActor.run {
                if dbDeleteSuccess || deletedFileCount > 0 {
                    // UI'dan sadece yüklenmiş resimleri kaldır
                    savedImages.removeAll { image in
                        uploadedIds.contains(image.databaseId)
                    }
                    
                    // Başarı mesajı
                    let message = """
                    ✅ Toplu silme tamamlandı:
                    • Silinen: \(uploadedRecords.count) yüklenmiş resim
                    • Korunan: \(pendingRecords.count) bekleyen resim
                    """
                    
                    // Müşteri gruplarını güncelle
                    loadCustomerImageGroups()
                    
                    // Bilgi mesajı (hata değil, bilgilendirme)
                    if pendingRecords.count > 0 {
                        showError(message) // showError yerine showInfo olabilir ama şimdilik bu
                    }
                } else {
                    // Hiçbir silme işlemi başarısız
                    showError("Yüklenmiş resimler silinemedi")
                }
            }
        }
    }
    
    // MARK: - Handle Captured Image (Kamera için - Sürekli çekim)
    func handleCapturedImage(_ image: UIImage, customer: Customer) async {
        // Kamerayı açık bırak, sadece background'da kaydet
        
        // Kamera resmini direk kaydet (Android directSaveImage mantığı)
        await directSaveImage(image: image, customer: customer, isGallery: false)
        
        await MainActor.run {
            // Kayıtlı resimleri yenile (background'da)
            loadSavedImagesForCustomer(customer.name)
            // Müşteri gruplarını güncelle (background'da)
            loadCustomerImageGroups()
        }
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
    let yukleyen: String
    let databaseId: Int  // Database record ID'si
    let fileExists: Bool  // 📁 Dosya varlık durumu
} 

// CustomerImageGroup artık Models/Customer.swift'de tanımlı

// NetworkError DeviceAuthManager'da tanımlı 
