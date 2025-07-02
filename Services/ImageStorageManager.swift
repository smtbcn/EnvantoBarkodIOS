import Foundation
import UIKit

class ImageStorageManager {
    
    // MARK: - Constants
    private static let TAG = "ImageStorageManager"
    
    // MARK: - Save Image (App Documents Only)
    static func saveImage(image: UIImage, customerName: String, isGallery: Bool, yukleyen: String) async -> String? {
        
        // App Documents'a kaydet (Files uygulamasından erişilebilir)
        if let documentsPath = saveToAppDocuments(image: image, customerName: customerName, isGallery: isGallery) {
            print("✅ App Documents'a kaydedildi: \(documentsPath)")
            
            // Relative path'i de göster
            if let documentsDir = getAppDocumentsDirectory() {
                let relativePath = documentsPath.replacingOccurrences(of: documentsDir.path, with: "Documents")
                print("📱 Files App'te görünecek yol: \(relativePath)")
            }
            
            // Dosya kontrol et
            let fileExists = FileManager.default.fileExists(atPath: documentsPath)
            print("📁 Dosya kontrolü: \(fileExists ? "✅ MEVCUT" : "❌ YOK")")
            
            // 🗄️ Database'e kaydet 
            print("🗄️ Database'e kaydediliyor: \(customerName)")
            print("📁 Path: \(documentsPath)")
            
            let dbManager = DatabaseManager.getInstance()
            let dbSaved = dbManager.insertBarkodResim(
                musteriAdi: customerName,
                resimYolu: documentsPath,
                yukleyen: yukleyen
            )
            
            if dbSaved {
                print("✅ Database'e kaydedildi")
                dbManager.printDatabaseInfo()
                
                // Upload tetikle
                triggerUploadAfterSave()
            } else {
                print("❌ Database kayıt hatası")
            }
            
            return documentsPath
        }
        
        print("❌ Resim kaydedilemedi")
        return nil
    }
    
    // MARK: - Upload Trigger (Android mantığı)
    private static func triggerUploadAfterSave() {
        // UserDefaults'tan WiFi ayarını oku
        let wifiOnly = UserDefaults.standard.bool(forKey: Constants.UserDefaults.wifiOnly)
        
        print("🚀 Upload tetikleniyor - WiFi only: \(wifiOnly)")
        
        // Upload servisini başlat
        UploadService.shared.startUploadService(wifiOnly: wifiOnly)
    }
    
    // MARK: - Debug: Print actual Documents path
    private static func printActualDocumentsPath() {
        if let documentsDir = getAppDocumentsDirectory() {
            print("📱 ACTUAL Documents Path: \(documentsDir.path)")
            print("📁 Envanto klasör yolu: \(documentsDir.appendingPathComponent("Envanto").path)")
            print("💡 Files App'te 'Bu iPhone/iPad' > 'Envanto Barkod' altında görünür")
            
            // Envanto klasörü var mı kontrol et
            let envantoDir = documentsDir.appendingPathComponent("Envanto")
            if FileManager.default.fileExists(atPath: envantoDir.path) {
                print("✅ Envanto klasörü mevcut")
                
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: envantoDir.path)
                    print("📁 Envanto içindeki müşteri klasörleri: \(contents)")
                    
                    // Her müşteri klasöründe kaç resim var
                    for customerFolder in contents.prefix(3) {
                        let customerPath = envantoDir.appendingPathComponent(customerFolder)
                        if let customerContents = try? FileManager.default.contentsOfDirectory(atPath: customerPath.path) {
                            let imageCount = customerContents.filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg") || $0.hasSuffix(".png") }.count
                            print("   👤 \(customerFolder): \(imageCount) resim")
                        }
                    }
                } catch {
                    print("❌ Envanto klasörü içeriği okunamadı: \(error)")
                }
            } else {
                print("❌ Envanto klasörü henüz oluşturulmamış")
            }
        } else {
            print("❌ Documents directory alınamadı")
        }
    }

    
    // MARK: - Save to App Documents (Files App Access)
    private static func saveToAppDocuments(image: UIImage, customerName: String, isGallery: Bool) -> String? {
        guard let customerDir = getAppDocumentsCustomerDir(for: customerName) else {
            print("❌ App Documents müşteri klasörü alınamadı")
            return nil
        }
        
        // Android'deki gibi dosya adı oluştur
        let fileName = generateFileName(customerName: customerName, isGallery: isGallery)
        let filePath = customerDir.appendingPathComponent(fileName)
        
        // Aynı isimde dosya varsa sayı ekle (Android mantığı)
        let finalPath = getUniqueFilePath(basePath: filePath)
        
        print("💾 Kaydetme yolu: \(finalPath.path)")
        
        // Resmi JPEG olarak kaydet
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Resim JPEG'e dönüştürülemedi")
            return nil
        }
        
        do {
            try imageData.write(to: finalPath)
            print("✅ App Documents'a kaydedildi: \(finalPath.path)")
            
            // Dosya boyutunu da kontrol et
            if let attributes = try? FileManager.default.attributesOfItem(atPath: finalPath.path),
               let fileSize = attributes[.size] as? Int64 {
                print("📏 Dosya boyutu: \(fileSize) bytes")
            }
            
            return finalPath.path
        } catch {
            print("❌ App Documents kaydetme hatası: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - PhotosPicker için URL'den kaydetme
    static func saveImageFromURL(sourceURL: URL, customerName: String, yukleyen: String) async -> String? {
        guard let imageData = try? Data(contentsOf: sourceURL),
              let image = UIImage(data: imageData) else {
            print("❌ URL'den resim yüklenemedi: \(sourceURL)")
            return nil
        }
        
        return await saveImage(image: image, customerName: customerName, isGallery: true, yukleyen: yukleyen)
    }
    
    // MARK: - Generate File Name (Android Pattern + Customer)
    private static func generateFileName(customerName: String, isGallery: Bool) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timeStamp = dateFormatter.string(from: Date())
        
        // Android'deki gibi güvenli müşteri adı
        let safeCustomerName = customerName.replacingOccurrences(of: "[^a-zA-Z0-9.-]", 
                                                                with: "_", 
                                                                options: .regularExpression)
        
        let prefix = isGallery ? "GALLERY" : "CAMERA"
        return "\(safeCustomerName)_\(prefix)_\(timeStamp).jpg"
    }
    
    // MARK: - App Documents Directory Functions (Files App Access)
    private static func getAppDocumentsDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, 
                                       in: .userDomainMask).first
    }
    
    private static func getAppDocumentsCustomerDir(for customerName: String) -> URL? {
        guard let documentsDir = getAppDocumentsDirectory() else {
            print("❌ App Documents directory alınamadı")
            return nil
        }
        
        let envantoDir = documentsDir.appendingPathComponent("Envanto")
        
        // Android'deki gibi güvenli klasör adı oluştur
        let safeCustomerName = customerName.replacingOccurrences(of: "[^a-zA-Z0-9.-]", 
                                                                with: "_", 
                                                                options: .regularExpression)
        
        let customerDir = envantoDir.appendingPathComponent(safeCustomerName)
        
        // Klasör yoksa oluştur
        if !FileManager.default.fileExists(atPath: customerDir.path) {
            do {
                try FileManager.default.createDirectory(at: customerDir, 
                                                      withIntermediateDirectories: true, 
                                                      attributes: nil)
                print("📁 App Documents müşteri klasörü oluşturuldu: \(customerDir.path)")
            } catch {
                print("❌ App Documents müşteri klasörü oluşturulamadı: \(error.localizedDescription)")
                return nil
            }
        }
        
        return customerDir
    }
    
    private static func getUniqueFilePath(basePath: URL) -> URL {
        var finalPath = basePath
        var counter = 1
        
        while FileManager.default.fileExists(atPath: finalPath.path) {
            let fileName = basePath.deletingPathExtension().lastPathComponent
            let fileExtension = basePath.pathExtension
            let newFileName = "\(fileName)_\(counter).\(fileExtension)"
            finalPath = basePath.deletingLastPathComponent().appendingPathComponent(newFileName)
            counter += 1
        }
        
        return finalPath
    }
    
    // MARK: - List Customer Images (App Documents)
    static func listCustomerImages(customerName: String) async -> [String] {
        // App Documents'tan ara
        let documentsImages = getAppDocumentsImages(customerName: customerName)
        
        print("📋 \(customerName) için App Documents'ta \(documentsImages.count) resim bulundu")
        return documentsImages.sorted()
    }
    
    private static func getAppDocumentsImages(customerName: String) -> [String] {
        guard let customerDir = getAppDocumentsCustomerDir(for: customerName) else { return [] }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: customerDir, 
                                                                       includingPropertiesForKeys: nil)
            
            // Sadece resim dosyalarını filtrele
            let imagePaths = fileURLs
                .filter { url in
                    let pathExtension = url.pathExtension.lowercased()
                    return ["jpg", "jpeg", "png"].contains(pathExtension)
                }
                .map { $0.path }
                .sorted()
            
            return imagePaths
        } catch {
            print("❌ App Documents müşteri resimleri listeleme hatası: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Delete Image (App Documents)
    static func deleteImage(at path: String) async -> Bool {
        let fileURL = URL(fileURLWithPath: path)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ App Documents'tan resim silindi: \(path)")
            
            // Boş klasörleri temizle
            cleanupEmptyDirectories(fileURL.deletingLastPathComponent())
            return true
        } catch {
            print("❌ App Documents silme hatası: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Cleanup Empty Directories
    private static func cleanupEmptyDirectories(_ directory: URL) {
        let contents = try? FileManager.default.contentsOfDirectory(at: directory, 
                                                                   includingPropertiesForKeys: nil)
        
        // Klasör boşsa ve Envanto klasörü değilse sil
        if contents?.isEmpty == true && directory.lastPathComponent != "Envanto" {
            do {
                try FileManager.default.removeItem(at: directory)
                print("🧹 Boş klasör silindi: \(directory.path)")
                
                // Üst klasörü de kontrol et
                cleanupEmptyDirectories(directory.deletingLastPathComponent())
            } catch {
                print("❌ Boş klasör silme hatası: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Delete Customer Images (App Documents)
    static func deleteCustomerImages(customerName: String) async -> Bool {
        print("🗑️ deleteCustomerImages çağrıldı: '\(customerName)'")
        
        // 🎯 Klasör adını aynı şekilde dönüştür (getAppDocumentsCustomerDir ile aynı mantık)
        let safeCustomerName = customerName.replacingOccurrences(of: "[^a-zA-Z0-9.-]", 
                                                                with: "_", 
                                                                options: .regularExpression)
        print("🗑️ Güvenli klasör adı: '\(safeCustomerName)'")
        
        var fileSuccess = false
        var dbSuccess = false
        
        // 1️⃣ Database kayıtlarını sil
        print("🗄️ Database kayıtları siliniyor...")
        dbSuccess = DatabaseManager.getInstance().deleteCustomerImages(musteriAdi: customerName)
        
        // 2️⃣ App Documents müşteri klasörünü sil
        if let customerDir = getAppDocumentsCustomerDir(for: customerName) {
            print("🗑️ Silinecek klasör: \(customerDir.path)")
            do {
                try FileManager.default.removeItem(at: customerDir)
                print("✅ App Documents müşteri klasörü silindi: \(customerDir.path)")
                cleanupEmptyDirectories(customerDir.deletingLastPathComponent())
                fileSuccess = true
            } catch {
                print("❌ App Documents müşteri klasörü silme hatası: \(error.localizedDescription)")
                fileSuccess = false
            }
        } else {
            print("❌ Müşteri klasörü bulunamadı: '\(customerName)' → '\(safeCustomerName)'")
            fileSuccess = false
        }
        
        // 3️⃣ Sonuç değerlendirmesi
        print("📊 Silme sonucu - Database: \(dbSuccess ? "✅" : "❌"), Dosyalar: \(fileSuccess ? "✅" : "❌")")
        
        // En az birisi başarılıysa UI'ı güncelle
        return dbSuccess || fileSuccess
    }
    
    // MARK: - Get Storage Info
    static func getStorageInfo() async -> String {
        var info = "📱 Envanto Storage Info:\n"
        
        // App Documents bilgisi
        if let documentsDir = getAppDocumentsDirectory() {
            let envantoDir = documentsDir.appendingPathComponent("Envanto")
            info += "📁 Files App: \(envantoDir.path)\n"
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: envantoDir, 
                                                                           includingPropertiesForKeys: nil)
                info += "📁 Müşteri klasörleri: \(contents.count)\n"
                
                // Her müşteri için resim sayısı
                for customerDir in contents.prefix(5) {
                    if customerDir.hasDirectoryPath {
                        let customerName = customerDir.lastPathComponent
                        let imageCount = getAppDocumentsImages(customerName: customerName).count
                        info += "   • \(customerName): \(imageCount) resim\n"
                    }
                }
                
                if contents.count > 5 {
                    info += "   ... ve \(contents.count - 5) müşteri daha\n"
                }
            } catch {
                info += "📁 Files App: Henüz oluşturulmadı\n"
            }
        }
        
        return info
    }
} 