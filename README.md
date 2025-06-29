<!-- @format -->

# Envanto Barkod Android Uygulaması

![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Java](https://img.shields.io/badge/Java-ED8B00?style=for-the-badge&logo=java&logoColor=white)
![MLKit](https://img.shields.io/badge/MLKit-4285F4?style=for-the-badge&logo=google&logoColor=white)
![CameraX](https://img.shields.io/badge/CameraX-34A853?style=for-the-badge&logo=android&logoColor=white)

Envanto web platformu ile entegre çalışan kapsamlı Android barkod tarama ve yönetim uygulaması. QR kod ve Data Matrix barkodlarını taramak, müşteri resimlerini yönetmek ve araç ürün takibi yapmak için geliştirilmiştir.

## 📱 Ana Özellikler

### 🔍 Barkod Tarama Sistemi

- **Gelişmiş Barkod Tarama**: MLKit kullanarak hızlı ve hassas barkod/QR kod tanıma
- **CameraX Entegrasyonu**: Yüksek performanslı kamera işlemleri
- **Otomatik Odaklama**: Dokunarak odaklama ve sürekli otofokus
- **Fener Kontrolü**: Görsel göstergeler ile flash açma/kapama
- **Titreşim ve Ses**: Başarılı tarama sonrası geri bildirim
- **Chrome Custom Tabs**: Tarama sonuçları ile web portalına sorunsuz yönlendirme

### 📤 Barkod Yükleme ve Yönetim

- **Offline Çalışma**: SQLite veritabanı ile yerel veri saklama
- **Otomatik Senkronizasyon**: Arka plan servisi ile veri yükleme
- **Retry Mekanizması**: Başarısız yüklemeler için otomatik tekrar deneme
- **WiFi/Mobil Veri Seçimi**: Kullanıcı tercihine göre ağ kullanımı
- **Toplu İşlem**: Birden fazla barkodun toplu yüklenmesi

### 🖼️ Müşteri Resim Yönetimi

- **Resim Çekme ve Yükleme**: Müşteri lokasyonlarının görsel dokumentasyonu
- **Yerel Önbellek**: Hızlı erişim için resim önbellekleme
- **Sıkıştırma ve Optimizasyon**: Otomatik resim optimizasyonu
- **Galeri Görünümü**: Çekilen resimlerin organize görüntülenmesi

### 🚚 Araç Ürün Takibi

- **Araç Bazlı Ürün Listesi**: Araçlardaki ürünlerin takibi
- **Stok Kontrolü**: Ürün sayımı ve durum güncellemeleri
- **Filtreleme ve Arama**: Hızlı ürün bulma özellikleri
- **Otomatik Güncelleme**: Sunucu ile düzenli senkronizasyon

### ⚙️ Gelişmiş Ayarlar ve Yönetim

- **Cihaz Yetkilendirme**: Güvenli cihaz kayıt sistemi
- **Kullanıcı Oturum Yönetimi**: Otomatik login ve oturum takibi
- **Otomatik Güncelleme**: APK güncelleme kontrolü ve indirme
- **Konfigürasyon Yönetimi**: Esnek uygulama ayarları
- **Pil Optimizasyonu**: Arka plan işlemleri için pil ayarları

## 🚀 Teknoloji Stack'i

### Core Android

- **Target SDK**: Android 14 (API 34)
- **Min SDK**: Android 5.0 (API 21)
- **Java Version**: Java 17
- **Material Design**: Modern UI bileşenleri

### Kamera ve Görüntü İşleme

- **MLKit Barcode Scanning**: v17.3.0 - Gelişmiş barkod tanıma
- **CameraX**: v1.4.2 - Modern kamera API'si
- **CameraX Lifecycle**: Kamera yaşam döngüsü yönetimi
- **CameraX View**: Kamera önizleme bileşenleri

### Network ve API

- **Retrofit**: v3.0.0 - RESTful API istemcisi
- **OkHttp**: v4.12.0 - HTTP istemcisi ve interceptor'lar
- **Gson Converter**: JSON serileştirme/deserileştirme
- **Chrome Custom Tabs**: v1.8.0 - Web entegrasyonu

### Veritabanı ve Persistence

- **SQLite**: Yerel veri saklama
- **JTDS**: v1.3.1 - SQL Server bağlantısı
- **Commons DBCP2**: v2.13.0 - Veritabanı bağlantı havuzu
- **SharedPreferences**: Kullanıcı tercihleri

### UI/UX Kütüphaneleri

- **AppCompat**: v1.7.1 - Geriye uyumluluk
- **Material Components**: v1.12.0 - Material Design
- **ConstraintLayout**: v2.2.1 - Esnek layout sistemi
- **SwipeRefreshLayout**: v1.1.0 - Yenileme gestürü

## 📋 Sistem Gereksinimleri

### Minimum Gereksinimler

- **Android Sürümü**: Android 5.0 (API 21)
- **RAM**: 2 GB
- **Depolama**: 100 MB boş alan
- **Kamera**: Otomatik odaklamalı arka kamera

### Önerilen Gereksinimler

- **Android Sürümü**: Android 8.0+ (API 26+)
- **RAM**: 4 GB+
- **Depolama**: 500 MB boş alan
- **Network**: 4G/WiFi bağlantısı
- **Donanım**: Kamera flaşı, titreşim motoru

## 🛠️ Kurulum ve Geliştirme

### Geliştirme Ortamı Hazırlığı

```bash
# Gerekli araçlar
- Android Studio Hedgehog (2023.1.1) veya daha yeni
- Android SDK 34
- Java JDK 17
- Gradle 8.0+
```

### Projeyi Çalıştırma

```bash
# Repository'yi klonlayın
git clone https://github.com/your-organization/EnvantoBarkodAndroid.git
cd EnvantoBarkodAndroid

# Android Studio'da açın
# Gradle sync işlemini bekleyin
# Fiziksel cihaza deploy edin (kamera işlevselliği için)
```

### Build Konfigürasyonu

```bash
# Debug build
./gradlew assembleDebug

# Release build (keystore gerekli)
./gradlew assembleRelease
```

## 📖 Kullanım Kılavuzu

### 🎯 Ana Özellikler

#### 1. Barkod Tarama

- Ana ekrandan "Barkod Tara" butonuna tıklayın
- Kamera açıldığında barkodu çerçeve içine yerleştirin
- Otomatik tanıma sonrası web portalı açılır
- Fener butonuyla aydınlatma kontrolü

#### 2. Barkod Yükleme

- "Barkod Yükle" menüsünden geçmiş taramaları görüntüleyin
- Yüklenmemiş kayıtları seçerek toplu yükleme yapın
- Ağ durumuna göre otomatik/manuel senkronizasyon

#### 3. Müşteri Resimleri

- "Müşteri Resimleri" bölümünden fotoğraf çekin
- Müşteri lokasyonlarını belgelendirin
- Yerel galeri ile resimleri yönetin

#### 4. Araç Ürünleri

- "Araçtaki Ürünler" ile stok takibi yapın
- Ürün listelerini görüntüleyin ve güncelleyin
- Filtreleme ve arama özellikleri kullanın

#### 5. Ayarlar ve Yönetim

- Cihaz yetkilendirme işlemlerini yapın
- Kullanıcı bilgilerini yönetin
- Uygulama güncellemelerini kontrol edin

## 📁 Proje Yapısı

```
app/src/main/java/com/envanto/barcode/
├── MainActivity.java                 # Ana aktivite ve navigasyon
├── ScannerActivity.java             # Barkod tarama aktivitesi
├── BarcodeUploadActivity.java       # Barkod yükleme yönetimi
├── CustomerImagesActivity.java      # Müşteri resim yönetimi
├── VehicleProductsActivity.java     # Araç ürün takibi
├── FastCameraActivity.java          # Hızlı kamera modülü
├── SettingsActivity.java            # Ayarlar ve konfigürasyon
│
├── adapter/                         # RecyclerView adapter'ları
│   ├── CustomerImagesAdapter.java   # Müşteri resim listesi
│   ├── LocalCustomerImagesAdapter.java # Yerel resim adapter'ı
│   ├── SavedUsersAdapter.java       # Kayıtlı kullanıcı listesi
│   └── VehicleProductsAdapter.java  # Araç ürün listesi
│
├── api/                            # API istemcileri ve modelleri
│   ├── ApiClient.java              # HTTP istemci konfigürasyonu
│   ├── ApiService.java             # REST API endpoint'leri
│   ├── Customer.java               # Müşteri modeli
│   ├── LoginRequest.java           # Login istek modeli
│   ├── LoginResponse.java          # Login yanıt modeli
│   ├── VehicleProduct.java         # Araç ürün modeli
│   └── [diğer API modelleri]
│
├── database/                       # Veritabanı yönetimi
│   └── DatabaseHelper.java         # SQLite veritabanı yardımcısı
│
├── model/                          # Veri modelleri
│   └── UpdateInfo.java             # Güncelleme bilgi modeli
│
├── service/                        # Arka plan servisleri
│   ├── UpdateManager.java          # APK güncelleme yöneticisi
│   └── UploadRetryService.java     # Veri yükleme retry servisi
│
└── utils/                          # Yardımcı sınıflar
    ├── AppConstants.java           # Uygulama sabitleri
    ├── DeviceAuthManager.java      # Cihaz yetkilendirme
    ├── DeviceIdentifier.java       # Cihaz kimlik yönetimi
    ├── ImageStorageManager.java    # Resim depolama yönetimi
    ├── LoginManager.java           # Kullanıcı oturum yönetimi
    └── NetworkUtils.java           # Ağ durumu kontrolleri
```

## 🔧 Yapılandırma

### API Endpoint'leri

```java
// AppConstants.java içinde tanımlı
API_BASE_URL = "https://envanto.app/barkod_yukle_android/"
UPDATE_CHECK_URL = "https://envanto.app/barkod_yukle_android/updatecontrol.asp"
DEFAULT_BARCODE_URL_BASE = "https://envanto.app/barkodindex.asp?barcode="
```

### Timing Konfigürasyonları

```java
// build.gradle BuildConfig'de tanımlı
UPLOAD_SERVICE_INTERVAL = 30000        // 30 saniye
AUTO_REFRESH_INTERVAL = 10000          // 10 saniye
UPDATE_CHECK_INTERVAL = 43200000       // 12 saat
SESSION_DURATION = 86400000            // 24 saat
```

### Gerekli İzinler

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.FLASHLIGHT" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## 📈 Versiyon Bilgileri

- **Güncel Sürüm**: v2025.06.25.25
- **Min SDK**: API 21 (Android 5.0)
- **Target SDK**: API 34 (Android 14)
- **Build Tools**: Gradle 8.0+
- **Java**: JDK 17

### Son Güncellemeler

- ✅ CameraX entegrasyonu
- ✅ Material Design 3 uyumluluğu
- ✅ Geliştirilmiş barkod tanıma algoritması
- ✅ Otomatik güncelleme sistemi
- ✅ Offline çalışma desteği
- ✅ Gelişmiş hata yönetimi

## 🔒 Güvenlik Özellikleri

- **Cihaz Yetkilendirme**: Benzersiz cihaz kimliği ile güvenli erişim
- **Oturum Yönetimi**: Otomatik token yenileme ve güvenli oturum takibi
- **Veri Şifreleme**: Hassas verilerin şifrelenmiş depolanması
- **Network Security**: HTTPS zorunluluğu ve sertifika pinning
- **İzin Yönetimi**: Minimum gerekli izinler ilkesi

## 🤝 Katkıda Bulunma

### Geliştirme Süreci

1. Bu repository'yi fork edin
2. Feature branch oluşturun (`git checkout -b feature/yeni-ozellik`)
3. Değişikliklerinizi commit edin (`git commit -am 'Yeni özellik: açıklama'`)
4. Branch'inizi push edin (`git push origin feature/yeni-ozellik`)
5. Pull Request oluşturun

### Kod Standartları

- Java 17 syntax'ı kullanın
- Android Lint kurallarına uygun kod yazın
- JavaDoc yorumları ekleyin
- Unit test'ler yazın
- Material Design kurallarına uygun UI tasarlayın

## 📞 Destek ve İletişim

- **Resmi Web Sitesi**: [envanto.app](https://envanto.app)
- **Teknik Destek**: support@envanto.app
- **Dokümantasyon**: [GitHub Wiki](https://github.com/your-org/EnvantoBarkodAndroid/wiki)

### Issue Raporlama

Hataları raporlarken lütfen şu bilgileri ekleyin:

- Android sürümü ve cihaz modeli
- Uygulama versiyonu
- Hatayı yeniden oluşturma adımları
- Logcat çıktısı (mümkünse)

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakın.

---

⭐ **Bu projeyi beğendiyseniz GitHub'da yıldız vermeyi unutmayın!**

**Geliştirici Notları**: Bu uygulama Envanto ekosistemine özel olarak tasarlanmıştır ve aktif geliştirme sürecindedir. Önerileriniz ve katkılarınız memnuniyetle karşılanır.
