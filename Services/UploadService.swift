import Foundation
import UIKit
import Network
import Combine

// MARK: - Upload Response Model (Android ile aynı)
struct UploadResponse: Codable {
    let basari: Bool
    let mesaj: String
    let hata: String
    
    var isSuccess: Bool {
        return basari
    }
    
    var message: String {
        return mesaj
    }
    
    var error: String {
        return hata
    }
}

// MARK: - Upload Service (Android UploadRetryService benzeri)
class UploadService: ObservableObject {
    static let shared = UploadService()
    private static let TAG = "UploadService"
    
    @Published var isUploading = false
    @Published var uploadProgress: (current: Int, total: Int) = (0, 0)
    @Published var uploadStatus = "Hazır"
    
    private var uploadTimer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(appDidEnterBackground), 
            name: UIApplication.didEnterBackgroundNotification, 
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(appWillEnterForeground), 
            name: UIApplication.willEnterForegroundNotification, 
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        startBackgroundTask()
    }
    
    @objc private func appWillEnterForeground() {
        endBackgroundTask()
    }
    
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // MARK: - Upload Control (Android mantığı)
    func startUploadService(wifiOnly: Bool) {
        print("🔄 \(UploadService.TAG): Upload servisi başlatılıyor - WiFi only: \(wifiOnly)")
        
        stopUploadService() // Mevcut servisi durdur
        
        uploadTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkAndUploadPendingImages(wifiOnly: wifiOnly)
            }
        }
        
        // İlk kontrolü hemen yap
        Task {
            await checkAndUploadPendingImages(wifiOnly: wifiOnly)
        }
    }
    
    func stopUploadService() {
        uploadTimer?.invalidate()
        uploadTimer = nil
        
        DispatchQueue.main.async {
            self.isUploading = false
            self.uploadStatus = "Durduruldu"
        }
        
        print("⏹️ \(UploadService.TAG): Upload servisi durduruldu")
    }
    
    // MARK: - Upload Logic (Android UploadRetryService benzeri)
    @MainActor
    private func checkAndUploadPendingImages(wifiOnly: Bool) async {
        print("🔍 \(UploadService.TAG): Upload kontrolü başlatılıyor - WiFi only: \(wifiOnly)")
        
        // Database'den yüklenmemiş resimleri al
        let dbManager = DatabaseManager.getInstance()
        
        // Gereksiz cleanup mantığı kaldırıldı - sadece upload işlemi
        
        let pendingImages = dbManager.getAllPendingImages()
        let totalCount = pendingImages.count
        print("📊 \(UploadService.TAG): Bekleyen resim sayısı: \(totalCount)")
        
        // Bekleyen resim yoksa erken çıkış
        if totalCount == 0 {
            uploadStatus = "Yüklenecek resim yok"
            uploadProgress = (0, 0)
            isUploading = false
            print("ℹ️ \(UploadService.TAG): Yüklenecek resim bulunamadı - Upload işlemi durduruldu")
            return
        }
        
        // Network kontrolü
        let uploadCheck = NetworkUtils.canUploadWithSettings(wifiOnly: wifiOnly)
        print("🌐 \(UploadService.TAG): Network kontrolü - Can upload: \(uploadCheck.canUpload), Reason: \(uploadCheck.reason)")
        
        if !uploadCheck.canUpload {
            uploadStatus = uploadCheck.reason
            uploadProgress = (0, totalCount)
            isUploading = false
            print("⚠️ \(UploadService.TAG): Network uygun değil - Upload işlemi bekletildi")
            return
        }
        
        // Cihaz yetki kontrolü
        let deviceId = DeviceIdentifier.getUniqueDeviceId()
        let isAuthorized = dbManager.isCihazYetkili(cihazBilgisi: deviceId)
        print("🔐 \(UploadService.TAG): Cihaz yetki kontrolü - Device ID: \(deviceId), Authorized: \(isAuthorized)")
        
        if !isAuthorized {
            uploadStatus = "Cihaz yetkili değil"
            uploadProgress = (0, totalCount)
            isUploading = false
            print("🚫 \(UploadService.TAG): Cihaz yetkili değil - Upload işlemi durduruldu")
            return
        }
        
        // Tüm kontroller geçti - Upload işlemini başlat
        isUploading = true
        uploadStatus = "Yükleniyor..."
        print("🚀 \(UploadService.TAG): Upload işlemi başlatılıyor - \(totalCount) resim")
        
        var uploadedCount = 0
        
        for (index, imageRecord) in pendingImages.enumerated() {
            uploadProgress = (index, totalCount)
            print("📤 \(UploadService.TAG): Resim yükleniyor (\(index + 1)/\(totalCount)): \(imageRecord.musteriAdi)")
            print("📂 \(UploadService.TAG): Resim yolu: \(imageRecord.resimYolu)")
            print("👤 \(UploadService.TAG): Yükleyen: \(imageRecord.yukleyen)")
            
            // Her resim için network kontrolü (WiFi kesilirse dursun)
            let currentCheck = NetworkUtils.canUploadWithSettings(wifiOnly: wifiOnly)
            if !currentCheck.canUpload {
                uploadStatus = currentCheck.reason
                print("⚠️ \(UploadService.TAG): Network bağlantısı kesildi: \(currentCheck.reason)")
                break
            }
            
            // Resmi yükle
            let success = await uploadImageToServer(imageRecord: imageRecord)
            
            if success {
                uploadedCount += 1
                // Database'de yuklendi flag'ini güncelle
                _ = dbManager.updateUploadStatus(id: imageRecord.id, yuklendi: 1)
                
                uploadProgress = (uploadedCount, totalCount)
                uploadStatus = "Yüklendi: \(uploadedCount)/\(totalCount)"
                
                print("✅ \(UploadService.TAG): Resim başarıyla yüklendi: \(imageRecord.musteriAdi) - \(imageRecord.resimYolu)")
            } else {
                print("❌ \(UploadService.TAG): Resim yüklenemedi: \(imageRecord.musteriAdi) - \(imageRecord.resimYolu)")
                
                // Hata durumunda kısa bekle
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 saniye
            }
        }
        
        isUploading = false
        
        if uploadedCount == totalCount {
            uploadStatus = "Tüm resimler yüklendi ✅"
        } else if uploadedCount > 0 {
            uploadStatus = "\(uploadedCount) resim yüklendi, \(totalCount - uploadedCount) bekliyor"
        }
        
        uploadProgress = (uploadedCount, totalCount)
    }
    
    // MARK: - Server Upload (Android uploadImageToServer benzeri)
    private func uploadImageToServer(imageRecord: BarkodResim) async -> Bool {
        do {
            // Basit dosya kontrolü - database'deki path direkt kullan
            let imagePath = imageRecord.resimYolu
            
            if !FileManager.default.fileExists(atPath: imagePath) {
                print("❌ \(UploadService.TAG): Resim dosyası bulunamadı: \(imagePath)")
                print("   Müşteri: \(imageRecord.musteriAdi)")
                return false
            }
            
            print("📂 \(UploadService.TAG): Resim yolu: \(imagePath)")
            
            // Base URL (Android ile aynı)
            let baseURL = "https://envanto.app/barkod_yukle_android"
            guard let url = URL(string: "\(baseURL)/upload.asp") else {
                print("❌ \(UploadService.TAG): Geçersiz URL")
                return false
            }
            
            // Multipart form data oluştur (Android ile aynı)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30.0
            
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            
            // Action field (Android ile aynı)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"action\"\r\n\r\n".data(using: .utf8)!)
            body.append("upload_file\r\n".data(using: .utf8)!)
            
            // Müşteri adı (Android ile aynı)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"musteri_adi\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(imageRecord.musteriAdi)\r\n".data(using: .utf8)!)
            
            // Yükleyen (Android ile aynı)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"yukleyen\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(imageRecord.yukleyen)\r\n".data(using: .utf8)!)
            
            // Resim dosyası - Database'deki path'i kullan
            let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            let fileName = URL(fileURLWithPath: imagePath).lastPathComponent
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"resim\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Boundary bitişi
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            print("🔗 \(UploadService.TAG): API çağrısı yapılıyor: \(url)")
            print("📋 \(UploadService.TAG): Müşteri: \(imageRecord.musteriAdi), Yükleyen: \(imageRecord.yukleyen)")
            
            // API çağrısı
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // HTTP yanıt kontrolü
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ \(UploadService.TAG): HTTP Error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return false
            }
            
            // JSON decode
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 \(UploadService.TAG): Sunucu yanıtı: \(jsonString)")
            }
            
            let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
            
            if uploadResponse.isSuccess {
                print("✅ \(UploadService.TAG): Upload başarılı: \(uploadResponse.message)")
                return true
            } else {
                print("❌ \(UploadService.TAG): Upload başarısız: \(uploadResponse.error)")
                return false
            }
            
        } catch {
            print("💥 \(UploadService.TAG): Upload hatası: \(error.localizedDescription)")
            return false
        }
    }
    
    // Karmaşık path mapping kaldırıldı - database'deki path direkt kullanılıyor
    
    deinit {
        stopUploadService()
        NotificationCenter.default.removeObserver(self)
    }
} 