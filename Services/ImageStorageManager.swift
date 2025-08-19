import Foundation
import UIKit

// MARK: - Image Storage Errors
enum ImageStorageError: Error {
    case saveFailed
    case deleteFailed
    case fileNotFound
    case directoryCreationFailed
}

class ImageStorageManager {
    
    // MARK: - Constants
    private static let TAG = "ImageStorageManager"
    
    // MARK: - Save Image (App Documents Only)
    static func saveImage(image: UIImage, customerName: String, yukleyen: String) async -> String? {
        
        // PathHelper kullanarak kaydet
        if let relativePath = saveBarkodImageWithRelativePath(image: image, customerName: customerName) {
            
            // Absolute path'i al (dosya kontrol için)
            guard let absolutePath = PathHelper.getAbsolutePath(for: relativePath) else {
                return nil
            }
            
            // Dosya kontrol et
            let fileExists = FileManager.default.fileExists(atPath: absolutePath)
            
            // 🗄️ Database'e RELATIVE PATH kaydet 
            let dbManager = DatabaseManager.getInstance()
            let dbSaved = dbManager.insertBarkodResim(
                musteriAdi: customerName,
                resimYolu: relativePath, // ✅ Relative path kaydet
                yukleyen: yukleyen
            )
            
            if dbSaved {
                // Upload tetikle
                triggerUploadAfterSave()
            }
            
            return absolutePath // UI için absolute path döndür
        }
        
        return nil
    }
    
    // MARK: - Customer Images Support (Müşteri Resimleri)
    
    /// Müşteri resmi kaydetme - relative path döndürür
    private static func saveMusteriImageWithRelativePath(image: UIImage, customerName: String) -> String? {
        guard let customerDir = PathHelper.getMusteriResimleriDirectory(for: customerName) else {
            print("❌ [ImageStorageManager] Müşteri klasörü oluşturulamadı: \(customerName)")
            return nil
        }
        
        print("📁 [ImageStorageManager] Müşteri klasörü: \(customerDir.path)")
        
        // Dosya adı oluştur
        let fileName = PathHelper.generateMusteriFileName(customerName: customerName)
        let fileURL = customerDir.appendingPathComponent(fileName)
        
        print("📁 [ImageStorageManager] Dosya yolu: \(fileURL.path)")
        
        // Resmi kaydet
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ [ImageStorageManager] JPEG data oluşturulamadı")
            return nil
        }
        
        do {
            // Benzersiz dosya yolu oluştur
            let finalPath = PathHelper.getUniqueFilePath(basePath: fileURL)
            
            try imageData.write(to: finalPath)
            
            // Dosya kaydedildi mi kontrol et
            let fileExists = FileManager.default.fileExists(atPath: finalPath.path)
            print("✅ [ImageStorageManager] Dosya kaydedildi: \(fileExists) - \(finalPath.path)")
            
            // Relative path oluştur
            let finalFileName = finalPath.lastPathComponent
            let relativePath = PathHelper.getMusteriImageRelativePath(customerName: customerName, fileName: finalFileName)
            print("📁 [ImageStorageManager] Relative path: \(relativePath)")
            
            return relativePath
        } catch {
            print("❌ [ImageStorageManager] Müşteri resmi kaydedilemedi: \(error)")
            return nil
        }
    }

    static func saveMusteriResmi(_ image: UIImage, customerName: String) throws -> (absolutePath: String, relativePath: String) {
        guard let relativePath = saveMusteriImageWithRelativePath(image: image, customerName: customerName) else {
            throw ImageStorageError.saveFailed
        }
        
        // Absolute path'i al (dosya kontrol için)
        guard let absolutePath = PathHelper.getAbsolutePath(for: relativePath) else {
            throw ImageStorageError.saveFailed
        }
        
        // Dosya kontrol et
        let fileExists = FileManager.default.fileExists(atPath: absolutePath)
        if !fileExists {
            throw ImageStorageError.fileNotFound
        }
        
        return (absolutePath: absolutePath, relativePath: relativePath)
    }
    
    static func deleteMusteriResmi(imagePath: String) throws {
        let fileManager = FileManager.default
        
        // Eğer relative path ise absolute path'e çevir
        let actualPath: String
        if imagePath.hasPrefix("/") {
            actualPath = imagePath // Zaten absolute path
        } else {
            // Relative path'i absolute path'e çevir
            actualPath = PathHelper.getAbsolutePath(for: imagePath) ?? imagePath
        }
        
        guard fileManager.fileExists(atPath: actualPath) else {
            // Dosya zaten yok, sessizce devam et
            return
        }
        
        do {
            try fileManager.removeItem(atPath: actualPath)
        } catch {
            throw ImageStorageError.deleteFailed
        }
        
        // Eğer müşteri klasörü boş kaldıyse onu da sil
        let parentDir = URL(fileURLWithPath: actualPath).deletingLastPathComponent()
        if let contents = try? fileManager.contentsOfDirectory(atPath: parentDir.path),
           contents.isEmpty {
            try? fileManager.removeItem(at: parentDir)
        }
    }
    
    // MARK: - New PathHelper-based Save Functions
    
    /// Barkod resmi kaydetme - relative path döndürür
    private static func saveBarkodImageWithRelativePath(image: UIImage, customerName: String) -> String? {
        guard let customerDir = PathHelper.getBarkodCustomerDirectory(for: customerName) else {
            return nil
        }
        
        // Dosya adı oluştur
        let fileName = PathHelper.generateBarkodFileName(customerName: customerName)
        let filePath = customerDir.appendingPathComponent(fileName)
        
        // Aynı isimde dosya varsa sayı ekle
        let finalPath = PathHelper.getUniqueFilePath(basePath: filePath)
        
        // Resmi JPEG olarak kaydet
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        
        do {
            try imageData.write(to: finalPath)
            
            // Relative path döndür
            let finalFileName = finalPath.lastPathComponent
            return PathHelper.getBarkodImageRelativePath(customerName: customerName, fileName: finalFileName)
        } catch {
            print("❌ [ImageStorageManager] Barkod resmi kaydedilemedi: \(error)")
            return nil
        }
    }
    
    // MARK: - Legacy Functions (Backward Compatibility)
    
    private static func saveToMusteriResimleriDocuments(image: UIImage, customerName: String) -> String? {
        // PathHelper kullanarak kaydet ve absolute path döndür
        guard let relativePath = saveMusteriImageWithRelativePath(image: image, customerName: customerName) else {
            return nil
        }
        return PathHelper.getAbsolutePath(for: relativePath)
    }
    
    // MARK: - Upload Trigger (Android mantığı)
    private static func triggerUploadAfterSave() {
        // UserDefaults'tan WiFi ayarını oku
        let wifiOnly = UserDefaults.standard.bool(forKey: Constants.UserDefaults.wifiOnly)
        
        
        // Upload servisini başlat
        UploadService.shared.startUploadService(wifiOnly: wifiOnly)
    }
    


    
    // MARK: - Save to App Documents (Files App Access)
    private static func saveToAppDocuments(image: UIImage, customerName: String) -> String? {
        guard let customerDir = getAppDocumentsCustomerDir(for: customerName) else {
            return nil
        }
        
        // Android'deki gibi dosya adı oluştur
        let fileName = PathHelper.generateBarkodFileName(customerName: customerName)
        let filePath = customerDir.appendingPathComponent(fileName)
        
        // Aynı isimde dosya varsa sayı ekle (Android mantığı)
        let finalPath = getUniqueFilePath(basePath: filePath)
        
        // Resmi JPEG olarak kaydet
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        
        do {
            try imageData.write(to: finalPath)
            
            return finalPath.path
        } catch {
            return nil
        }
    }
    
    // MARK: - PhotosPicker için URL'den kaydetme
    static func saveImageFromURL(sourceURL: URL, customerName: String, yukleyen: String) async -> String? {
        // PathHelper kullanarak hedef dosya yolu oluştur
        guard let customerDir = PathHelper.getBarkodCustomerDirectory(for: customerName) else {
            return nil
        }
        
        let fileName = PathHelper.generateBarkodFileName(customerName: customerName)
        let filePath = customerDir.appendingPathComponent(fileName)
        let finalPath = PathHelper.getUniqueFilePath(basePath: filePath)
        
        // YENİ: ImageOrientationUtils kullanarak kopyala ve orientation düzelt
        let success = ImageOrientationUtils.copyAndFixOrientation(
            sourceURL: sourceURL,
            destinationPath: finalPath.path
        )
        
        if success {
            // Relative path oluştur
            let finalFileName = finalPath.lastPathComponent
            let relativePath = PathHelper.getBarkodImageRelativePath(customerName: customerName, fileName: finalFileName)
            
            // Database'e RELATIVE PATH kaydet
            let dbManager = DatabaseManager.getInstance()
            let dbSaved = dbManager.insertBarkodResim(
                musteriAdi: customerName,
                resimYolu: relativePath, // ✅ Relative path kaydet
                yukleyen: yukleyen
            )
            
            if dbSaved {
                triggerUploadAfterSave()
            }
            
            return finalPath.path // UI için absolute path döndür
        } else {
            // Fallback: Normal kopyalama yöntemi
            return await fallbackSaveFromURL(sourceURL: sourceURL, customerName: customerName, yukleyen: yukleyen)
        }
    }
    
    private static func fallbackSaveFromURL(sourceURL: URL, customerName: String, yukleyen: String) async -> String? {
        guard let imageData = try? Data(contentsOf: sourceURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return await saveImage(image: image, customerName: customerName, yukleyen: yukleyen)
    }
    
    // MARK: - Legacy Functions (PathHelper'a yönlendirme)
    
    private static func generateFileName(customerName: String) -> String {
        return PathHelper.generateBarkodFileName(customerName: customerName)
    }
    
    private static func getAppDocumentsDirectory() -> URL? {
        return PathHelper.getDocumentsDirectory()
    }
    
    private static func getAppDocumentsCustomerDir(for customerName: String) -> URL? {
        return PathHelper.getBarkodCustomerDirectory(for: customerName)
    }
    
    private static func getUniqueFilePath(basePath: URL) -> URL {
        return PathHelper.getUniqueFilePath(basePath: basePath)
    }
    
    // MARK: - List Customer Images (App Documents)
    static func listCustomerImages(customerName: String) async -> [String] {
        // PathHelper kullanarak müşteri klasörünü al
        guard let customerDir = PathHelper.getBarkodCustomerDirectory(for: customerName) else { 
            return [] 
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: customerDir, 
                                                                       includingPropertiesForKeys: nil)
            
            // Sadece resim dosyalarını filtrele ve absolute path döndür
            let imagePaths = fileURLs
                .filter { url in
                    let pathExtension = url.pathExtension.lowercased()
                    return ["jpg", "jpeg", "png"].contains(pathExtension)
                }
                .map { $0.path }
                .sorted()
            
            return imagePaths
        } catch {
            return []
        }
    }
    
    private static func getAppDocumentsImages(customerName: String) -> [String] {
        // Legacy fonksiyon - PathHelper'a yönlendir
        guard let customerDir = PathHelper.getBarkodCustomerDirectory(for: customerName) else { 
            return [] 
        }
        
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
            return []
        }
    }
    
    // MARK: - Delete Image (App Documents)
    static func deleteImage(at path: String) async -> Bool {
        let fileURL = URL(fileURLWithPath: path)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            
            // Boş klasörleri temizle
            cleanupEmptyDirectories(fileURL.deletingLastPathComponent())
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Cleanup Empty Directories (PathHelper'a yönlendirme)
    private static func cleanupEmptyDirectories(_ directory: URL) {
        PathHelper.cleanupEmptyDirectories(directory)
    }
    
    // MARK: - Delete Customer Images (App Documents)
    static func deleteCustomerImages(customerName: String) async -> Bool {
        var fileSuccess = false
        var dbSuccess = false
        
        // 1️⃣ Database kayıtlarını sil
        dbSuccess = DatabaseManager.getInstance().deleteCustomerImages(musteriAdi: customerName)
        
        // 2️⃣ PathHelper kullanarak müşteri klasörünü sil
        if let customerDir = PathHelper.getBarkodCustomerDirectory(for: customerName) {
            do {
                try FileManager.default.removeItem(at: customerDir)
                PathHelper.cleanupEmptyDirectories(customerDir.deletingLastPathComponent())
                fileSuccess = true
            } catch {
                fileSuccess = false
            }
        } else {
            fileSuccess = false
        }
        
        // 3️⃣ Sonuç değerlendirmesi
        
        // En az birisi başarılıysa UI'ı güncelle
        return dbSuccess || fileSuccess
    }
    
    // MARK: - Get Storage Info
    static func getStorageInfo() async -> String {
        var info = "📱 Envanto Storage Info:\n"
        
        // PathHelper kullanarak Documents dizini bilgisi
        if let documentsDir = PathHelper.getDocumentsDirectory() {
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
