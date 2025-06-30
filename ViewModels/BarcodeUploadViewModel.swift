import SwiftUI
import Foundation
import UIKit

// MARK: - Customer Model (API'den gelen format: {"musteri_adi":"..."})
struct Customer: Codable {
    let musteri_adi: String
}

// MARK: - BarcodeUploadViewModel
class BarcodeUploadViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var isAuthSuccess = false
    @Published var customerSearchText = ""
    @Published var searchResults: [String] = []
    @Published var selectedCustomer: String?
    @Published var isSearching = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadMessage = ""
    @Published var showingToast = false
    @Published var toastMessage = ""
    
    private var customerCache: [String] = []
    private var lastCacheTime: Date?
    private let cacheValidityDuration: TimeInterval = 6 * 60 * 60 // 6 saat
    
    private var toastTimer: Timer?
    
    init() {
        checkDeviceAuthorization()
    }
    
    func checkDeviceAuthorization() {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "iOS User"
        
        // Android'deki gibi usersperm.asp endpoint'ini kullan
        let urlString = "https://envanto.app/barkod_yukle_android/usersperm.asp"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "action=check&cihaz_bilgisi=\(deviceId)"
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Device auth error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("❌ No auth data received")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(DeviceAuthResponse.self, from: data)
                if !response.success {
                    DispatchQueue.main.async {
                        self?.showToast("Cihaz yetkisi yok: \(response.message ?? "Bilinmeyen hata")")
                    }
                }
            } catch {
                print("❌ Auth JSON decode error: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    func searchCustomers(query: String) {
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        
        // Önbellekten müşterileri kontrol et
        if let lastCache = lastCacheTime,
           Date().timeIntervalSince(lastCache) < cacheValidityDuration {
            // Önbellek geçerli, filtreleme yap
            searchResults = customerCache.filter { $0.lowercased().contains(query.lowercased()) }
            return
        }
        
        // Önbellek geçersiz veya yok, API'den yeni liste al
        isLoading = true
        
        // Android'deki gibi customers.asp endpoint'ini kullan
        let urlString = "https://envanto.app/barkod_yukle_android/customers.asp?action=search&query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ Customer search error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received")
                    return
                }
                
                do {
                    let customers = try JSONDecoder().decode([String].self, from: data)
                    self?.customerCache = customers
                    self?.lastCacheTime = Date()
                    self?.searchResults = customers.filter { $0.lowercased().contains(query.lowercased()) }
                } catch {
                    print("❌ JSON decode error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    func saveImages(images: [UIImage], customerName: String, source: String) {
        let totalImages = images.count
        var savedCount = 0
        
        for (index, image) in images.enumerated() {
            // iOS Documents/EnvantoBarkod/customerName/IMG_timestamp_index.jpg
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let appDirectory = documentsPath.appendingPathComponent("EnvantoBarkod")
            let customerDirectory = appDirectory.appendingPathComponent(customerName)
            
            // Create directory if needed
            try? FileManager.default.createDirectory(at: customerDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // Generate filename like Android: IMG_timestamp_index.jpg
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "IMG_\(timestamp)_\(index).jpg"
            let fileURL = customerDirectory.appendingPathComponent(fileName)
            
            // Save image
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                do {
                    try imageData.write(to: fileURL)
                    savedCount += 1
                    print("✅ Resim kaydedildi: \(fileURL.path)")
                    
                    // SQLite'a kaydet ve yüklemeyi başlat
                    let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "iOS User"
                    let dbResult = SQLiteManager.shared.addBarkodResim(
                        musteriAdi: customerName,
                        resimYolu: fileURL.path,
                        yukleyen: deviceId
                    )
                    
                    if dbResult > 0 {
                        print("✅ Database kaydı oluşturuldu: ID \(dbResult)")
                        // Resmi yüklemeye başla
                        uploadImage(imagePath: fileURL.path, customerName: customerName)
                    } else {
                        print("❌ Database kaydı başarısız")
                    }
                    
                } catch {
                    print("❌ Resim kaydetme hatası: \(error.localizedDescription)")
                }
            }
        }
        
        // Android style toast message
        if savedCount > 0 {
            showToast("\(source)'den \(savedCount)/\(totalImages) resim kaydedildi")
        } else {
            showToast("Resim kaydetme başarısız")
        }
    }
    
    func uploadImage(imagePath: String, customerName: String) {
        isLoading = true
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "iOS User"
        
        ApiService.shared.uploadImage(
            customerName: customerName,
            imagePath: imagePath,
            uploader: deviceId
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    if response.success {
                        print("✅ Resim yüklendi: \(imagePath)")
                        // Update SQLite status
                        SQLiteManager.shared.updateBarkodResimStatus(resimYolu: imagePath, yuklendi: true)
                    } else {
                        print("❌ Yükleme başarısız: \(response.message ?? "Bilinmeyen hata")")
                        self?.showToast("Yükleme başarısız: \(response.message ?? "Bilinmeyen hata")")
                    }
                    
                case .failure(let error):
                    print("❌ Yükleme hatası: \(error.localizedDescription)")
                    self?.showToast("Yükleme hatası: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func showToast(_ message: String) {
        toastMessage = message
        showingToast = true
        
        // 2 saniye sonra toast'ı kapat
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showingToast = false
        }
    }
    
    func startUploadRetryService() {
        // Yüklenememiş resimleri kontrol et
        let unuploadedImages = SQLiteManager.shared.getUnuploadedImages()
        
        for image in unuploadedImages {
            uploadImage(imagePath: image.path, customerName: image.customerName)
        }
    }
}

// Android'deki gibi response modeli
struct DeviceAuthResponse: Codable {
    let success: Bool
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success = "basari"
        case message = "mesaj"
    }
} 