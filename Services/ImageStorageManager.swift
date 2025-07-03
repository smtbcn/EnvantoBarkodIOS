import Foundation
import UIKit
import UniformTypeIdentifiers

class ImageStorageManager {
    
    // MARK: - Constants
    private static let TAG = "ImageStorageManager"
    private static let USER_SELECTED_FOLDER_KEY = "userSelectedFolder"
    
    // MARK: - User Selected Folder Management (Firefox benzeri)
    
    /// Kullanıcının seçtiği klasör URL'ini kaydet
    static func saveUserSelectedFolder(_ url: URL) {
        // Security-scoped resource olarak kaydet
        let bookmarkData = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmarkData, forKey: USER_SELECTED_FOLDER_KEY)
        print("📁 Kullanıcı klasörü kaydedildi: \(url.path)")
    }
    
    /// Kullanıcının seçtiği klasör URL'ini getir
    static func getUserSelectedFolder() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: USER_SELECTED_FOLDER_KEY) else {
            print("❌ Kaydedilmiş klasör bulunamadı")
            return nil
        }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("⚠️ Klasör bookmark'u eski, yeniden seçim gerekli")
                return nil
            }
            
            // Security-scoped resource'a erişim başlat
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Klasör erişim izni alınamadı")
                return nil
            }
            
            print("✅ Kullanıcı klasörü bulundu: \(url.path)")
            return url
        } catch {
            print("❌ Klasör bookmark çözümlenemedi: \(error)")
            return nil
        }
    }
    
    /// Kullanıcının klasör seçip seçmediğini kontrol et
    static func isUserFolderSelected() -> Bool {
        return getUserSelectedFolder() != nil
    }
    
    // MARK: - Save Image (User Selected Folder)
    static func saveImage(image: UIImage, customerName: String, isGallery: Bool, yukleyen: String) async -> String? {
        
        guard let userFolder = getUserSelectedFolder() else {
            print("❌ Kullanıcı klasörü seçmemiş!")
            return nil
        }
        
        // Envanto ana klasörü oluştur
        let envantoFolder = userFolder.appendingPathComponent("Envanto")
        
        do {
            if !FileManager.default.fileExists(atPath: envantoFolder.path) {
                try FileManager.default.createDirectory(at: envantoFolder, withIntermediateDirectories: true, attributes: nil)
                print("📁 Envanto klasörü oluşturuldu: \(envantoFolder.path)")
            }
        } catch {
            print("❌ Envanto klasörü oluşturulamadı: \(error)")
            userFolder.stopAccessingSecurityScopedResource()
            return nil
        }
        
        // Müşteri klasörü oluştur
        let safeCustomerName = customerName.replacingOccurrences(of: "[^a-zA-Z0-9.-]", 
                                                               with: "_", 
                                                               options: .regularExpression)
        let customerFolder = envantoFolder.appendingPathComponent(safeCustomerName)
        
        do {
            if !FileManager.default.fileExists(atPath: customerFolder.path) {
                try FileManager.default.createDirectory(at: customerFolder, withIntermediateDirectories: true, attributes: nil)
                print("📁 Müşteri klasörü oluşturuldu: \(customerFolder.path)")
            }
        } catch {
            print("❌ Müşteri klasörü oluşturulamadı: \(error)")
            userFolder.stopAccessingSecurityScopedResource()
            return nil
        }
        
        // Dosya adı oluştur
        let fileName = generateFileName(customerName: customerName, isGallery: isGallery)
        let filePath = customerFolder.appendingPathComponent(fileName)
        let finalPath = getUniqueFilePath(basePath: filePath)
        
        // Resmi kaydet
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Resim JPEG'e çevrilemedi")
            userFolder.stopAccessingSecurityScopedResource()
            return nil
        }
        
        do {
            try imageData.write(to: finalPath)
            print("✅ Resim kaydedildi: \(finalPath.path)")
            
            // Relative path oluştur (Envanto'dan başlayarak)
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
            
            userFolder.stopAccessingSecurityScopedResource()
            return finalPath.path
            
        } catch {
            print("❌ Resim kaydedilemedi: \(error)")
            userFolder.stopAccessingSecurityScopedResource()
            return nil
        }
    }
    
    // MARK: - File Operations
    
    /// Relative path'i mutlak path'e çevirir
    static func getAbsolutePath(from relativePath: String) -> String? {
        guard let userFolder = getUserSelectedFolder() else {
            return nil
        }
        
        let absolutePath = userFolder.appendingPathComponent(relativePath).path
        userFolder.stopAccessingSecurityScopedResource()
        return absolutePath
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
        guard let userFolder = getUserSelectedFolder() else {
            return false
        }
        
        let absolutePath = userFolder.appendingPathComponent(relativePath)
        
        do {
            try FileManager.default.removeItem(at: absolutePath)
            print("🗑️ Dosya silindi: \(relativePath)")
            userFolder.stopAccessingSecurityScopedResource()
            return true
        } catch {
            print("❌ Dosya silinemedi: \(error)")
            userFolder.stopAccessingSecurityScopedResource()
            return false
        }
    }
    
    /// Müşteri klasörünü tamamen siler
    static func deleteCustomerFolder(customerName: String) -> Bool {
        guard let userFolder = getUserSelectedFolder() else {
            return false
        }
        
        let safeCustomerName = customerName.replacingOccurrences(of: "[^a-zA-Z0-9.-]", 
                                                               with: "_", 
                                                               options: .regularExpression)
        let customerPath = userFolder.appendingPathComponent("Envanto").appendingPathComponent(safeCustomerName)
        
        do {
            try FileManager.default.removeItem(at: customerPath)
            print("🗑️ Müşteri klasörü silindi: \(customerPath.path)")
            userFolder.stopAccessingSecurityScopedResource()
            return true
        } catch {
            print("❌ Müşteri klasörü silinemedi: \(error)")
            userFolder.stopAccessingSecurityScopedResource()
            return false
        }
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
