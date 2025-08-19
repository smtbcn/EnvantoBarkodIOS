import Foundation

/// Path yönetimi için merkezi yardımcı sınıf
/// Absolute path sorununu çözmek ve tüm path işlemlerini merkezileştirmek için kullanılır
class PathHelper {
    
    // MARK: - Constants
    private static let ENVANTO_FOLDER = "Envanto"
    private static let MUSTERI_RESIMLERI_FOLDER = "musteriresimleri"
    
    // MARK: - Document Directory Path
    /// iOS'un dinamik Documents dizinini döndürür
    static func getDocumentsDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    // MARK: - Relative Path to Absolute Path Conversion
    /// Relative path'i absolute path'e çevirir
    /// - Parameter relativePath: "Envanto/MusteriAdi/resim.jpg" formatında relative path
    /// - Returns: Tam absolute path
    static func getAbsolutePath(for relativePath: String) -> String? {
        guard let documentsDir = getDocumentsDirectory() else {
            return nil
        }
        
        let fullPath = documentsDir.appendingPathComponent(relativePath)
        return fullPath.path
    }
    
    /// Absolute path'i relative path'e çevirir
    /// - Parameter absolutePath: Tam absolute path
    /// - Returns: Documents dizininden sonraki relative path
    static func getRelativePath(from absolutePath: String) -> String? {
        guard let documentsDir = getDocumentsDirectory() else {
            return nil
        }
        
        let documentsPath = documentsDir.path
        
        // Absolute path Documents dizini ile başlıyorsa relative path'e çevir
        if absolutePath.hasPrefix(documentsPath) {
            let relativePath = String(absolutePath.dropFirst(documentsPath.count))
            // Başındaki "/" karakterini kaldır
            return relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        }
        
        return nil
    }
    
    // MARK: - Barkod Resimleri (Envanto Folder)
    /// Barkod resimleri için müşteri klasörünün absolute path'ini döndürür
    /// - Parameter customerName: Müşteri adı
    /// - Returns: Müşteri klasörünün absolute path'i
    static func getBarkodCustomerDirectory(for customerName: String) -> URL? {
        guard let documentsDir = getDocumentsDirectory() else {
            return nil
        }
        
        let safeCustomerName = makeSafeFileName(customerName)
        let customerDir = documentsDir
            .appendingPathComponent(ENVANTO_FOLDER)
            .appendingPathComponent(safeCustomerName)
        
        // Klasör yoksa oluştur
        createDirectoryIfNeeded(customerDir)
        
        return customerDir
    }
    
    /// Barkod resmi için relative path oluşturur
    /// - Parameters:
    ///   - customerName: Müşteri adı
    ///   - fileName: Dosya adı
    /// - Returns: "Envanto/MusteriAdi/dosya.jpg" formatında relative path
    static func getBarkodImageRelativePath(customerName: String, fileName: String) -> String {
        let safeCustomerName = makeSafeFileName(customerName)
        return "\(ENVANTO_FOLDER)/\(safeCustomerName)/\(fileName)"
    }
    
    // MARK: - Müşteri Resimleri (musteriresimleri Folder)
    /// Müşteri resimleri için müşteri klasörünün absolute path'ini döndürür
    /// - Parameter customerName: Müşteri adı
    /// - Returns: Müşteri klasörünün absolute path'i
    static func getMusteriResimleriDirectory(for customerName: String) -> URL? {
        guard let documentsDir = getDocumentsDirectory() else {
            return nil
        }
        
        let safeCustomerName = makeSafeFileName(customerName)
        let customerDir = documentsDir
            .appendingPathComponent(MUSTERI_RESIMLERI_FOLDER)
            .appendingPathComponent(safeCustomerName)
        
        // Klasör yoksa oluştur
        createDirectoryIfNeeded(customerDir)
        
        return customerDir
    }
    
    /// Müşteri resmi için benzersiz dosya adı oluştur
    static func generateMusteriFileName(customerName: String? = nil) -> String {
        // Tarih bazlı benzersiz ön ek
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let datePrefix = dateFormatter.string(from: Date())
        
        // Müşteri adını temizle (boşluk ve özel karakterlerden arındır)
        let cleanCustomerName = customerName != nil ? makeSafeFileName(customerName!) : ""
        
        // Rastgele sayı ekle
        let randomSuffix = String(format: "%04d", Int.random(in: 1000...9999))
        
        // Dosya adını oluştur
        let fileName = "\(cleanCustomerName)_\(datePrefix)_\(randomSuffix).jpg"
        
        return fileName
    }

    /// Müşteri resmi için relative path oluştur
    static func getMusteriImageRelativePath(customerName: String, fileName: String) -> String {
        // Müşteri adını temizle
        let cleanCustomerName = makeSafeFileName(customerName)
        
        // Relative path oluştur
        return "\(MUSTERI_RESIMLERI_FOLDER)/\(cleanCustomerName)/\(fileName)"
    }
    
    // MARK: - File Name Generation
    /// Barkod resmi için dosya adı oluşturur
    /// - Parameters:
    ///   - customerName: Müşteri adı
    /// - Returns: Oluşturulan dosya adı
    static func generateBarkodFileName(customerName: String) -> String {
        // Tarih bazlı benzersiz ön ek
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let datePrefix = dateFormatter.string(from: Date())
        
        // Müşteri adını temizle (boşluk ve özel karakterlerden arındır)
        let cleanCustomerName = makeSafeFileName(customerName)
        
        // Rastgele sayı ekle
        let randomSuffix = String(format: "%04d", Int.random(in: 1000...9999))
        
        // Dosya adını oluştur
        let fileName = "\(cleanCustomerName)_\(datePrefix)_\(randomSuffix).jpg"
        
        return fileName
    }

    /// Müşteri resmi için benzersiz dosya adı oluştur
    static func generateMusteriFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        return "IMG_\(timestamp).jpg"
    }
    
    // MARK: - Utility Functions
    /// Dosya adını güvenli hale getirir (özel karakterleri temizler)
    /// - Parameter fileName: Orijinal dosya adı
    /// - Returns: Güvenli dosya adı
    static func makeSafeFileName(_ fileName: String) -> String {
        // Boşlukları alt çizgi ile değiştir, özel karakterleri temizle
        return fileName.components(separatedBy: .alphanumerics.inverted)
            .joined(separator: "_")
            .uppercased()
    }
    
    /// Klasör yoksa oluşturur
    /// - Parameter directory: Oluşturulacak klasör URL'i
    private static func createDirectoryIfNeeded(_ directory: URL) {
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                print("❌ [PathHelper] Klasör oluşturulamadı: \(directory.path) - \(error)")
            }
        }
    }
    
    /// Benzersiz dosya yolu oluşturur (aynı isimde dosya varsa sayı ekler)
    /// - Parameter basePath: Temel dosya yolu
    /// - Returns: Benzersiz dosya yolu
    static func getUniqueFilePath(basePath: URL) -> URL {
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
    
    /// Dosyanın var olup olmadığını kontrol eder
    /// - Parameter relativePath: Kontrol edilecek relative path
    /// - Returns: Dosya var mı?
    static func fileExists(relativePath: String) -> Bool {
        guard let absolutePath = getAbsolutePath(for: relativePath) else {
            return false
        }
        return FileManager.default.fileExists(atPath: absolutePath)
    }
    
    /// Boş klasörleri temizler
    /// - Parameter directory: Temizlenecek klasör
    static func cleanupEmptyDirectories(_ directory: URL) {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        
        // Klasör boşsa ve ana klasörler değilse sil
        if contents?.isEmpty == true && 
           directory.lastPathComponent != ENVANTO_FOLDER &&
           directory.lastPathComponent != MUSTERI_RESIMLERI_FOLDER {
            do {
                try FileManager.default.removeItem(at: directory)
                // Üst klasörü de kontrol et
                cleanupEmptyDirectories(directory.deletingLastPathComponent())
            } catch {
                print("❌ [PathHelper] Boş klasör silinemedi: \(directory.path) - \(error)")
            }
        }
    }
}