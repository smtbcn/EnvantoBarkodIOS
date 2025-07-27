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
    static func saveImage(image: UIImage, customerName: String, isGallery: Bool, yukleyen: String) async -> String? {
        
        // App Documents'a kaydet (Files uygulamasından erişilebilir)
        if let documentsPath = saveToAppDocuments(image: image, customerName: customerName, isGallery: isGallery) {
            
            // NOT: Orientation düzeltmesi artık CameraModel'da yapılıyor
            // let _ = ImageOrientationUtils.fixImageOrientation(imagePath: documentsPath)
            
            // Dosya kontrol et
            let fileExists = FileManager.default.fileExists(atPath: documentsPath)
            
            // 🗄️ Database'e kaydet 
            
            let dbManager = DatabaseManager.getInstance()
            let dbSaved = dbManager.insertBarkodResim(
                musteriAdi: customerName,
                resimYolu: documentsPath,
                yukleyen: yukleyen
            )
            
            if dbSaved {
                // Upload tetikle
                triggerUploadAfterSave()
            }
            
            return documentsPath
        }
        
        return nil
    }
    
    // MARK: - Customer Images Support (Müşteri Resimleri)
    
    static func saveMusteriResmi(_ image: UIImage, customerName: String) throws -> String {
        guard let documentsPath = saveToMusteriResimleriDocuments(image: image, customerName: customerName) else {
            throw ImageStorageError.saveFailed
        }
        
        // NOT: Orientation düzeltmesi artık CameraModel'da yapılıyor
        // let _ = ImageOrientationUtils.fixImageOrientation(imagePath: documentsPath)
        
        // Dosya kontrol et
        let fileExists = FileManager.default.fileExists(atPath: documentsPath)
        if !fileExists {
            throw ImageStorageError.fileNotFound
        }
        
        return documentsPath
    }
    
    static func deleteMusteriResmi(imagePath: String) throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: imagePath) else {
            // Dosya zaten yok, sessizce devam et
            return
        }
        
        do {
            try fileManager.removeItem(atPath: imagePath)
        } catch {
            throw ImageStorageError.deleteFailed
        }
        
        // Eğer müşteri klasörü boş kaldıyse onu da sil
        let parentDir = URL(fileURLWithPath: imagePath).deletingLastPathComponent()
        if let contents = try? fileManager.contentsOfDirectory(atPath: parentDir.path),
           contents.isEmpty {
            try? fileManager.removeItem(at: parentDir)
        }
    }
    
    private static func saveToMusteriResimleriDocuments(image: UIImage, customerName: String) -> String? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // musteriresimleri/CustomerName klasör yapısı oluştur
        let musteriResimleriDir = documentsDir.appendingPathComponent("musteriresimleri")
        let customerDir = musteriResimleriDir.appendingPathComponent(customerName)
        
        do {
            try FileManager.default.createDirectory(at: customerDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Müşteri klasörü oluşturulamadı: \(error)")
            return nil
        }
        
        // Resim dosya adı oluştur
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "IMG_\(timestamp).jpg"
        let fileURL = customerDir.appendingPathComponent(fileName)
        
        // Resmi kaydet
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        
        do {
            try imageData.write(to: fileURL)
            return fileURL.path
        } catch {
            print("Müşteri resmi kaydedilemedi: \(error)")
            return nil
        }
    }
    
    // MARK: - Upload Trigger (Android mantığı)
    private static func triggerUploadAfterSave() {
        // UserDefaults'tan WiFi ayarını oku
        let wifiOnly = UserDefaults.standard.bool(forKey: Constants.UserDefaults.wifiOnly)
        
        
        // Upload servisini başlat
        UploadService.shared.startUploadService(wifiOnly: wifiOnly)
    }
    


    
    // MARK: - Save to App Documents (Files App Access)
    private static func saveToAppDocuments(image: UIImage, customerName: String, isGallery: Bool) -> String? {
        guard let customerDir = getAppDocumentsCustomerDir(for: customerName) else {
            return nil
        }
        
        // Android'deki gibi dosya adı oluştur
        let fileName = generateFileName(customerName: customerName, isGallery: isGallery)
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
        // Hedef dosya yolu oluştur
        guard let customerDir = getAppDocumentsCustomerDir(for: customerName) else {
            return nil
        }
        
        let fileName = generateFileName(customerName: customerName, isGallery: true)
        let filePath = customerDir.appendingPathComponent(fileName)
        let finalPath = getUniqueFilePath(basePath: filePath)
        
        // YENİ: ImageOrientationUtils kullanarak kopyala ve orientation düzelt
        let success = ImageOrientationUtils.copyAndFixOrientation(
            sourceURL: sourceURL,
            destinationPath: finalPath.path
        )
        
        if success {
            // Database'e kaydet
            let dbManager = DatabaseManager.getInstance()
            let dbSaved = dbManager.insertBarkodResim(
                musteriAdi: customerName,
                resimYolu: finalPath.path,
                yukleyen: yukleyen
            )
            
            if dbSaved {
                triggerUploadAfterSave()
            }
            
            return finalPath.path
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
            } catch {
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
    
    // MARK: - Cleanup Empty Directories
    private static func cleanupEmptyDirectories(_ directory: URL) {
        let contents = try? FileManager.default.contentsOfDirectory(at: directory, 
                                                                   includingPropertiesForKeys: nil)
        
        // Klasör boşsa ve Envanto klasörü değilse sil
        if contents?.isEmpty == true && directory.lastPathComponent != "Envanto" {
            do {
                try FileManager.default.removeItem(at: directory)
                
                // Üst klasörü de kontrol et
                cleanupEmptyDirectories(directory.deletingLastPathComponent())
            } catch {
            }
        }
    }
    
    // MARK: - Delete Customer Images (App Documents)
    static func deleteCustomerImages(customerName: String) async -> Bool {
        
        // 🎯 Klasör adını aynı şekilde dönüştür (getAppDocumentsCustomerDir ile aynı mantık)
        let safeCustomerName = customerName.replacingOccurrences(of: "[^a-zA-Z0-9.-]", 
                                                                with: "_", 
                                                                options: .regularExpression)
        
        var fileSuccess = false
        var dbSuccess = false
        
        // 1️⃣ Database kayıtlarını sil
        dbSuccess = DatabaseManager.getInstance().deleteCustomerImages(musteriAdi: customerName)
        
        // 2️⃣ App Documents müşteri klasörünü sil
        if let customerDir = getAppDocumentsCustomerDir(for: customerName) {
            do {
                try FileManager.default.removeItem(at: customerDir)
                cleanupEmptyDirectories(customerDir.deletingLastPathComponent())
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
