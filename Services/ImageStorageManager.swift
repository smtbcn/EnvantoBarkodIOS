import Foundation
import UIKit
import UniformTypeIdentifiers

class ImageStorageManager {
    
    // MARK: - Constants
    private static let ENVANTO_FOLDER = "Envanto"
    private static let TAG = "ImageStorageManager"
    
    // MARK: - Get Documents Directory (User Accessible)
    private static func getDocumentsDirectory() -> URL? {
        // iOS Documents klasörü - Dosyalar uygulamasında görünür
        return FileManager.default.urls(for: .documentDirectory, 
                                       in: .userDomainMask).first
    }
    
    // MARK: - Get Envanto Storage Directory (Android: Pictures/Envanto)
    static func getStorageDir() -> URL? {
        guard let documentsDir = getDocumentsDirectory() else {
            print("❌ Documents directory alınamadı")
            return nil
        }
        
        let envantoDir = documentsDir.appendingPathComponent(ENVANTO_FOLDER)
        
        // Klasör yoksa oluştur
        if !FileManager.default.fileExists(atPath: envantoDir.path) {
            do {
                try FileManager.default.createDirectory(at: envantoDir, 
                                                      withIntermediateDirectories: true, 
                                                      attributes: nil)
                print("📁 Envanto klasörü oluşturuldu: \(getRelativePath(for: envantoDir))")
            } catch {
                print("❌ Envanto klasörü oluşturulamadı: \(error.localizedDescription)")
                return nil
            }
        }
        
        return envantoDir
    }
    
    // MARK: - Get Customer Directory (Android: Envanto/{musteri_adi})
    static func getCustomerDir(for customerName: String) -> URL? {
        guard let storageDir = getStorageDir() else { return nil }
        
        // Android'deki gibi güvenli klasör adı oluştur
        let safeCustomerName = customerName.replacingOccurrences(of: "[^a-zA-Z0-9.-]", 
                                                                with: "_", 
                                                                options: .regularExpression)
        
        let customerDir = storageDir.appendingPathComponent(safeCustomerName)
        
        // Klasör yoksa oluştur
        if !FileManager.default.fileExists(atPath: customerDir.path) {
            do {
                try FileManager.default.createDirectory(at: customerDir, 
                                                      withIntermediateDirectories: true, 
                                                      attributes: nil)
                print("📁 Müşteri klasörü oluşturuldu: \(getRelativePath(for: customerDir))")
            } catch {
                print("❌ Müşteri klasörü oluşturulamadı: \(error.localizedDescription)")
                return nil
            }
        }
        
        return customerDir
    }
    
    // MARK: - Save Image (Main Function - Android Compatible)
    static func saveImage(image: UIImage, customerName: String, isGallery: Bool) -> String? {
        guard let customerDir = getCustomerDir(for: customerName) else {
            print("❌ Müşteri klasörü alınamadı")
            return nil
        }
        
        // Android'deki gibi dosya adı oluştur
        let fileName = generateFileName(isGallery: isGallery)
        let filePath = customerDir.appendingPathComponent(fileName)
        
        // Aynı isimde dosya varsa sayı ekle (Android mantığı)
        let finalPath = getUniqueFilePath(basePath: filePath)
        
        // Resmi JPEG olarak kaydet
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Resim JPEG'e dönüştürülemedi")
            return nil
        }
        
        do {
            try imageData.write(to: finalPath)
            
            // Daha temiz dosya yolu gösterimi
            let relativePath = getRelativePath(for: finalPath)
            print("✅ Resim kaydedildi: \(relativePath)")
            return finalPath.path
        } catch {
            print("❌ Resim kaydetme hatası: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - PhotosPicker için URL'den kaydetme
    static func saveImageFromURL(sourceURL: URL, customerName: String) -> String? {
        guard let imageData = try? Data(contentsOf: sourceURL),
              let image = UIImage(data: imageData) else {
            print("❌ URL'den resim yüklenemedi: \(sourceURL)")
            return nil
        }
        
        return saveImage(image: image, customerName: customerName, isGallery: true)
    }
    
    // MARK: - Generate File Name (Android Pattern)
    private static func generateFileName(isGallery: Bool) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timeStamp = dateFormatter.string(from: Date())
        
        let prefix = isGallery ? "GALLERY" : "CAMERA"
        return "\(prefix)_\(timeStamp).jpg"
    }
    
    // MARK: - Get Unique File Path (Android Counter Logic)
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
    
    // MARK: - Delete Image
    static func deleteImage(at path: String) -> Bool {
        let fileURL = URL(fileURLWithPath: path)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ Resim silindi: \(getRelativePath(for: fileURL))")
            
            // Boş klasörleri temizle (Android mantığı)
            cleanupEmptyDirectories(fileURL.deletingLastPathComponent())
            return true
        } catch {
            print("❌ Resim silme hatası: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Delete Customer Images
    static func deleteCustomerImages(customerName: String) -> Bool {
        guard let customerDir = getCustomerDir(for: customerName) else { return false }
        
        do {
            try FileManager.default.removeItem(at: customerDir)
            print("🗑️ Müşteri klasörü silindi: \(getRelativePath(for: customerDir))")
            
            // Boş üst klasörleri temizle
            cleanupEmptyDirectories(customerDir.deletingLastPathComponent())
            return true
        } catch {
            print("❌ Müşteri klasörü silme hatası: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Cleanup Empty Directories (Android Pattern)
    private static func cleanupEmptyDirectories(_ directory: URL) {
        let contents = try? FileManager.default.contentsOfDirectory(at: directory, 
                                                                   includingPropertiesForKeys: nil)
        
        // Klasör boşsa ve Envanto klasörü değilse sil
        if contents?.isEmpty == true && directory.lastPathComponent != ENVANTO_FOLDER {
            do {
                try FileManager.default.removeItem(at: directory)
                print("🧹 Boş klasör silindi: \(getRelativePath(for: directory))")
                
                // Üst klasörü de kontrol et
                cleanupEmptyDirectories(directory.deletingLastPathComponent())
            } catch {
                print("❌ Boş klasör silme hatası: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - List Customer Images
    static func listCustomerImages(customerName: String) -> [String] {
        guard let customerDir = getCustomerDir(for: customerName) else { return [] }
        
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
            
            print("📋 \(customerName) için \(imagePaths.count) resim bulundu")
            return imagePaths
        } catch {
            print("❌ Müşteri resimleri listeleme hatası: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Get Relative Path (Clean Display)
    private static func getRelativePath(for fullPath: URL) -> String {
        guard let documentsDir = getDocumentsDirectory() else {
            return fullPath.path
        }
        
        let documentsPath = documentsDir.path
        let fullPathString = fullPath.path
        
        if fullPathString.hasPrefix(documentsPath) {
            let relativePath = String(fullPathString.dropFirst(documentsPath.count))
            return "📁 Documents\(relativePath)"
        }
        
        return fullPathString
    }
    
    // MARK: - Get Storage Info
    static func getStorageInfo() -> String {
        guard let storageDir = getStorageDir() else {
            return "❌ Storage directory bulunamadı"
        }
        
        var info = "📁 Envanto Storage Info:\n"
        info += "📂 Konum: \(getRelativePath(for: storageDir))\n"
        info += "💡 Dosyalar uygulamasından erişilebilir\n"
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: storageDir, 
                                                                       includingPropertiesForKeys: nil)
            info += "Müşteri klasörleri: \(contents.count)\n"
            
            for customerDir in contents {
                if customerDir.hasDirectoryPath {
                    let customerName = customerDir.lastPathComponent
                    let imageCount = listCustomerImages(customerName: customerName).count
                    info += "- \(customerName): \(imageCount) resim\n"
                }
            }
        } catch {
            info += "❌ İçerik listeleme hatası: \(error.localizedDescription)"
        }
        
        return info
    }
    
    // MARK: - Debug Test Function
    static func testStorageSetup() {
        print("🧪 ImageStorageManager Test Başlatıldı")
        
        guard let documentsDir = getDocumentsDirectory() else {
            print("❌ Documents directory alınamadı")
            return
        }
        
        print("📂 Documents Path: \(getRelativePath(for: documentsDir))")
        
        guard let storageDir = getStorageDir() else {
            print("❌ Storage directory oluşturulamadı")
            return
        }
        
        print("📁 Envanto Path: \(getRelativePath(for: storageDir))")
        
        // Test müşteri klasörü oluştur
        let testCustomer = "TEST_MUSTERI"
        guard let customerDir = getCustomerDir(for: testCustomer) else {
            print("❌ Test müşteri klasörü oluşturulamadı")
            return
        }
        
        print("🏢 Test Müşteri Path: \(getRelativePath(for: customerDir))")
        print("✅ Tüm klasörler başarıyla oluşturuldu!")
        print("💡 iPhone Dosyalar uygulamasından 'Bu iPhone'da' > 'Envanto Barkod' altından erişebilirsiniz")
    }
} 