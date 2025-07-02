import Foundation
import UIKit

class ImageStorageManager {
    
    // MARK: - Constants
    private static let TAG = "ImageStorageManager"
    
    // MARK: - Save Image (App Documents Only)
    static func saveImage(image: UIImage, customerName: String, isGallery: Bool) async -> String? {
        // Önce Documents dizinini kontrol et
        guard let documentsDir = getAppDocumentsDirectory() else {
            print("❌ Documents dizini alınamadı")
            return nil
        }
        
        print("📁 Documents dizini: \(documentsDir.path)")
        
        // Müşteri klasörünün tam yolunu al
        guard let customerDir = getAppDocumentsCustomerDir(for: customerName) else {
            print("❌ Müşteri klasörü oluşturulamadı")
            return nil
        }
        
        print("📂 Müşteri klasörü: \(customerDir.path)")
        
        // App Documents'a kaydet
        if let documentsPath = saveToAppDocuments(image: image, customerName: customerName, isGallery: isGallery) {
            print("✅ Resim başarıyla kaydedildi: \(documentsPath)")
            
            // Dosyanın gerçekten oluştuğunu kontrol et
            if FileManager.default.fileExists(atPath: documentsPath) {
                print("✅ Dosya doğrulandı: \(documentsPath)")
                print("📂 Tam dosya yolu: \(URL(fileURLWithPath: documentsPath).path)")
                
                // Dosya boyutunu kontrol et
                if let attributes = try? FileManager.default.attributesOfItem(atPath: documentsPath),
                   let fileSize = attributes[.size] as? Int64 {
                    print("📏 Dosya boyutu: \(fileSize) bytes")
                }
            } else {
                print("❌ Dosya oluşturulamadı: \(documentsPath)")
            }
            
            return documentsPath
        }
        
        print("❌ Resim kaydedilemedi")
        return nil
    }
    
    // MARK: - Debug: Print actual Documents path
    static func printDocumentsPath() {
        if let documentsDir = getAppDocumentsDirectory() {
            print("📱 ACTUAL Documents Path: \(documentsDir.path)")
            let envantoDir = documentsDir.appendingPathComponent("Envanto")
            print("📱 ACTUAL Envanto Path: \(envantoDir.path)")
            
            // Envanto klasörü var mı kontrol et
            if FileManager.default.fileExists(atPath: envantoDir.path) {
                print("✅ Envanto klasörü mevcut")
                
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: envantoDir.path)
                    print("📁 Envanto içindeki klasörler: \(contents)")
                } catch {
                    print("❌ Envanto klasörü içeriği okunamadı: \(error)")
                }
            } else {
                print("❌ Envanto klasörü mevcut değil")
            }
        } else {
            print("❌ Documents directory alınamadı")
        }
    }
    
    // MARK: - Save to App Documents (Files App Access)
    private static func saveToAppDocuments(image: UIImage, customerName: String, isGallery: Bool) -> String? {
        // Müşteri klasörünü al veya oluştur
        guard let customerDir = getAppDocumentsCustomerDir(for: customerName) else {
            print("❌ Müşteri klasörü oluşturulamadı: \(customerName)")
            return nil
        }
        
        print("💾 Kayıt hedefi: \(customerDir.path)")
        
        // Dosya adını oluştur
        let fileName = generateFileName(customerName: customerName, isGallery: isGallery)
        let filePath = customerDir.appendingPathComponent(fileName)
        
        print("📄 Oluşturulan dosya adı: \(fileName)")
        
        // Benzersiz dosya adı oluştur
        let finalPath = getUniqueFilePath(basePath: filePath)
        print("� Nihai kayıt yolu: \(finalPath.path)")
        
        // Resmi JPEG olarak kaydet
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Resim JPEG'e dönüştürülemedi")
            return nil
        }
        
        do {
            // Klasörün var olduğundan emin ol
            try FileManager.default.createDirectory(at: customerDir, 
                                                  withIntermediateDirectories: true, 
                                                  attributes: nil)
            
            // Dosyayı kaydet
            try imageData.write(to: finalPath)
            print("✅ Resim başarıyla kaydedildi: \(finalPath.path)")
            
            // Dosya özelliklerini kontrol et
            if let attributes = try? FileManager.default.attributesOfItem(atPath: finalPath.path) {
                print("� Dosya özellikleri: \(attributes)")
            }
            
            return finalPath.path
        } catch {
            print("❌ Dosya kaydedilirken hata oluştu: \(error.localizedDescription)")
            print("📂 Hata detayı: \(error)")
            return nil
        }
    }
    
    // MARK: - PhotosPicker için URL'den kaydetme
    static func saveImageFromURL(sourceURL: URL, customerName: String) async -> String? {
        guard let imageData = try? Data(contentsOf: sourceURL),
              let image = UIImage(data: imageData) else {
            print("❌ URL'den resim yüklenemedi: \(sourceURL)")
            return nil
        }
        
        return await saveImage(image: image, customerName: customerName, isGallery: true)
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
        let paths = FileManager.default.urls(for: .documentDirectory, 
                                           in: .userDomainMask)
        let documentsDirectory = paths[0]
        print("📱 Documents Dizini: \(documentsDirectory.path)")
        return documentsDirectory
    }
    
    private static func getAppDocumentsCustomerDir(for customerName: String) -> URL? {
        guard let documentsDir = getAppDocumentsDirectory() else {
            print("❌ Documents dizini alınamadı")
            return nil
        }
        
        // Envanto klasörünü oluştur
        let envantoDir = documentsDir.appendingPathComponent("Envanto")
        
        // Müşteri adından güvenli klasör adı oluştur
        let safeCustomerName = customerName.replacingOccurrences(of: "[^a-zA-Z0-9.-]", 
                                                              with: "_", 
                                                              options: .regularExpression)
        
        let customerDir = envantoDir.appendingPathComponent(safeCustomerName)
        
        print("📂 Müşteri klasör yolu: \(customerDir.path)")
        
        // Klasör yoksa oluştur
        if !FileManager.default.fileExists(atPath: customerDir.path) {
            do {
                try FileManager.default.createDirectory(at: customerDir, 
                                                      withIntermediateDirectories: true, 
                                                      attributes: nil)
                print("✅ Müşteri klasörü oluşturuldu: \(customerDir.path)")
            } catch {
                print("❌ Müşteri klasörü oluşturulamadı: \(error.localizedDescription)")
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
        // App Documents müşteri klasörünü sil
        if let customerDir = getAppDocumentsCustomerDir(for: customerName) {
            do {
                try FileManager.default.removeItem(at: customerDir)
                print("🗑️ App Documents müşteri klasörü silindi: \(customerDir.path)")
                cleanupEmptyDirectories(customerDir.deletingLastPathComponent())
                return true
            } catch {
                print("❌ App Documents müşteri klasörü silme hatası: \(error.localizedDescription)")
                return false
            }
        }
        
        return false
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