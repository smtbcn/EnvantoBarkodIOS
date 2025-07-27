# iOS Dinamik Orientation Tracking - Test Rehberi

## 🧪 Test Adımları

### 1. **Kamera Açma ve Orientation Tracking**
1. Uygulamayı açın
2. Barkod Yükleme veya Müşteri Resimleri sayfasına gidin
3. Müşteri seçin ve "Hızlı Çekim" butonuna basın
4. Console'da şu log'ları kontrol edin:
   ```
   📱 [CameraModel] Device orientation güncellendi: PORTRAIT (0°)
   📷 [CameraModel] Camera orientation güncellendi: portrait
   ```

### 2. **Telefonu Yan Çevirme Testi**
1. Kamera açıkken telefonu sola çevirin (landscape left)
2. Console'da şu log'ları görmeli:
   ```
   📱 [CameraModel] Device orientation güncellendi: LANDSCAPE_LEFT (90°)
   📷 [CameraModel] Camera orientation güncellendi: landscapeRight
   ```

### 3. **Resim Çekme Testi**
1. Telefonu yan konumda tutun
2. Resim çekme butonuna basın
3. Console'da şu log sırasını görmeli:
   ```
   📷 [CameraModel] Photo capture orientation: landscapeRight (device: LANDSCAPE_LEFT (90°))
   🔄 [CameraModel] Resim orientation işleniyor: /tmp/temp_camera_xxx.jpg
   📱 [CameraModel] Current device orientation: LANDSCAPE_LEFT (90°)
   📐 [CameraModel] Orijinal resim boyutları: 1920x1080
   🔧 [CameraModel] Manuel rotation gerekiyor
   📐 [CameraModel] Resim boyutları: 1920x1080 (landscape: true)
   📱 [CameraModel] Device orientation: LANDSCAPE_LEFT (90°)
   🔄 [CameraModel] Manuel rotation uygulanıyor: 270°
   ✅ [CameraModel] Manuel rotation başarıyla uygulandı: 270°
   📐 [CameraModel] Final resim boyutları: 1080x1920
   ✅ [CameraModel] Orientation düzeltmesi tamamlandı, resim callback'e gönderiliyor
   ```

### 4. **Tüm Orientation Testleri**

#### A. Portrait (📱 Dik)
- **Beklenen**: Resim düz kaydedilir
- **Log**: `PORTRAIT (0°)` → `portrait` → Manuel rotation gerekmez

#### B. Landscape Left (📱 Sol yatık)  
- **Beklenen**: Resim düz kaydedilir
- **Log**: `LANDSCAPE_LEFT (90°)` → `landscapeRight` → 270° rotation

#### C. Landscape Right (📱 Sağ yatık)
- **Beklenen**: Resim düz kaydedilir  
- **Log**: `LANDSCAPE_RIGHT (270°)` → `landscapeLeft` → 90° rotation

#### D. Portrait Upside Down (📱 Ters)
- **Beklenen**: Resim düz kaydedilir
- **Log**: `PORTRAIT_UPSIDE_DOWN (180°)` → `portraitUpsideDown` → 180° rotation

## 🐛 Sorun Giderme

### ❌ Orientation değişmiyor
**Sorun**: Device orientation log'ları görünmüyor
**Çözüm**: 
- `UIDevice.current.beginGeneratingDeviceOrientationNotifications()` çağrıldığından emin olun
- Cihazın orientation lock'u kapalı olmalı

### ❌ Resim hala yan kaydediliyor
**Sorun**: Manuel rotation çalışmıyor
**Kontrol Listesi**:
1. `processImageOrientation` metodu çağrılıyor mu?
2. `needsManualRotation()` true dönüyor mu?
3. `applyManualRotation` metodu çalışıyor mu?
4. `ImageOrientationUtils.rotateImage` çalışıyor mu?

### ❌ EXIF orientation düzeltmesi çalışmıyor
**Sorun**: `ImageOrientationUtils.fixImageOrientation` başarısız
**Kontrol**:
- Resim dosyası mevcut mu?
- EXIF bilgisi okunabiliyor mu?
- CGImageSource oluşturuluyor mu?

## 📱 Test Senaryoları

### ✅ Barkod Resimleri
1. BarcodeUploadView → Müşteri seç → Hızlı Çekim
2. Telefonu farklı yönlerde tut ve resim çek
3. Kaydedilen resimlerin düz olduğunu kontrol et

### ✅ Müşteri Resimleri  
1. CustomerImagesView → Müşteri seç → Hızlı Çekim
2. Telefonu farklı yönlerde tut ve resim çek
3. Kaydedilen resimlerin düz olduğunu kontrol et

### ✅ Galeri Seçimi
1. PhotosPicker ile resim seç
2. Yan çekilmiş resimler düz kaydedilmeli
3. EXIF orientation bilgisi korunmalı

## 🎯 Beklenen Sonuçlar

### ✅ Başarılı Test
- Telefon hangi yönde tutulursa tutulsun resimler düz kaydedilir
- Console log'ları doğru sırada görünür
- Manuel rotation gerektiğinde uygulanır
- Final resim boyutları doğru (portrait: height > width)

### ❌ Başarısız Test  
- Resimler yan kaydediliyor
- Console log'ları eksik veya hatalı
- Manuel rotation uygulanmıyor
- Final resim boyutları yanlış

## 🚀 Performance Kontrolleri

### Memory Usage
- UIImage objelerinin doğru release edildiğini kontrol edin
- Geçici dosyaların temizlendiğini kontrol edin
- Memory leak olmadığını kontrol edin

### Processing Time
- Orientation düzeltmesi 1-2 saniyede tamamlanmalı
- Arka plan thread'de işlem yapılmalı
- UI bloklanmamalı

Bu test rehberini takip ederek orientation tracking sisteminin doğru çalıştığını doğrulayabilirsiniz.