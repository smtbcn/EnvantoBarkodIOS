import Foundation
import UIKit
import UniformTypeIdentifiers

class ImageStorageManager {
    
    // MARK: - Constants
    private static let TAG = "ImageStorageManager"
    private static let ENVANTO_FOLDER_NAME = "Envanto"
    
    // MARK: - Automatic Folder Management
    
    /// Otomatik olarak kullanıcının Files klasöründe Envanto klasörü oluşturur
    private static func getEnvantoFolder() -> URL? {
        // Documents dizinini al (Files uygulamasından erişilebilir)
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Documents dizini bulunamadı")
            return nil
        }
        
        let envantoFolder = documentsDir.appendingPathComponent(ENVANTO_FOLDER_NAME)
        
        // Envanto klasörü yoksa oluştur
        if !FileManager.default.fileExists(atPath: envantoFolder.path) {
            do {
                try FileManager.default.createDirectory(at: envantoFolder, withIntermediateDirectories: true, attributes: nil)
                print("📁 Envanto klasörü oluşturuldu: \(envantoFolder.path)")
            } catch {
                print("❌ Envanto klasörü oluşturulamadı: \(error)")
                return nil
            }
        } else {
            print("✅ Envanto klasörü mevcut: \(envantoFolder.path)")
        }
        
        return envantoFolder
    }
    
    /// Müşteri klasörünü oluştur ve döndür
    private static func getCustomerFolder(customerName: String) -> URL? {
        guard let envantoFolder = getEnvantoFolder() else {
            return nil
        }
        
        // Müşteri adını güvenli hale getir
        let safeCustomerName = customerName.replacingOccurrences(of: "[^a-zA-Z0-9.-]", 
                                                               with: "_", 
                                                               options: .regularExpression)
        
        let customerFolder = envantoFolder.appendingPathComponent(safeCustomerName)
        
        // Müşteri klasörü yoksa oluştur
        if !FileManager.default.fileExists(atPath: customerFolder.path) {
            do {
                try FileManager.default.createDirectory(at: customerFolder, withIntermediateDirectories: true, attributes: nil)
                print("📁 Müşteri klasörü oluşturuldu: \(customerFolder.path)")
            } catch {
                print("❌ Müşteri klasörü oluşturulamadı: \(error)")
                return nil
            }
        }
        
        return customerFolder
    }
    
    // MARK: - Save Image
    static func saveImage(image: UIImage, customerName: String, isGallery: Bool, yukleyen: String) async -> String? {
        
        guard let customerFolder = getCustomerFolder(customerName: customerName) else {
            print("❌ Müşteri klasörü oluşturulamadı")
            return nil
        }
        
        // Dosya adı oluştur
        let fileName = generateFileName(customerName: customerName, isGallery: isGallery)
        let filePath = customerFolder.appendingPathComponent(fileName)
        let finalPath = getUniqueFilePath(basePath: filePath)
        
        // Resmi kaydet
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Resim JPEG'e çevrilemedi")
            return nil
        }
        
        do {
            try imageData.write(to: finalPath)
            print("✅ Resim kaydedildi: \(finalPath.path)")
            
            // Relative path oluştur (Envanto'dan başlayarak)
            guard let envantoFolder = getEnvantoFolder() else {
                return nil
            }
            
            let relativePath = "Envanto/" + finalPath.path.replacingOccurrences(of: envantoFolder.path + "/", with: "")
            
            // Veritabanına relative path kaydet
            let dbManager = DatabaseManager.getInstance()
            let dbSaved = dbManager.insertBarkodResim(
                musteriAdi: customerName,
                resimYolu: relativePath,
                yukleyen: yukleyen
            )
            
            if dbSaved {
                print("📊 Veritabanına kaydedildi: \(relativePath)")
                
                // Upload tetikle
                triggerUploadAfterSave()
            } else {
                print("❌ Veritabanı kayıt hatası!")
            }
            
            return finalPath.path
            
        } catch {
            print("❌ Resim kaydedilemedi: \(error)")
            return nil
        }
    }
    
    // MARK: - File Operations
    
    /// Relative path'i mutlak path'e çevirir
    static func getAbsolutePath(from relativePath: String) -> String? {
        guard let envantoFolder = getEnvantoFolder() else {
            return nil
        }
        
        if relativePath.hasPrefix("Envanto/") {
            // Envanto/ prefix'ini kaldır ve tam path oluştur
            let pathWithoutPrefix = String(relativePath.dropFirst(8)) // "Envanto/" = 8 karakter
            let absolutePath = envantoFolder.appendingPathComponent(pathWithoutPrefix).path
            return absolutePath
        } else if relativePath.hasPrefix("/") {
            // Zaten mutlak path ise olduğu gibi dön (eski kayıtlar için)
            return relativePath
        }
        
        return nil
    }
    
    /// Dosya varlığını kontrol eder
    static func fileExists(relativePath: String) -> Bool {
        guard let absolutePath = getAbsolutePath(from: relativePath) else {
            return false
        }
        return FileManager.default.fileExists(atPath: absolutePath)
    }
    
    /// Dosyayı siler
    static func deleteImage(relativePath: String) -> Bool {
        guard let absolutePath = getAbsolutePath(from: relativePath) else {
            return false
        }
        
        let fileURL = URL(fileURLWithPath: absolutePath)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ Dosya silindi: \(relativePath)")
            return true
        } catch {
            print("❌ Dosya silinemedi: \(error)")
            return false
        }
    }
    
    /// Müşteri klasörünü tamamen siler
    static func deleteCustomerFolder(customerName: String) -> Bool {
        guard let envantoFolder = getEnvantoFolder() else {
            return false
        }
        
        let safeCustomerName = customerName.replacingOccurrences(of: "[^a-zA-Z0-9.-]", 
                                                               with: "_", 
                                                               options: .regularExpression)
        let customerPath = envantoFolder.appendingPathComponent(safeCustomerName)
        
        do {
            try FileManager.default.removeItem(at: customerPath)
            print("🗑️ Müşteri klasörü silindi: \(customerPath.path)")
            return true
        } catch {
            print("❌ Müşteri klasörü silinemedi: \(error)")
            return false
        }
    }
    
    /// Sistem durumunu kontrol eder (klasör varlığı vs.)
    static func isSystemReady() -> Bool {
        return getEnvantoFolder() != nil
    }
    
    // MARK: - PhotosPicker için URL'den kaydetme
    static func saveImageFromURL(sourceURL: URL, customerName: String, yukleyen: String) async -> String? {
        guard let imageData = try? Data(contentsOf: sourceURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return await saveImage(image: image, customerName: customerName, isGallery: true, yukleyen: yukleyen)
    }
    
    // MARK: - Helper Functions
    
    private static func generateFileName(customerName: String, isGallery: Bool) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timeStamp = dateFormatter.string(from: Date())
        
        let safeCustomerName = customerName.replacingOccurrences(of: "[^a-zA-Z0-9.-]", 
                                                               with: "_", 
                                                               options: .regularExpression)
        
        let prefix = isGallery ? "GALLERY" : "CAMERA"
        return "\(safeCustomerName)_\(prefix)_\(timeStamp).jpg"
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
    
    private static func triggerUploadAfterSave() {
        let wifiOnly = UserDefaults.standard.bool(forKey: Constants.UserDefaults.wifiOnly)
        UploadService.shared.startUploadService(wifiOnly: wifiOnly)
    }
} 
