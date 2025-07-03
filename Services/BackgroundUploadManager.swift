import Foundation
import UIKit
import BackgroundTasks
import Network

// MARK: - Background Upload Manager (iOS Background App Refresh)
class BackgroundUploadManager {
    static let shared = BackgroundUploadManager()
    
    // Background task identifier
    private static let backgroundTaskIdentifier = "com.envanto.barcode.upload"
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    

    
    private init() {
        registerBackgroundTasks()
        startNetworkMonitoring()
    }
    
    // MARK: - Background Task Registration
    private func registerBackgroundTasks() {
        // Background App Refresh task'ını kaydet
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundUploadManager.backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundUpload(task: task as! BGAppRefreshTask)
        }
        
        print("📱 Background task kaydedildi: \(BackgroundUploadManager.backgroundTaskIdentifier)")
    }
    
    // MARK: - Schedule Background Task
    func scheduleBackgroundUpload() {
        // iOS Background Task sınırlamaları nedeniyle basit timer kullanıyoruz
        print("📅 Background upload timer başlatılıyor...")
        
        // Network değişikliği algılandığında kısa bir süre sonra upload kontrol et
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            Task {
                await self.performBackgroundUpload()
            }
        }
    }
    
    // MARK: - Alternative: Immediate Upload Check (iOS Background sınırlamaları için)
    func checkPendingUploadsImmediately() {
        Task {
            await performBackgroundUpload()
        }
    }
    
    // MARK: - Handle Background Upload
    private func handleBackgroundUpload(task: BGAppRefreshTask) {
        print("🚀 Background upload task başladı")
        
        // Task'ın iptal edilme durumunu handle et
        task.expirationHandler = {
            print("⏰ Background task süresi doldu")
            task.setTaskCompleted(success: false)
        }
        
        // Upload işlemini başlat
        Task {
            let success = await performBackgroundUpload()
            
            // Task'ı tamamla
            task.setTaskCompleted(success: success)
            
            // Bir sonraki task'ı zamanla
            if success {
                self.scheduleBackgroundUpload()
            }
        }
    }
    
    // MARK: - Perform Background Upload
    private func performBackgroundUpload() async -> Bool {
        // 🔒 Global Upload Lock - UploadService ile çakışma önleme
        guard Constants.UploadLock.lockUpload() else {
            print("⏸️ Background upload: Upload zaten devam ediyor (UploadService), atlanıyor")
            return false
        }
        defer { Constants.UploadLock.unlockUpload() }
        
        print("📤 Background upload başlıyor...")
        
        // WiFi ayarını kontrol et
        let wifiOnly = UserDefaults.standard.bool(forKey: "upload_wifi_only")
        
        // Network kontrolü
        let uploadCheck = NetworkUtils.canUploadWithSettings(wifiOnly: wifiOnly)
        
        if !uploadCheck.canUpload {
            print("🚫 Background upload durumu: \(uploadCheck.reason)")
            return false
        }
        
        // Database'den pending resimleri al
        let dbManager = DatabaseManager.getInstance()
        let pendingImages = dbManager.getAllPendingImages()
        
        if pendingImages.isEmpty {
            print("✅ Background upload: Yüklenecek resim yok")
            return true
        }
        
        print("📊 Background upload: \(pendingImages.count) resim yüklenecek")
        
        // Cihaz yetki kontrolü
        let deviceId = DeviceIdentifier.getUniqueDeviceId()
        let isAuthorized = dbManager.isCihazYetkili(cihazBilgisi: deviceId)
        
        if !isAuthorized {
            print("🚫 Background upload: Cihaz yetkili değil")
            return false
        }
        
        // Upload işlemini başlat (maksimum 3 resim - iOS background limit)
        let maxUploads = min(pendingImages.count, 3)
        var uploadedCount = 0
        
        for i in 0..<maxUploads {
            let imageRecord = pendingImages[i]
            
            // 🔍 CRITICAL: Upload öncesi database'de hala pending mi kontrol et
            let currentPendingImages = dbManager.getAllPendingImages()
            let stillPending = currentPendingImages.first(where: { $0.id == imageRecord.id })
            
            if stillPending == nil {
                print("⏭️ Background upload: Resim zaten yüklenmiş, atlanıyor - ID: \(imageRecord.id)")
                continue
            }
            
            // Network kontrolü (her resim için)
            let currentCheck = NetworkUtils.canUploadWithSettings(wifiOnly: wifiOnly)
            if !currentCheck.canUpload {
                break
            }
            
            // Resmi yükle
            let success = await uploadImageToServer(imageRecord: imageRecord)
            
            if success {
                // Database'de yuklendi flag'ini güncelle
                let updateResult = dbManager.updateUploadStatus(id: imageRecord.id, yuklendi: 1)
                
                if updateResult {
                    uploadedCount += 1
                    print("✅ Background upload: Resim yüklendi (\(uploadedCount)/\(maxUploads))")
                } else {
                    print("❌ Background upload: Database güncellenemedi")
                }
            } else {
                print("❌ Background upload: Resim yüklenemedi")
                break
            }
        }
        
        print("🎯 Background upload tamamlandı: \(uploadedCount) resim yüklendi")
        
        // Notification gönder (kullanıcıya bilgi ver)
        if uploadedCount > 0 {
            sendUploadNotification(count: uploadedCount)
        }
        
        return uploadedCount > 0
    }
    
    // MARK: - Network Monitoring (WiFi değişimlerini takip et)
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    print("📶 WiFi bağlantısı algılandı - Background upload kontrol ediliyor")
                    
                    // WiFi bağlantısı geldiğinde upload'u tetikle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self?.scheduleBackgroundUpload()
                    }
                }
            }
        }
        
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Upload Implementation (UploadService'ten kopyalandı)
    private func uploadImageToServer(imageRecord: BarkodResim) async -> Bool {
        do {
            // Path kontrolü
            let actualPath = findActualImagePath(for: imageRecord)
            if actualPath.isEmpty {
                return false
            }
            
            // Base URL
            let baseURL = "https://envanto.app/barkod_yukle_android"
            guard let url = URL(string: "\(baseURL)/upload.asp") else {
                return false
            }
            
            // Multipart form data oluştur
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30.0
            
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            
            // Müşteri adı
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"musteri_adi\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(imageRecord.musteriAdi)\r\n".data(using: .utf8)!)
            
            // Yükleyen
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"yukleyen\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(imageRecord.yukleyen)\r\n".data(using: .utf8)!)
            
            // Resim dosyası
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
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            // JSON decode
            do {
                let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
                return uploadResponse.isSuccess
            } catch {
                return false
            }
            
        } catch {
            return false
        }
    }
    
    // MARK: - Path Helper
    private func findActualImagePath(for imageRecord: BarkodResim) -> String {
        let imagePath = imageRecord.resimYolu
        
        if imagePath.isEmpty {
            return ""
        }
        
        // Dosya varlığını kontrol et
        if FileManager.default.fileExists(atPath: imagePath) {
            return imagePath
        }
        
        return ""
    }
    
    // MARK: - Notification
    private func sendUploadNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Envanto Barkod"
        content.body = "\(count) resim başarıyla yüklendi"
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification hatası: \(error)")
            }
        }
    }
} 