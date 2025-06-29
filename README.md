<!-- @format -->

# Envanto Barkod Uygulaması

![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Java](https://img.shields.io/badge/Java-ED8B00?style=for-the-badge&logo=java&logoColor=white)
![MLKit](https://img.shields.io/badge/MLKit-4285F4?style=for-the-badge&logo=google&logoColor=white)

QR kod ve Data Matrix barkodlarını taramak için geliştirilmiş özelleştirilmiş Android uygulaması. Envanto web uygulama sistemi ile sorunsuz çalışacak şekilde tasarlanmıştır.

## 📱 Özellikler

- **Hızlı Barkod Tarama**: MLKit kullanarak hızlı ve verimli barkod tarama
- **Gelişmiş Kamera Entegrasyonu**: CameraX ile yüksek performanslı kamera kullanımı
- **Otomatik Odaklama**: Dokunarak odaklama özelliği
- **Fener Desteği**: Görsel göstergeler ile fener açma/kapama
- **Gerçek Zamanlı Geri Bildirim**: Yumuşak barkod algılama
- **Titreşim ve Ses**: Başarılı tarama sonrası geri bildirim
- **Otomatik Yönlendirme**: Tarama sonuçları ile Envanto web portalına otomatik yönlendirme
- **Modern UI**: Sezgisel ve kullanıcı dostu arayüz
- **Portre Mod**: Optimal tarama deneyimi için dikey mod

## 🚀 Teknolojiler

- **MLKit**: Güçlü barkod tanıma için
- **CameraX**: Gelişmiş kamera özellikleri ve cihaz uyumluluğu
- **ConstraintLayout**: Duyarlı UI tasarımı
- **Vector Drawables**: Her çözünürlükte net ikonlar
- **Retrofit**: Network işlemleri
- **Chrome Custom Tabs**: Web portalı entegrasyonu
- **Material Design**: Modern Android tasarım dili

## 📋 Sistem Gereksinimleri

- **Minimum Android Sürümü**: Android 5.0 (API 21)
- **Önerilen Android Sürümü**: Android 8.0+ (API 26+)
- **Gerekli Donanım**: Otomatik odaklamalı kamera
- **İsteğe Bağlı Donanım**: Kamera flaşı

## 🛠️ Kurulum

### Geliştirme Ortamı

- Android Studio Giraffe (2022.3.1) veya daha yeni
- Android SDK 21 veya üzeri
- Gradle 8.0+
- Java 17

### Projeyi Çalıştırma

1. Bu repoyu klonlayın:

```bash
git clone https://github.com/your-username/envanto-barcode-basic.git
cd envanto-barcode-basic
```

2. Android Studio'da projeyi açın

3. Gradle bağımlılıklarını senkronize edin

4. Fiziksel bir cihaza dağıtın ve çalıştırın (kamera işlevselliği fiziksel cihaz gerektirir)

### Release APK Oluşturma

```bash
./gradlew assembleRelease
```

İmzalı APK dosyası `app/build/outputs/apk/release/` konumunda bulunacaktır.

## 📖 Nasıl Kullanılır

1. Uygulamayı başlatın
2. QR kod veya Data Matrix barkodunu tarama çerçevesi içine yerleştirin
3. Uygulama otomatik olarak barkodu algılar ve işler
4. Başarılı algılama sonrası ses ve titreşim geri bildirimi alırsınız
5. Uygulama otomatik olarak taranan barkod verisiyle Envanto web portalını açar
6. Web portalı taranan veriyi sistem içinde işler

## 📁 Proje Yapısı

```
app/
├── src/main/java/com/envanto/barcode/
│   ├── MainActivity.java              # Ana aktivite
│   ├── ScannerActivity.java          # Barkod tarama aktivitesi
│   ├── BarcodeUploadActivity.java    # Barkod yükleme aktivitesi
│   ├── CustomerImagesActivity.java   # Müşteri resimleri aktivitesi
│   ├── api/                          # API istemcileri
│   ├── database/                     # Veritabanı yardımcıları
│   ├── service/                      # Arka plan servisleri
│   └── utils/                        # Yardımcı sınıflar
├── src/main/res/
│   ├── layout/                       # XML layout dosyaları
│   ├── drawable/                     # Drawable kaynakları
│   ├── values/                       # String, color, dimen değerleri
│   └── menu/                         # Menü dosyaları
└── build.gradle                      # Gradle yapılandırması
```

## 🔧 Yapılandırma

### İzinler

Uygulama aşağıdaki izinleri gerektirir:

- `CAMERA`: Barkod tarama için
- `VIBRATE`: Geri bildirim titreşimi için
- `FLASHLIGHT`: Fener kontrolü için
- `INTERNET`: Web portalı erişimi için
- `ACCESS_NETWORK_STATE`: Ağ durumu kontrolü için

### Özelleştirme

Uygulama ayarlarını `app/src/main/java/com/envanto/barcode/utils/AppConstants.java` dosyasından özelleştirebilirsiniz.

## 📈 Versiyon Geçmişi

- **v2025.06.17.21**: Güncel stabil sürüm
- CameraX entegrasyonu
- Geliştirilmiş barkod tanıma
- Modern UI tasarımı
- Performans iyileştirmeleri

## 🤝 Katkıda Bulunma

1. Bu repoyu fork edin
2. Özellik dalınızı oluşturun (`git checkout -b feature/yeni-ozellik`)
3. Değişikliklerinizi commit edin (`git commit -am 'Yeni özellik eklendi'`)
4. Dalınızı push edin (`git push origin feature/yeni-ozellik`)
5. Pull Request oluşturun

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakın.

## 📞 İletişim

Envanto Barkod uygulaması hakkında sorularınız için:

- **Web**: [envanto.app](https://envanto.app)
- **E-posta**: support@envanto.app

## 🛡️ Güvenlik

Güvenlik açıkları bildirmek için lütfen güvenli kanalları kullanın ve genel issue tracker'da rapor etmeyin.

---

⭐ **Bu projeyi beğendiyseniz yıldız vermeyi unutmayın!**
