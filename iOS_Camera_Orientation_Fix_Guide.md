# iOS Fast Camera Orientation Fix Implementation Guide

## 📱 Problem Statement
Fast camera ile çekilen resimlerin telefon yönüne bakılmaksızın her zaman düz görünmesi için iOS Swift implementasyonu gerekiyor. Android versiyonunda başarıyla uygulanan dinamik orientation tracking sisteminin iOS'a uyarlanması.

## 🎯 Android'de Yapılan İyileştirmeler

### 1. **ImageOrientationUtils.swift** - Yeni Utility Sınıfı Oluştur
```swift
import UIKit
import ImageIO

class ImageOrientationUtils {
    
    /// EXIF orientation bilgisini okuyup resimleri otomatik döndüren ana metod
    static func fixImageOrientation(imagePath: String) -> String {
        // EXIF orientation bilgisini oku
        // Gerekirse resmi döndür
        // EXIF orientation'ı normal olarak güncelle
        // Detaylı debug logging ekle
    }
    
    /// URI'den resmi yükler, orientation düzeltir ve belirtilen yola kaydeder
    static func copyAndFixOrientation(sourceURL: URL, destinationPath: String) -> Bool {
        // Resmi kopyala
        // Orientation düzeltmesi uygula
        // Başarı durumunu döndür
    }
    
    /// UIImage'i belirtilen açıda döndürür
    static func rotateImage(_ image: UIImage, angle: CGFloat) -> UIImage {
        // CGAffineTransform kullanarak döndürme
        // Yeni UIImage döndür
    }
    
    /// EXIF orientation değerinden döndürme açısını hesaplar
    private static func getRotationAngle(from orientation: CGImagePropertyOrientation) -> CGFloat {
        switch orientation {
        case .up: return 0
        case .right: return 90
        case .down: return 180
        case .left: return 270
        default: return 0
        }
    }
    
    /// Debug için orientation adını döndürür
    private static func getOrientationName(_ orientation: CGImagePropertyOrientation) -> String {
        // Orientation değerlerinin string karşılıkları
    }
}
```

### 2. **FastCameraViewController.swift** - Ana Kamera Sınıfı Güncellemeleri

#### A. Import'lar ve Property'ler
```swift
import AVFoundation
import UIKit

class FastCameraViewController: UIViewController {
    
    // Mevcut property'ler...
    
    // YENİ: Orientation tracking için
    private var deviceOrientation: UIDeviceOrientation = .portrait
    private var orientationObserver: NSObjectProtocol?
    
    // YENİ: AVCapturePhotoOutput için orientation ayarları
    private var photoOutput: AVCapturePhotoOutput!
}
```

#### B. ViewDidLoad Güncellemeleri
```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    // Mevcut setup kodları...
    
    // YENİ: Orientation tracking başlat
    setupOrientationTracking()
    
    // YENİ: Camera session'ı kur
    setupCameraSession()
}
```

#### C. Orientation Tracking Sistemi
```swift
private func setupOrientationTracking() {
    // Device orientation değişikliklerini dinle
    orientationObserver = NotificationCenter.default.addObserver(
        forName: UIDevice.orientationDidChangeNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.handleOrientationChange()
    }
    
    // İlk orientation değerini al
    updateDeviceOrientation()
}

private func handleOrientationChange() {
    updateDeviceOrientation()
    updateCameraOrientation()
}

private func updateDeviceOrientation() {
    deviceOrientation = UIDevice.current.orientation
    print("📱 Device orientation güncellendi: \(getOrientationName(deviceOrientation))")
}

private func updateCameraOrientation() {
    guard let connection = photoOutput.connection(with: .video) else { return }
    
    // Video orientation'ı güncelle
    if connection.isVideoOrientationSupported {
        connection.videoOrientation = getVideoOrientation(from: deviceOrientation)
        print("📷 Camera orientation güncellendi: \(connection.videoOrientation)")
    }
}

private func getVideoOrientation(from deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
    switch deviceOrientation {
    case .portrait: return .portrait
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeRight
    case .landscapeRight: return .landscapeLeft
    default: return .portrait
    }
}

private func getOrientationName(_ orientation: UIDeviceOrientation) -> String {
    switch orientation {
    case .portrait: return "PORTRAIT (0°)"
    case .landscapeLeft: return "LANDSCAPE_LEFT (90°)"
    case .portraitUpsideDown: return "PORTRAIT_UPSIDE_DOWN (180°)"
    case .landscapeRight: return "LANDSCAPE_RIGHT (270°)"
    default: return "UNKNOWN"
    }
}
```

#### D. Resim Çekme Metodunu Güncelle
```swift
@IBAction func capturePhoto(_ sender: UIButton) {
    sender.isEnabled = false
    
    // Photo settings oluştur
    let photoSettings = AVCapturePhotoSettings()
    
    // YENİ: Orientation ayarlarını ekle
    if let connection = photoOutput.connection(with: .video) {
        connection.videoOrientation = getVideoOrientation(from: deviceOrientation)
    }
    
    // Resim çek
    photoOutput.capturePhoto(with: photoSettings, delegate: self)
}
```

#### E. Photo Capture Delegate Güncellemeleri
```swift
extension FastCameraViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard error == nil else {
            print("❌ Resim çekme hatası: \(error!)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ Image data alınamadı")
            return
        }
        
        // Geçici dosya oluştur
        let tempURL = createTempImageFile()
        
        do {
            try imageData.write(to: tempURL)
            
            // YENİ: Arka planda orientation düzeltmesi yap
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.processImageOrientation(at: tempURL.path)
            }
            
        } catch {
            print("❌ Resim kaydetme hatası: \(error)")
        }
    }
    
    private func processImageOrientation(at imagePath: String) {
        print("🔄 Resim orientation işleniyor: \(imagePath)")
        print("📱 Device orientation: \(getOrientationName(deviceOrientation))")
        
        // 1. EXIF orientation düzeltmesi
        let fixedPath = ImageOrientationUtils.fixImageOrientation(imagePath: imagePath)
        
        // 2. Manuel orientation kontrolü
        if needsManualRotation() {
            print("🔧 Manuel rotation gerekiyor")
            applyManualRotation(imagePath: fixedPath)
        }
        
        // Ana thread'de sonucu döndür
        DispatchQueue.main.async { [weak self] in
            self?.handleProcessedImage(at: fixedPath)
        }
    }
    
    private func needsManualRotation() -> Bool {
        // Her durumda manuel kontrol yap (AVFoundation bazen orientation'ı doğru ayarlamıyor)
        return true
    }
    
    private func applyManualRotation(imagePath: String) {
        guard let image = UIImage(contentsOfFile: imagePath) else { return }
        
        let imageSize = image.size
        let isImageLandscape = imageSize.width > imageSize.height
        
        print("📐 Resim boyutları: \(imageSize.width)x\(imageSize.height) (landscape: \(isImageLandscape))")
        
        var shouldRotate = false
        var rotationAngle: CGFloat = 0
        
        switch deviceOrientation {
        case .portrait:
            // Cihaz portrait, resim landscape ise 90° döndür
            if isImageLandscape {
                shouldRotate = true
                rotationAngle = 90
            }
        case .landscapeLeft:
            // Cihaz landscape left, resim portrait ise 270° döndür
            if !isImageLandscape {
                shouldRotate = true
                rotationAngle = 270
            }
        case .portraitUpsideDown:
            // Cihaz upside down, resim landscape ise 270° döndür
            if isImageLandscape {
                shouldRotate = true
                rotationAngle = 270
            }
        case .landscapeRight:
            // Cihaz landscape right, resim portrait ise 90° döndür
            if !isImageLandscape {
                shouldRotate = true
                rotationAngle = 90
            }
        default:
            break
        }
        
        if shouldRotate && rotationAngle != 0 {
            print("🔄 Manuel rotation uygulanıyor: \(rotationAngle)°")
            
            let rotatedImage = ImageOrientationUtils.rotateImage(image, angle: rotationAngle)
            
            // Döndürülmüş resmi kaydet
            if let imageData = rotatedImage.jpegData(compressionQuality: 0.9) {
                do {
                    try imageData.write(to: URL(fileURLWithPath: imagePath))
                    print("✅ Manuel rotation başarıyla uygulandı: \(rotationAngle)°")
                } catch {
                    print("❌ Manuel rotation kaydetme hatası: \(error)")
                }
            }
        } else {
            print("ℹ️ Manuel rotation gerekmiyor, resim zaten doğru yönde")
        }
    }
    
    private func handleProcessedImage(at imagePath: String) {
        // Resim işleme tamamlandı, delegate'e bildir veya completion handler çağır
        let imageURL = URL(fileURLWithPath: imagePath)
        
        // Delegate pattern veya completion handler ile sonucu döndür
        delegate?.fastCamera(self, didCaptureImageAt: imageURL)
        
        // Veya NotificationCenter ile bildir
        NotificationCenter.default.post(
            name: .fastCameraDidCaptureImage,
            object: self,
            userInfo: ["imageURL": imageURL]
        )
        
        // Activity'yi kapat
        dismiss(animated: true)
    }
}
```

### 3. **ImageStorageManager.swift** - Resim Kaydetme Güncellemeleri

```swift
extension ImageStorageManager {
    
    /// Resim kaydetme metodunu orientation düzeltmesi ile güncelle
    static func saveImage(from sourceURL: URL, customerName: String, isGallery: Bool) -> String? {
        
        // Hedef dosya yolu oluştur
        let destinationPath = createDestinationPath(customerName: customerName, isGallery: isGallery)
        
        // ImageOrientationUtils kullanarak kopyala ve orientation düzelt
        let success = ImageOrientationUtils.copyAndFixOrientation(
            sourceURL: sourceURL,
            destinationPath: destinationPath
        )
        
        if success {
            return destinationPath
        } else {
            // Fallback: Normal kopyalama yöntemi
            return fallbackCopyMethod(from: sourceURL, to: destinationPath)
        }
    }
    
    private static func fallbackCopyMethod(from sourceURL: URL, to destinationPath: String) -> String? {
        do {
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: URL(fileURLWithPath: destinationPath))
            
            // Sonrasında orientation düzelt
            let _ = ImageOrientationUtils.fixImageOrientation(imagePath: destinationPath)
            
            return destinationPath
        } catch {
            print("❌ Fallback copy hatası: \(error)")
            return nil
        }
    }
}
```

### 4. **Notification Extension**

```swift
extension Notification.Name {
    static let fastCameraDidCaptureImage = Notification.Name("fastCameraDidCaptureImage")
}
```

### 5. **Protocol Definition**

```swift
protocol FastCameraDelegate: AnyObject {
    func fastCamera(_ controller: FastCameraViewController, didCaptureImageAt url: URL)
    func fastCameraDidCancel(_ controller: FastCameraViewController)
}
```

## 🔧 Kritik Implementation Noktaları

### A. **AVFoundation Setup**
- `AVCapturePhotoOutput` kullan (deprecated `AVCaptureStillImageOutput` değil)
- `videoOrientation` property'sini dinamik olarak güncelle
- Photo settings'de orientation bilgisini doğru ayarla

### B. **Device Orientation Tracking**
- `UIDevice.orientationDidChangeNotification` kullan
- `UIDeviceOrientation` ile `AVCaptureVideoOrientation` arasında mapping yap
- Orientation değişikliklerinde camera connection'ı güncelle

### C. **Image Processing Pipeline**
1. **AVFoundation Level:** Video orientation ayarla
2. **EXIF Level:** EXIF orientation bilgisini oku ve düzelt
3. **Manual Level:** Resim boyutlarına göre manuel rotation uygula

### D. **Memory Management**
- `UIImage` ve `CGImage` objelerini doğru şekilde release et
- Arka plan thread'lerinde image processing yap
- Ana thread'de UI güncellemelerini yap

### E. **Error Handling**
- Her adımda hata kontrolü yap
- Fallback mekanizmaları kur
- Detaylı logging ekle

## 📱 Test Senaryoları

1. **Portrait Mode:** Telefonu dik tutarak resim çek → Resim düz olmalı
2. **Landscape Left:** Telefonu sola yatırarak resim çek → Resim düz olmalı  
3. **Landscape Right:** Telefonu sağa yatırarak resim çek → Resim düz olmalı
4. **Upside Down:** Telefonu ters çevirerek resim çek → Resim düz olmalı

## 🐛 Debug ve Logging

```swift
// Debug logging için
print("📱 Device Orientation: \(deviceOrientation)")
print("📷 Video Orientation: \(videoOrientation)")
print("📐 Image Size: \(imageSize)")
print("🔄 Rotation Angle: \(rotationAngle)°")
print("✅ Orientation Fix Applied")
```

## 🎯 Beklenen Sonuç

Bu implementasyon sonrasında iOS uygulamanızda da Android versiyonundaki gibi:
- Telefon hangi yönde tutulursa tutulsun resimler düz kaydedilecek
- EXIF orientation bilgisi doğru şekilde işlenecek
- Manuel rotation fallback'i çalışacak
- Detaylı debug bilgileri loglanacak

## 📚 Gerekli iOS Framework'ler

```swift
import AVFoundation  // Camera functionality
import UIKit         // UI components
import ImageIO       // EXIF data processing
import CoreGraphics  // Image manipulation
```

Bu guide'ı iOS geliştiricisine vererek Android'de yaptığımız orientation fix sisteminin birebir iOS karşılığını implement edebilirsiniz.