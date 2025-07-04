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
        
        stopUploadService() // Mevcut servisi durdur
        
        // 🔋 PIL OPTİMİZASYONU: 10 saniye → 60 saniye (6x daha az pil tüketimi)
        uploadTimer = Timer.scheduledTimer(withTimeInterval: Constants.Timing.uploadCheckInterval, repeats: true) { [weak self] _ in
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
        
    }
    
    // MARK: - Upload Logic (Android UploadRetryService benzeri)
    @MainActor
    private func checkAndUploadPendingImages(wifiOnly: Bool) async {
        // 🔒 Global Upload Lock - BackgroundUploadManager ile çakışma önleme
        guard Constants.UploadLock.lockUpload() else {
            uploadStatus = "Background upload devam ediyor..."
            return
        }
        defer { Constants.UploadLock.unlockUpload() }
        
        // Database'den yüklenmemiş resimleri al
        let dbManager = DatabaseManager.getInstance()
        
        let pendingImages = dbManager.getAllPendingImages()
        let totalCount = pendingImages.count
        
        // 🔋 PIL OPTİMİZASYONU: Bekleyen resim yoksa timer'ı durdur
        if totalCount == 0 {
            uploadStatus = "Yüklenecek resim yok"
            uploadProgress = (0, 0)
            isUploading = false
            
            // Timer'ı durdur - gereksiz pil tüketimini önle
            stopUploadService()
            return
        }
        
        // Network kontrolü
        let uploadCheck = NetworkUtils.canUploadWithSettings(wifiOnly: wifiOnly)
        
        if !uploadCheck.canUpload {
            uploadStatus = uploadCheck.reason
            uploadProgress = (0, totalCount)
            isUploading = false
            return
        }
        
        // Cihaz yetki kontrolü
        let deviceId = DeviceIdentifier.getUniqueDeviceId()
        let isAuthorized = dbManager.isCihazYetkili(cihazBilgisi: deviceId)
        
        if !isAuthorized {
            uploadStatus = "Cihaz yetkili değil"
            uploadProgress = (0, totalCount)
            isUploading = false
            
            // 🚨 GÜVENLİK TEMİZLİĞİ: Android benzeri güvenlik önlemi
            let cleanupResult = dbManager.clearAllPendingUploads()
            
            if cleanupResult {
                
                // UI refresh tetikle (temizlik sonrası liste güncellensin)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .uploadCompleted, object: nil)
                }
            }
            
            // Timer'ı durdur - yetkisiz cihazda gereksiz işlem yapma
            stopUploadService()
            return
        }
        
        // Tüm kontroller geçti - Upload işlemini başlat
        isUploading = true
        uploadStatus = "Yükleniyor..."
        
        var uploadedCount = 0
        
        for (index, imageRecord) in pendingImages.enumerated() {
            uploadProgress = (index, totalCount)
            
            // 🔍 CRITICAL: Upload öncesi database'de hala pending mi kontrol et
            let currentPendingImages = dbManager.getAllPendingImages()
            let stillPending = currentPendingImages.first(where: { $0.id == imageRecord.id })
            
            if stillPending == nil {
                continue
            }
            
            // PATH KONTROL DETAYI
            if imageRecord.resimYolu.isEmpty {
                continue
            }
            
            // Her resim için network kontrolü (WiFi kesilirse dursun)
            let currentCheck = NetworkUtils.canUploadWithSettings(wifiOnly: wifiOnly)
            if !currentCheck.canUpload {
                uploadStatus = currentCheck.reason
                break
            }
            
            // Resmi yükle
            let success = await uploadImageToServer(imageRecord: imageRecord)
            
            if success {
                uploadedCount += 1
                
                // Database'de yuklendi flag'ini güncelle
                let updateResult = dbManager.updateUploadStatus(id: imageRecord.id, yuklendi: 1)
                
                if updateResult {
                    // Güncelleme sonrası doğrulama
                    let allPending = dbManager.getAllPendingImages()
                    let stillPending = allPending.first(where: { $0.id == imageRecord.id })
                }
                
                uploadProgress = (uploadedCount, totalCount)
                uploadStatus = "Yüklendi: \(uploadedCount)/\(totalCount)"
                
                // Her başarılı upload sonrasında UI'ı anında güncelle
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .uploadCompleted, object: nil)
                }
            } else {
                // Hata durumunda kısa bekle
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 saniye
            }
        }
        
        isUploading = false
        
        if uploadedCount == totalCount {
            uploadStatus = "Tüm resimler yüklendi ✅"
            // 🔋 PIL OPTİMİZASYONU: Tüm resimler yüklendiyse timer'ı durdur
            stopUploadService()
        } else if uploadedCount > 0 {
            uploadStatus = "\(uploadedCount) resim yüklendi, \(totalCount - uploadedCount) bekliyor"
        }
        
        uploadProgress = (uploadedCount, totalCount)
        
        // UI refresh tetikle (upload tamamlandığında resim listesi güncellenir)
        if uploadedCount > 0 {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .uploadCompleted, object: nil)
            }
        }
    }
    
    // MARK: - Server Upload (Android uploadImageToServer benzeri)
    private func uploadImageToServer(imageRecord: BarkodResim) async -> Bool {
        do {
            // Path Mapping: Database'deki eski path'i gerçek path ile eşleştir
            let actualPath = findActualImagePath(for: imageRecord)
            
            if actualPath.isEmpty {
                return false
            }
            
            
            // Base URL (Android ile aynı) + Debug test
            let baseURL = "https://envanto.app/barkod_yukle_android"
            
            // Önce debug endpoint test et
            if let debugURL = URL(string: "\(baseURL)/upload.asp?debug=1") {
                
                do {
                    let (debugData, debugResponse) = try await URLSession.shared.data(from: debugURL)
                    if let debugString = String(data: debugData, encoding: .utf8) {
                    }
                } catch {
                }
            }
            
            guard let url = URL(string: "\(baseURL)/upload.asp") else {
                return false
            }
            
            
            // Multipart form data oluştur (Android ile aynı)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30.0
            
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            
            var body = Data()
            
            // Action field kaldırıldı - Sunucu kodu action field kontrol etmiyor
            
            // Müşteri adı (Sunucunun beklediği field: musteri_adi)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"musteri_adi\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(imageRecord.musteriAdi)\r\n".data(using: .utf8)!)
            
            // Yükleyen (Sunucunun beklediği field: yukleyen)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"yukleyen\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(imageRecord.yukleyen)\r\n".data(using: .utf8)!)
            
            // Resim dosyası - Gerçek path'i kullan
            let imageData = try Data(contentsOf: URL(fileURLWithPath: actualPath))
            let fileName = URL(fileURLWithPath: actualPath).lastPathComponent
            
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"resim\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Boundary bitişi
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            
            // API çağrısı
            let (data, response) = try await URLSession.shared.data(for: request)
            
            
            // HTTP yanıt kontrolü
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            for (key, value) in httpResponse.allHeaderFields {
            }
            
            // Response data'yı string olarak göster
            let responseString = String(data: data, encoding: .utf8) ?? "Response decode edilemedi"
            
            if httpResponse.statusCode != 200 {
                return false
            }
            
            // JSON decode attempt
            do {
                let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
                
                
                if uploadResponse.isSuccess {
                    return true
                } else {
                    return false
                }
            } catch {
                
                // Eğer response HTML içeriyorsa
                if responseString.contains("<html") || responseString.contains("<!DOCTYPE") {
                } else if responseString.contains("basari") {
                }
                
                return false
            }
            
        } catch {
            return false
        }
    }
    
    // MARK: - Path Helper (Detaylı Debug)
    private func findActualImagePath(for imageRecord: BarkodResim) -> String {
        
        let imagePath = imageRecord.resimYolu
        
        if imagePath.isEmpty {
            return ""
        }
        
        // Path formatını analiz et
        if imagePath.hasPrefix("/var/mobile") {
        } else if imagePath.hasPrefix("Documents/") {
        } else {
        }
        
        // Dosya varlığını kontrol et
        let fileExists = FileManager.default.fileExists(atPath: imagePath)
        
        if fileExists {
            return imagePath
        } else {
            
            // Alternative path dene - Documents klasörü
            if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                
                // Envanto klasör kontrol
                let envantoDir = documentsDir.appendingPathComponent("Envanto")
                
                // Müşteri klasör kontrol
                let customerDir = envantoDir.appendingPathComponent(imageRecord.musteriAdi)
                
                // Klasör içeriği listele
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: customerDir.path)
                } catch {
                }
            }
            
            return ""
        }
    }
    
    deinit {
        stopUploadService()
        NotificationCenter.default.removeObserver(self)
    }
} 
