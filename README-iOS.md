<!-- @format -->

# Envanto Barkod iOS Uygulaması

Bu uygulama, Android versiyonundan iOS'a dönüştürülen bir barkod tarayıcı uygulamasıdır.

## 📱 Özellikler

- **Barkod Tarama**: QR kod, Data Matrix ve diğer barkod formatlarını destekler
- **Flash Desteği**: Karanlık ortamlarda flash kullanımı
- **Otomatik Odaklama**: Gelişmiş odaklama sistemi
- **Web Yönlendirme**: Taranan barkodları web sitesine yönlendirir
- **Ses ve Titreşim**: Başarılı taramalarda geri bildirim
- **Ayarlar**: Base URL ve cihaz sahibi ayarları

## 🔧 Gereksinimler

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+
- Kamera izni

## 🚀 Kurulum

1. Projeyi Xcode'da açın
2. Gerekli izinleri Info.plist'te kontrol edin
3. Bundle Identifier'ı ayarlayın (com.envanto.barcode.ios)
4. Development Team'i seçin
5. Uygulamayı derleyin ve çalıştırın

## 🏗️ Mimari

### SwiftUI + MVVM

- **Views**: Kullanıcı arayüzü bileşenleri
- **ViewModels**: İş mantığı ve veri yönetimi
- **Models**: Veri modelleri
- **Services**: Ağ ve kamera servisleri
- **Utilities**: Yardımcı fonksiyonlar ve uzantılar

### Ana Bileşenler

1. **MainMenuView**: Ana menü ekranı
2. **ScannerView**: Barkod tarama ekranı
3. **SettingsView**: Ayarlar ekranı
4. **ScannerViewModel**: Kamera ve barkod tarama mantığı
5. **MainViewModel**: Ana uygulama mantığı

## 🔄 Android'den iOS'a Dönüştürüm

### Android (Java) → iOS (Swift) Karşılıkları

| Android           | iOS                       |
| ----------------- | ------------------------- |
| CameraX           | AVFoundation              |
| ML Kit            | Vision Framework          |
| SharedPreferences | UserDefaults              |
| MediaPlayer       | AudioToolbox              |
| Vibrator          | UIImpactFeedbackGenerator |
| CustomTabsIntent  | SFSafariViewController    |
| Toast             | Alert/Banner              |

### Önemli Farklılıklar

1. **İzin Yönetimi**: iOS'ta compile-time izin tanımlaması gerekli
2. **Kamera Erişimi**: AVCaptureSession kullanımı
3. **Barkod Tarama**: Vision Framework ile VNDetectBarcodesRequest
4. **UI/UX**: SwiftUI ile deklaratif tasarım

## 📂 Dosya Yapısı

```
EnvantoBarkodIOS/
├── Android/                            # Orijinal Android uygulaması
├── EnvantoBarkodApp.swift              # Ana uygulama giriş noktası
├── ContentView.swift                   # Ana içerik görünümü
├── Views/
│   ├── MainMenuView.swift              # Ana menü
│   ├── ScannerView.swift               # Barkod tarayıcı
│   └── SettingsView.swift              # Ayarlar
├── ViewModels/
│   ├── MainViewModel.swift             # Ana ViewModel
│   └── ScannerViewModel.swift          # Tarayıcı ViewModel
├── Models/
│   └── BarcodeResult.swift             # Barkod sonuç modeli
├── Services/
│   ├── CameraService.swift             # Kamera servisi
│   └── BarcodeService.swift            # Barkod tarama servisi
├── Utilities/
│   ├── Constants.swift                 # Sabitler
│   └── Extensions.swift                # Uzantılar
├── Info.plist                          # Uygulama yapılandırması
└── README-iOS.md                       # Bu dosya
```

## 🎯 Temel İşlevsellik

### Barkod Tarama Süreci

1. **Kamera Başlatma**: AVCaptureSession ile kamera başlatılır
2. **Video Analizi**: Her frame Vision Framework ile analiz edilir
3. **Barkod Algılama**: VNDetectBarcodesRequest ile barkod aranır
4. **Sonuç İşleme**: Bulunan barkod işlenip kullanıcıya sunulur
5. **Web Yönlendirme**: Base URL + barkod içeriği ile web sayfası açılır

### Desteklenen Barkod Formatları

- QR Code
- Data Matrix
- EAN-13
- EAN-8
- Code 128
- Code 39
- PDF417
- Aztec

## ⚙️ Yapılandırma

### Base URL Ayarı

```swift
// Constants.swift dosyasında
struct Network {
    static let defaultBaseURL = "https://envanto.com.tr/barkod"
}

// Ayarlar üzerinden de değiştirilebilir
UserDefaults.standard.set("your-url", forKey: Constants.UserDefaults.baseURL)
```

### Kamera İzinleri

Info.plist dosyasında tanımlı:

```xml
<key>NSCameraUsageDescription</key>
<string>Bu uygulama barkod taramak için kamera kullanır.</string>
```

## 🔮 Gelecek Özellikler

- [ ] Barkod Yükleme
- [ ] Müşteri Resimleri
- [ ] Araçtaki Ürünler
- [ ] İstatistikler
- [ ] Çevrimdışı mod
- [ ] Toplu tarama
- [ ] Dark mode desteği
- [ ] Bildirim sistemi

## 🧪 Test Etme

### Simulator'da Test

1. Xcode'da iOS Simulator'ı seçin
2. Kamera simülasyonu için simulatör menüsünden Device > Photos seçin
3. Test barkod görsellerini ekleyin

### Gerçek Cihazda Test

1. iOS cihazınızı bağlayın
2. Development certificate'ınızı ayarlayın
3. Uygulamayı cihaza yükleyin
4. Gerçek barkodlarla test edin

## 🐛 Hata Ayıklama

### Yaygın Sorunlar

1. **Kamera İzni Verilmedi**: Settings > Privacy > Camera'dan izin verin
2. **Barkod Taranmıyor**: Işıklama ve odaklama kontrol edin
3. **Build Hatası**: Bundle ID ve certificate ayarlarını kontrol edin

### Log Takibi

Xcode Console'da aşağıdaki logları takip edin:

- Kamera başlatma durumu
- Barkod algılama sonuçları
- Network bağlantı durumu

## 🤝 Katkıda Bulunma

1. Fork edin
2. Feature branch oluşturun (`git checkout -b feature/AmazingFeature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add some AmazingFeature'`)
4. Branch'inizi push edin (`git push origin feature/AmazingFeature`)
5. Pull request gönderin

## 📄 Lisans

Bu proje Envanto şirketi için geliştirilmiştir. Tüm hakları saklıdır.

## 📞 İletişim

Proje ile ilgili sorularınız için:

- Email: info@envanto.com.tr
- Web: https://envanto.com.tr

---

**Not**: Bu iOS uygulaması, mevcut Android uygulamasının işlevselliklerini iOS platformuna taşımak amacıyla geliştirilmiştir.
