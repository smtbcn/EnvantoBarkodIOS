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
        
        // Cleanup mantığı kaldırıldı - Sadece pending resimleri işle
        
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
            
            // 🚨 GÜVENLİK TEMİZLİĞİ: Android benzeri güvenlik önlemi
            print("🚨 \(UploadService.TAG): Güvenlik temizliği başlatılıyor...")
            let cleanupResult = dbManager.clearAllPendingUploads()
            
            if cleanupResult {
                print("✅ \(UploadService.TAG): Güvenlik temizliği tamamlandı - Yetkisiz cihaz resimleri silindi")
                
                // UI refresh tetikle (temizlik sonrası liste güncellensin)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .uploadCompleted, object: nil)
                    print("📢 \(UploadService.TAG): Güvenlik temizliği sonrası UI refresh tetiklendi")
                }
            } else {
                print("⚠️ \(UploadService.TAG): Güvenlik temizliği sırasında hata oluştu")
            }
            
            return
        }
        
        // Tüm kontroller geçti - Upload işlemini başlat
        isUploading = true
        uploadStatus = "Yükleniyor..."
        print("🚀 \(UploadService.TAG): Upload işlemi başlatılıyor - \(totalCount) resim")
        
        var uploadedCount = 0
        
        for (index, imageRecord) in pendingImages.enumerated() {
            uploadProgress = (index, totalCount)
            print("📤 \(UploadService.TAG): === RESİM UPLOAD DEBUG (\(index + 1)/\(totalCount)) ===")
            print("👤 \(UploadService.TAG): Müşteri: '\(imageRecord.musteriAdi)'")
            print("📁 \(UploadService.TAG): DB Path: '\(imageRecord.resimYolu)'")
            print("👨‍💼 \(UploadService.TAG): Yükleyen: '\(imageRecord.yukleyen)'")
            print("🆔 \(UploadService.TAG): DB ID: \(imageRecord.id)")
            print("📅 \(UploadService.TAG): Tarih: '\(imageRecord.tarih)'")
            print("🏷️ \(UploadService.TAG): Yuklendi Flag: \(imageRecord.yuklendi)")
            
            // PATH KONTROL DETAYI
            if imageRecord.resimYolu.isEmpty {
                print("❌ \(UploadService.TAG): KRITIK HATA - Database'deki path BOŞ!")
                continue
            } else {
                print("✅ \(UploadService.TAG): Database path dolu: \(imageRecord.resimYolu.count) karakter")
            }
            
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
                
                print("🎯 \(UploadService.TAG): === UPLOAD BAŞARILI - DATABASE GÜNCELLEMESİ ===")
                print("📊 \(UploadService.TAG): Record ID: \(imageRecord.id)")
                print("👤 \(UploadService.TAG): Müşteri: \(imageRecord.musteriAdi)")
                print("📁 \(UploadService.TAG): Path: \(imageRecord.resimYolu)")
                print("🏷️ \(UploadService.TAG): Eski yuklendi değeri: \(imageRecord.yuklendi)")
                
                // Database'de yuklendi flag'ini güncelle
                let updateResult = dbManager.updateUploadStatus(id: imageRecord.id, yuklendi: 1)
                
                if updateResult {
                    print("✅ \(UploadService.TAG): Database güncelleme BAŞARILI! ID: \(imageRecord.id) → yuklendi=1")
                    
                    // Güncelleme sonrası doğrulama
                    let allPending = dbManager.getAllPendingImages()
                    let stillPending = allPending.first(where: { $0.id == imageRecord.id })
                    
                    if stillPending == nil {
                        print("✅ \(UploadService.TAG): DOĞRULAMA OK - Resim artık pending listesinde yok")
                    } else {
                        print("⚠️ \(UploadService.TAG): DOĞRULAMA BAŞARISIZ - Resim hala pending listesinde!")
                        print("   Güncel yuklendi değeri: \(stillPending?.yuklendi ?? -1)")
                    }
                } else {
                    print("❌ \(UploadService.TAG): Database güncelleme BAŞARISIZ! ID: \(imageRecord.id)")
                }
                
                uploadProgress = (uploadedCount, totalCount)
                uploadStatus = "Yüklendi: \(uploadedCount)/\(totalCount)"
                
                print("✅ \(UploadService.TAG): Resim başarıyla yüklendi: \(imageRecord.musteriAdi)")
                
                // Her başarılı upload sonrasında UI'ı anında güncelle
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .uploadCompleted, object: nil)
                    print("📢 \(UploadService.TAG): Tek resim yüklendi - UI refresh notification gönderildi")
                }
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
        
        // UI refresh tetikle (upload tamamlandığında resim listesi güncellenir)
        if uploadedCount > 0 {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .uploadCompleted, object: nil)
                print("📢 \(UploadService.TAG): Upload tamamlandı - UI refresh notification gönderildi")
            }
        }
    }
    
    // MARK: - Server Upload (Android uploadImageToServer benzeri)
    private func uploadImageToServer(imageRecord: BarkodResim) async -> Bool {
        do {
            // Path Mapping: Database'deki eski path'i gerçek path ile eşleştir
            let actualPath = findActualImagePath(for: imageRecord)
            
            if actualPath.isEmpty {
                print("❌ \(UploadService.TAG): Resim dosyası bulunamadı: \(imageRecord.resimYolu)")
                print("   Müşteri: \(imageRecord.musteriAdi)")
                print("   Beklenen dosya adı: \(URL(fileURLWithPath: imageRecord.resimYolu).lastPathComponent)")
                return false
            }
            
            print("📂 \(UploadService.TAG): Gerçek dosya yolu: \(actualPath)")
            
            // Base URL (Android ile aynı) + Debug test
            let baseURL = "https://envanto.app/barkod_yukle_android"
            
            // Önce debug endpoint test et
            if let debugURL = URL(string: "\(baseURL)/upload.asp?debug=1") {
                print("🔧 \(UploadService.TAG): Debug endpoint test ediliyor: \(debugURL)")
                
                do {
                    let (debugData, debugResponse) = try await URLSession.shared.data(from: debugURL)
                    if let debugString = String(data: debugData, encoding: .utf8) {
                        print("🔧 \(UploadService.TAG): Debug response: \(debugString)")
                    }
                } catch {
                    print("🔧 \(UploadService.TAG): Debug test hatası: \(error)")
                }
            }
            
            guard let url = URL(string: "\(baseURL)/upload.asp") else {
                print("❌ \(UploadService.TAG): Geçersiz URL")
                return false
            }
            
            print("🌐 \(UploadService.TAG): === UPLOAD REQUEST BAŞLIYOR ===")
            print("🔗 \(UploadService.TAG): URL: \(url)")
            print("👤 \(UploadService.TAG): Müşteri Adı: '\(imageRecord.musteriAdi)'")
            print("👨‍💼 \(UploadService.TAG): Yükleyen: '\(imageRecord.yukleyen)'")
            print("📁 \(UploadService.TAG): Dosya Path: '\(actualPath)'")
            
            // Multipart form data oluştur (Android ile aynı)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30.0
            
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            print("🏷️ \(UploadService.TAG): Boundary: \(boundary)")
            print("📝 \(UploadService.TAG): Content-Type: multipart/form-data; boundary=\(boundary)")
            
            var body = Data()
            
            // Action field kaldırıldı - Sunucu kodu action field kontrol etmiyor
            
            // Müşteri adı (Sunucunun beklediği field: musteri_adi)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"musteri_adi\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(imageRecord.musteriAdi)\r\n".data(using: .utf8)!)
            print("✅ \(UploadService.TAG): Müşteri adı field eklendi: '\(imageRecord.musteriAdi)'")
            
            // Yükleyen (Sunucunun beklediği field: yukleyen)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"yukleyen\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(imageRecord.yukleyen)\r\n".data(using: .utf8)!)
            print("✅ \(UploadService.TAG): Yükleyen field eklendi: '\(imageRecord.yukleyen)'")
            
            // Resim dosyası - Gerçek path'i kullan
            let imageData = try Data(contentsOf: URL(fileURLWithPath: actualPath))
            let fileName = URL(fileURLWithPath: actualPath).lastPathComponent
            
            print("📊 \(UploadService.TAG): Resim bilgileri:")
            print("   📄 Dosya adı: '\(fileName)'")
            print("   📏 Dosya boyutu: \(imageData.count) bytes (\(String(format: "%.2f", Double(imageData.count) / 1024 / 1024)) MB)")
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"resim\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            print("✅ \(UploadService.TAG): Resim field eklendi (name: resim, filename: \(fileName))")
            
            // Boundary bitişi
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            print("📦 \(UploadService.TAG): Total request body size: \(body.count) bytes")
            print("🚀 \(UploadService.TAG): HTTP Request başlatılıyor...")
            
            // API çağrısı
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("📡 \(UploadService.TAG): === RESPONSE ALINDI ===")
            
            // HTTP yanıt kontrolü
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ \(UploadService.TAG): HTTP Response alınamadı")
                return false
            }
            
            print("📊 \(UploadService.TAG): HTTP Status Code: \(httpResponse.statusCode)")
            print("📋 \(UploadService.TAG): HTTP Headers:")
            for (key, value) in httpResponse.allHeaderFields {
                print("   \(key): \(value)")
            }
            
            // Response data'yı string olarak göster
            let responseString = String(data: data, encoding: .utf8) ?? "Response decode edilemedi"
            print("📥 \(UploadService.TAG): Raw Response Body:")
            print("📄 \(UploadService.TAG): \(responseString)")
            print("📏 \(UploadService.TAG): Response size: \(data.count) bytes")
            
            if httpResponse.statusCode != 200 {
                print("❌ \(UploadService.TAG): HTTP Error - Expected 200, Got: \(httpResponse.statusCode)")
                return false
            }
            
            // JSON decode attempt
            do {
                let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
                
                print("✅ \(UploadService.TAG): JSON decode başarılı:")
                print("   📊 Success: \(uploadResponse.isSuccess)")
                print("   📝 Message: \(uploadResponse.message)")
                print("   ⚠️ Error: \(uploadResponse.error)")
                
                if uploadResponse.isSuccess {
                    print("🎉 \(UploadService.TAG): Upload BAŞARILI! Message: \(uploadResponse.message)")
                    return true
                } else {
                    print("❌ \(UploadService.TAG): Upload BAŞARISIZ! Error: \(uploadResponse.error)")
                    return false
                }
            } catch {
                print("❌ \(UploadService.TAG): JSON decode hatası: \(error)")
                print("💡 \(UploadService.TAG): Raw response başka format olabilir")
                
                // Eğer response HTML içeriyorsa
                if responseString.contains("<html") || responseString.contains("<!DOCTYPE") {
                    print("🌐 \(UploadService.TAG): Response HTML formatında - Server hatası olabilir")
                } else if responseString.contains("basari") {
                    print("💡 \(UploadService.TAG): Response Türkçe JSON formatında olabilir")
                }
                
                return false
            }
            
        } catch {
            print("💥 \(UploadService.TAG): Upload hatası: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Path Helper (Detaylı Debug)
    private func findActualImagePath(for imageRecord: BarkodResim) -> String {
        print("🔍 \(UploadService.TAG): === PATH DEBUG BAŞLIYOR ===")
        
        let imagePath = imageRecord.resimYolu
        print("📋 \(UploadService.TAG): DB'den gelen path: '\(imagePath)'")
        print("📏 \(UploadService.TAG): Path uzunluğu: \(imagePath.count) karakter")
        
        if imagePath.isEmpty {
            print("❌ \(UploadService.TAG): PATH BOŞ! Database sorunu")
            return ""
        }
        
        // Path formatını analiz et
        if imagePath.hasPrefix("/var/mobile") {
            print("✅ \(UploadService.TAG): iOS full path formatı")
        } else if imagePath.hasPrefix("Documents/") {
            print("⚠️ \(UploadService.TAG): Relative path formatı")
        } else {
            print("❓ \(UploadService.TAG): Bilinmeyen path formatı")
        }
        
        // Dosya varlığını kontrol et
        print("🔍 \(UploadService.TAG): Dosya varlığı kontrol ediliyor...")
        let fileExists = FileManager.default.fileExists(atPath: imagePath)
        print("📁 \(UploadService.TAG): FileManager.fileExists = \(fileExists)")
        
        if fileExists {
            print("✅ \(UploadService.TAG): DOSYA BULUNDU: \(imagePath)")
            return imagePath
        } else {
            print("❌ \(UploadService.TAG): DOSYA BULUNAMADI: \(imagePath)")
            
            // Alternative path dene - Documents klasörü
            if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                print("🔍 \(UploadService.TAG): Documents directory: \(documentsDir.path)")
                
                // Envanto klasör kontrol
                let envantoDir = documentsDir.appendingPathComponent("Envanto")
                print("🔍 \(UploadService.TAG): Envanto directory: \(envantoDir.path)")
                print("📁 \(UploadService.TAG): Envanto exists: \(FileManager.default.fileExists(atPath: envantoDir.path))")
                
                // Müşteri klasör kontrol
                let customerDir = envantoDir.appendingPathComponent(imageRecord.musteriAdi)
                print("🔍 \(UploadService.TAG): Customer directory: \(customerDir.path)")
                print("📁 \(UploadService.TAG): Customer exists: \(FileManager.default.fileExists(atPath: customerDir.path))")
                
                // Klasör içeriği listele
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: customerDir.path)
                    print("📋 \(UploadService.TAG): Customer klasöründeki dosyalar: \(contents)")
                } catch {
                    print("❌ \(UploadService.TAG): Customer klasör okuma hatası: \(error)")
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