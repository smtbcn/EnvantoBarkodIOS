import UIKit
import ImageIO
import CoreGraphics
import Foundation

class ImageOrientationUtils {
    
    private static let TAG = "ImageOrientationUtils"
    
    /// EXIF orientation bilgisini okuyup resimleri otomatik döndüren ana metod
    static func fixImageOrientation(imagePath: String) -> String {
        print("🔄 [\(TAG)] Resim orientation işleniyor: \(imagePath)")
        
        guard let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil) else {
            print("❌ [\(TAG)] Image source oluşturulamadı")
            return imagePath
        }
        
        // EXIF orientation bilgisini oku
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            print("❌ [\(TAG)] Image properties okunamadı")
            return imagePath
        }
        
        let orientation = getImageOrientation(from: properties)
        print("📐 [\(TAG)] EXIF Orientation: \(getOrientationName(orientation))")
        
        // Orientation düzeltmesi gerekli mi?
        if orientation == .up {
            print("ℹ️ [\(TAG)] Orientation zaten doğru, işlem gerekmiyor")
            return imagePath
        }
        
        // Resmi yükle ve döndür
        guard let image = UIImage(contentsOfFile: imagePath) else {
            print("❌ [\(TAG)] Resim yüklenemedi")
            return imagePath
        }
        
        let rotationAngle = getRotationAngle(from: orientation)
        print("🔄 [\(TAG)] Rotation açısı: \(rotationAngle)°")
        
        print("🔄 [\(TAG)] rotateImage metodu çağrılıyor...")
        let rotatedImage = rotateImage(image, angle: rotationAngle)
        print("🔄 [\(TAG)] rotateImage metodu tamamlandı")
        
        // Döndürülmüş resmi kaydet
        guard let imageData = rotatedImage.jpegData(compressionQuality: 0.9) else {
            print("❌ [\(TAG)] Rotated image data oluşturulamadı")
            return imagePath
        }
        
        do {
            try imageData.write(to: URL(fileURLWithPath: imagePath))
            print("✅ [\(TAG)] Orientation düzeltmesi başarıyla uygulandı")
            return imagePath
        } catch {
            print("❌ [\(TAG)] Rotated image kaydetme hatası: \(error)")
            return imagePath
        }
    }
    
    /// URI'den resmi yükler, orientation düzeltir ve belirtilen yola kaydeder
    static func copyAndFixOrientation(sourceURL: URL, destinationPath: String) -> Bool {
        print("📋 [\(TAG)] Copy ve fix orientation: \(sourceURL.path) -> \(destinationPath)")
        
        do {
            // Önce dosyayı kopyala
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: URL(fileURLWithPath: destinationPath))
            
            // Sonra orientation düzeltmesi uygula
            let _ = fixImageOrientation(imagePath: destinationPath)
            
            return true
        } catch {
            print("❌ [\(TAG)] Copy ve fix orientation hatası: \(error)")
            return false
        }
    }
    
    /// Android mantığı ile device orientation + EXIF kombinasyonu
    /// Hem barkod resimleri hem müşteri resimleri için kullanılır
    static func fixImageOrientationWithDeviceOrientation(imagePath: String, deviceOrientation: UIDeviceOrientation) -> String {
        print("🔄 [\(TAG)] Android mantığı ile orientation düzeltmesi başlıyor")
        print("📱 [\(TAG)] Device orientation: \(getDeviceOrientationName(deviceOrientation))")
        
        // 1. EXIF orientation düzeltmesi
        let exifFixedPath = fixImageOrientation(imagePath: imagePath)
        
        // 2. Android mantığı ile manuel rotation
        guard let image = UIImage(contentsOfFile: exifFixedPath) else {
            print("❌ [\(TAG)] Resim yüklenemedi: \(exifFixedPath)")
            return exifFixedPath
        }
        
        let imageSize = image.size
        print("📐 [\(TAG)] EXIF sonrası resim boyutları: \(imageSize.width)x\(imageSize.height)")
        
        // Android mantığı: Device orientation'a göre target format belirle
        let targetShouldBePortrait = shouldTargetBePortrait(deviceOrientation: deviceOrientation)
        let currentIsPortrait = imageSize.height > imageSize.width
        
        print("🎯 [\(TAG)] Target format: \(targetShouldBePortrait ? "PORTRAIT" : "LANDSCAPE")")
        print("📐 [\(TAG)] Current format: \(currentIsPortrait ? "PORTRAIT" : "LANDSCAPE")")
        
        var rotationAngle: CGFloat = 0
        
        if targetShouldBePortrait && !currentIsPortrait {
            // Target portrait ama current landscape → 90° döndür
            rotationAngle = 90
            print("🔄 [\(TAG)] Landscape → Portrait: 90° rotation")
        } else if !targetShouldBePortrait && currentIsPortrait {
            // Target landscape ama current portrait → 270° döndür  
            rotationAngle = 270
            print("🔄 [\(TAG)] Portrait → Landscape: 270° rotation")
        } else {
            print("ℹ️ [\(TAG)] Format zaten doğru, rotation gerekmiyor")
            return exifFixedPath
        }
        
        // Rotation uygula
        let rotatedImage = rotateImage(image, angle: rotationAngle)
        
        // Döndürülmüş resmi kaydet
        guard let imageData = rotatedImage.jpegData(compressionQuality: 0.9) else {
            print("❌ [\(TAG)] Rotated image data oluşturulamadı")
            return exifFixedPath
        }
        
        do {
            try imageData.write(to: URL(fileURLWithPath: exifFixedPath))
            print("✅ [\(TAG)] Android mantığı ile orientation düzeltmesi başarıyla uygulandı")
            return exifFixedPath
        } catch {
            print("❌ [\(TAG)] Rotated image kaydetme hatası: \(error)")
            return exifFixedPath
        }
    }
    
    /// Device orientation'a göre target format belirle (Android mantığı)
    private static func shouldTargetBePortrait(deviceOrientation: UIDeviceOrientation) -> Bool {
        switch deviceOrientation {
        case .portrait, .portraitUpsideDown:
            return true  // Portrait orientations → Portrait resim
        case .landscapeLeft, .landscapeRight:
            return false // Landscape orientations → Landscape resim
        default:
            return true  // Unknown → Default portrait
        }
    }
    
    /// Device orientation adını döndür (debug için)
    private static func getDeviceOrientationName(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait: return "PORTRAIT (0°)"
        case .landscapeLeft: return "LANDSCAPE_LEFT (90°)"
        case .portraitUpsideDown: return "PORTRAIT_UPSIDE_DOWN (180°)"
        case .landscapeRight: return "LANDSCAPE_RIGHT (270°)"
        default: return "UNKNOWN"
        }
    }

    /// UIImage'i belirtilen açıda döndürür
    static func rotateImage(_ image: UIImage, angle: CGFloat) -> UIImage {
        print("🔄 [\(TAG)] rotateImage çağrıldı: \(angle)° (radians: \(angle * .pi / 180.0))")
        print("📐 [\(TAG)] Orijinal boyut: \(image.size.width)x\(image.size.height)")
        
        let radians = angle * .pi / 180.0
        
        // Yeni boyutları hesapla
        let rotatedSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
            
        print("📐 [\(TAG)] Döndürülmüş boyut: \(rotatedSize.width)x\(rotatedSize.height)")
        
        // Graphics context oluştur
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return image
        }
        
        // Koordinat sistemini merkeze taşı
        context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        
        // Döndürme uygula
        context.rotate(by: radians)
        
        // Resmi çiz
        image.draw(in: CGRect(
            x: -image.size.width / 2,
            y: -image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        ))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        print("✅ [\(TAG)] Rotation tamamlandı, final boyut: \(rotatedImage.size.width)x\(rotatedImage.size.height)")
        return rotatedImage
    }
    
    /// EXIF orientation değerinden döndürme açısını hesaplar
    /// iOS CGImagePropertyOrientation mantığı ile düzeltilmiş
    private static func getRotationAngle(from orientation: CGImagePropertyOrientation) -> CGFloat {
        switch orientation {
        case .up: return 0           // Normal orientation
        case .right: return 270      // Saat yönünde 90° döndürülmüş → 270° ters döndür
        case .down: return 0         // 180° döndürülmüş ama doğru yönde → rotation yok
        case .left: return 270       // Portrait Upside Down için → 270° döndür (90° yerine)
        case .upMirrored: return 0   // Mirror durumları
        case .rightMirrored: return 270
        case .downMirrored: return 0  // Mirror + 180° ama doğru yönde
        case .leftMirrored: return 270
        @unknown default: return 0
        }
    }
    
    /// Properties'den orientation bilgisini çıkarır
    private static func getImageOrientation(from properties: [String: Any]) -> CGImagePropertyOrientation {
        if let orientationValue = properties[kCGImagePropertyOrientation as String] as? UInt32 {
            return CGImagePropertyOrientation(rawValue: orientationValue) ?? .up
        }
        return .up
    }
    
    /// Debug için orientation adını döndürür
    private static func getOrientationName(_ orientation: CGImagePropertyOrientation) -> String {
        switch orientation {
        case .up: return "UP (0°)"
        case .right: return "RIGHT (90°)"
        case .down: return "DOWN (180°)"
        case .left: return "LEFT (270°)"
        case .upMirrored: return "UP_MIRRORED (0° + Mirror)"
        case .rightMirrored: return "RIGHT_MIRRORED (90° + Mirror)"
        case .downMirrored: return "DOWN_MIRRORED (180° + Mirror)"
        case .leftMirrored: return "LEFT_MIRRORED (270° + Mirror)"
        @unknown default: return "UNKNOWN"
        }
    }
}