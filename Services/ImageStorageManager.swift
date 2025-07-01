import Foundation
import UIKit
import Photos
import PhotosUI

class ImageStorageManager {
    
    // MARK: - Constants
    private static let ENVANTO_ALBUM_NAME = "Envanto"
    private static let TAG = "ImageStorageManager"
    
    // MARK: - Photos Library Authorization
    static func requestPhotosPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            print("❌ Fotoğraf izni reddedildi")
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Get or Create Envanto Album
    static func getEnvantoAlbum() async -> PHAssetCollection? {
        // Önce mevcut Envanto albumünü ara
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", ENVANTO_ALBUM_NAME)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, 
                                                                 subtype: .any, 
                                                                 options: fetchOptions)
        
        if let existingAlbum = collections.firstObject {
            print("📁 Mevcut Envanto albümü bulundu")
            return existingAlbum
        }
        
        // Albüm yoksa oluştur
        return await createEnvantoAlbum()
    }
    
    private static func createEnvantoAlbum() async -> PHAssetCollection? {
        do {
            var albumPlaceholder: PHObjectPlaceholder?
            
            try await PHPhotoLibrary.shared().performChanges {
                let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: ENVANTO_ALBUM_NAME)
                albumPlaceholder = createRequest.placeholderForCreatedAssetCollection
            }
            
            if let placeholder = albumPlaceholder {
                let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                print("📁 Envanto albümü oluşturuldu")
                return fetchResult.firstObject
            }
        } catch {
            print("❌ Envanto albümü oluşturma hatası: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Save Image to Photos Library (Android MediaStore Pattern)
    static func saveImage(image: UIImage, customerName: String, isGallery: Bool) async -> String? {
        // Photos izni kontrol et
        guard await requestPhotosPermission() else {
            print("❌ Fotoğraf izni gerekli")
            return fallbackToDocuments(image: image, customerName: customerName, isGallery: isGallery)
        }
        
        // Envanto albümünü al/oluştur
        guard let envantoAlbum = await getEnvantoAlbum() else {
            print("❌ Envanto albümü oluşturulamadı, Documents'a kaydediliyor")
            return fallbackToDocuments(image: image, customerName: customerName, isGallery: isGallery)
        }
        
        // Android'deki gibi dosya adı oluştur
        let fileName = generateFileName(customerName: customerName, isGallery: isGallery)
        
        do {
            var assetPlaceholder: PHObjectPlaceholder?
            
            try await PHPhotoLibrary.shared().performChanges {
                // Resmi Photos Library'ye ekle
                let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                assetPlaceholder = creationRequest.placeholderForCreatedAsset
                
                // Envanto albümüne ekle
                if let albumChangeRequest = PHAssetCollectionChangeRequest(for: envantoAlbum),
                   let placeholder = creationRequest.placeholderForCreatedAsset {
                    albumChangeRequest.addAssets([placeholder] as NSArray)
                }
            }
            
            if let placeholder = assetPlaceholder {
                let localId = placeholder.localIdentifier
                print("✅ Resim Photos Library'ye kaydedildi: \(fileName)")
                return "photos://\(localId)" // Custom URI scheme for Photos Library
            }
            
        } catch {
            print("❌ Photos Library kaydetme hatası: \(error.localizedDescription)")
            return fallbackToDocuments(image: image, customerName: customerName, isGallery: isGallery)
        }
        
        return nil
    }
    
    // MARK: - Fallback to Documents (iOS 14 altı veya izin yoksa)
    private static func fallbackToDocuments(image: UIImage, customerName: String, isGallery: Bool) -> String? {
        guard let customerDir = getDocumentsCustomerDir(for: customerName) else {
            print("❌ Documents müşteri klasörü alınamadı")
            return nil
        }
        
        // Android'deki gibi dosya adı oluştur
        let fileName = generateFileName(customerName: customerName, isGallery: isGallery)
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
            print("✅ Resim Documents'a kaydedildi: \(finalPath.path)")
            return finalPath.path
        } catch {
            print("❌ Documents kaydetme hatası: \(error.localizedDescription)")
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
    
    // MARK: - Documents Directory Fallback Functions
    private static func getDocumentsDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, 
                                       in: .userDomainMask).first
    }
    
    private static func getDocumentsCustomerDir(for customerName: String) -> URL? {
        guard let documentsDir = getDocumentsDirectory() else {
            print("❌ Documents directory alınamadı")
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
                print("📁 Documents müşteri klasörü oluşturuldu: \(customerDir.path)")
            } catch {
                print("❌ Documents müşteri klasörü oluşturulamadı: \(error.localizedDescription)")
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
    
    // MARK: - List Customer Images (Photos + Documents)
    static func listCustomerImages(customerName: String) async -> [String] {
        var imagePaths: [String] = []
        
        // 1. Photos Library'den ara
        if let photosImages = await getPhotosLibraryImages(customerName: customerName) {
            imagePaths.append(contentsOf: photosImages)
        }
        
        // 2. Documents'tan ara (fallback)
        let documentsImages = getDocumentsImages(customerName: customerName)
        imagePaths.append(contentsOf: documentsImages)
        
        print("📋 \(customerName) için toplam \(imagePaths.count) resim bulundu")
        return imagePaths.sorted()
    }
    
    private static func getPhotosLibraryImages(customerName: String) async -> [String]? {
        guard await requestPhotosPermission(),
              let envantoAlbum = await getEnvantoAlbum() else {
            return nil
        }
        
        let assets = PHAsset.fetchAssets(in: envantoAlbum, options: nil)
        var imagePaths: [String] = []
        
        assets.enumerateObjects { asset, _, _ in
            // Müşteri adı ile eşleşen resimleri filtrele (dosya adından)
            let localId = asset.localIdentifier
            imagePaths.append("photos://\(localId)")
        }
        
        return imagePaths
    }
    
    private static func getDocumentsImages(customerName: String) -> [String] {
        guard let customerDir = getDocumentsCustomerDir(for: customerName) else { return [] }
        
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
            print("❌ Documents müşteri resimleri listeleme hatası: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Delete Image
    static func deleteImage(at path: String) async -> Bool {
        if path.hasPrefix("photos://") {
            // Photos Library'den sil
            return await deleteFromPhotosLibrary(path: path)
        } else {
            // Documents'tan sil
            return deleteFromDocuments(path: path)
        }
    }
    
    private static func deleteFromPhotosLibrary(path: String) async -> Bool {
        let localId = String(path.dropFirst(9)) // "photos://" prefix'ini kaldır
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
        guard let asset = fetchResult.firstObject else {
            print("❌ Photos Library'de resim bulunamadı")
            return false
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }
            print("🗑️ Photos Library'den resim silindi")
            return true
        } catch {
            print("❌ Photos Library silme hatası: \(error.localizedDescription)")
            return false
        }
    }
    
    private static func deleteFromDocuments(path: String) -> Bool {
        let fileURL = URL(fileURLWithPath: path)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ Documents'tan resim silindi: \(path)")
            
            // Boş klasörleri temizle
            cleanupEmptyDirectories(fileURL.deletingLastPathComponent())
            return true
        } catch {
            print("❌ Documents silme hatası: \(error.localizedDescription)")
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
    
    // MARK: - Delete Customer Images
    static func deleteCustomerImages(customerName: String) async -> Bool {
        var success = true
        
        // 1. Photos Library'den sil
        if let photosImages = await getPhotosLibraryImages(customerName: customerName) {
            for imagePath in photosImages {
                let result = await deleteFromPhotosLibrary(path: imagePath)
                success = success && result
            }
        }
        
        // 2. Documents'tan sil
        if let customerDir = getDocumentsCustomerDir(for: customerName) {
            do {
                try FileManager.default.removeItem(at: customerDir)
                print("🗑️ Documents müşteri klasörü silindi: \(customerDir.path)")
                cleanupEmptyDirectories(customerDir.deletingLastPathComponent())
            } catch {
                print("❌ Documents müşteri klasörü silme hatası: \(error.localizedDescription)")
                success = false
            }
        }
        
        return success
    }
    
    // MARK: - Get Storage Info
    static func getStorageInfo() async -> String {
        var info = "📱 Envanto Storage Info:\n"
        
        // Photos Library bilgisi
        if await requestPhotosPermission(),
           let envantoAlbum = await getEnvantoAlbum() {
            let assets = PHAsset.fetchAssets(in: envantoAlbum, options: nil)
            info += "📸 Photos Library: \(assets.count) resim\n"
        } else {
            info += "📸 Photos Library: İzin yok\n"
        }
        
        // Documents bilgisi
        if let documentsDir = getDocumentsDirectory() {
            let envantoDir = documentsDir.appendingPathComponent("Envanto")
            info += "📁 Documents: \(envantoDir.path)\n"
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: envantoDir, 
                                                                           includingPropertiesForKeys: nil)
                info += "📁 Müşteri klasörleri: \(contents.count)\n"
            } catch {
                info += "📁 Documents: Henüz oluşturulmadı\n"
            }
        }
        
        return info
    }
} 