<!-- @format -->

# 🚀 Sanal PC'de Xcode Optimizasyon Rehberi

## 📋 Genel Bakış

Bu rehber, sanal makinelerde Xcode kullanırken performansı maksimize etmek için tasarlanmıştır.

## ⚡ Proje Optimizasyonları (Otomatik Uygulandı)

### Build Settings Optimizasyonları

Aşağıdaki ayarlar otomatik olarak proje dosyasına eklendi:

#### Debug Konfigürasyonu:

```
SWIFT_COMPILATION_MODE = incremental        // Artımlı derleme
COMPILER_INDEX_STORE_ENABLE = NO           // Indexing kapalı
ENABLE_BITCODE = NO                        // Bitcode kapalı
SWIFT_INSTALL_OBJC_HEADER = NO            // Obj-C header yok
CLANG_ENABLE_MODULE_DEBUGGING = NO        // Module debug kapalı
SUPPORTS_MACCATALYST = NO                 // MacCatalyst desteği yok
VALIDATE_PRODUCT = NO                     // Ürün doğrulama kapalı
```

#### Release Konfigürasyonu:

```
SWIFT_COMPILATION_MODE = wholemodule      // Tam modül optimizasyonu
ENABLE_BITCODE = NO                       // Bitcode kapalı
COMPILER_INDEX_STORE_ENABLE = NO          // Indexing kapalı
SUPPORTS_MACCATALYST = NO                 // MacCatalyst desteği yok
```

## 🎛️ Xcode Kullanıcı Ayarları

### Simulator Seçimi

- **iPhone SE (3rd generation)** kullanın (minimum kaynak kullanımı)
- iPad simulatörlerinden kaçının
- Sadece tek simulator açık tutun

### Xcode Preferences Ayarları

#### Text Editing:

```
☑️ Code completion: Suggest completions while typing: OFF
☑️ Enable type-over completions: OFF
☑️ Show completions after a delay: OFF
```

#### Source Control:

```
☑️ Enable source control: OFF (geçici olarak)
☑️ Refresh local status automatically: OFF
☑️ Show source control changes: OFF
```

#### Behaviors:

```
Build starts → Hide debugger
Build succeeds → Show navigator (sadece)
Build fails → Show Issue Navigator
```

## 💻 Sistem Seviyesi Optimizasyonlar

### Sanal Makine Ayarları

```
RAM: Minimum 8GB (16GB önerilen)
CPU Cores: Minimum 4 core
Video Memory: 256MB minimum
3D Acceleration: Enabled
```

### macOS Ayarları

```
Reduce motion: ON
Reduce transparency: ON
Automatic graphics switching: OFF
```

### Terminal Komutları (Opsiyonel)

```bash
# Xcode cache temizleme
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Simulator cache temizleme
xcrun simctl erase all

# Sistem cache temizleme
sudo purge
```

## 🧹 Düzenli Bakım

### Günlük:

- Simulator'ı her kullanım sonrası kapatın
- Sadece gerekli Xcode pencerelerini açık tutun
- Project navigator'da sadece gerekli dosyaları genişletin

### Haftalık:

- DerivedData klasörünü temizleyin
- Simulator cache'ini temizleyin
- Kullanılmayan eski projelerri silin

### Aylık:

- Xcode'u güncelleyin
- macOS sistem güncellemelerini yapın

## 🔧 Troubleshooting

### Build Yavaşlığı:

1. Clean Build Folder (⌘+Shift+K)
2. DerivedData temizle
3. Xcode'u yeniden başlat

### Memory Sorunları:

1. Activity Monitor'da Xcode memory kullanımını kontrol edin
2. 4GB+ memory kullanıyorsa Xcode'u yeniden başlatın
3. Gereksiz uygulamaları kapatın

### Simulator Sorunları:

1. Hardware → Erase All Content and Settings
2. Simulator'ı tamamen kapat ve yeniden aç
3. `xcrun simctl shutdown all` komutu çalıştır

## 📊 Performans Metrikleri

### İyi Performans:

- Build süresi: < 30 saniye
- Memory kullanımı: < 4GB
- CPU kullanımı: < %80

### Kötü Performans İşaretleri:

- Build süresi: > 60 saniye
- Memory kullanımı: > 6GB
- CPU kullanımı: > %90 sürekli

## 🎯 Proje Specific Notlar

### EnvantoBarkod Projesi:

- **Toplam dosya sayısı:** 8 (optimize edildi)
- **Target minimum:** iOS 15.0
- **Ortalama build süresi:** 15-25 saniye (sanal PC'de)
- **Memory kullanımı:** 2-3GB

### Build İyileştirmeleri:

- Silinen dosya referansları temizlendi
- Gereksiz target'lar kaldırıldı
- Build phase'ler optimize edildi

## ⚠️ Önemli Notlar

1. **Info.plist:** Otomatik oluşturma aktif edildi (manuel Info.plist dosyası gerekmez)
2. **Bitcode:** Tamamen devre dışı (sanal PC için optimum)
3. **Indexing:** Kapalı (IDE performansı için)
4. **MacCatalyst:** Desteği kaldırıldı (gereksiz overhead)

## 📞 Destek

Sorun yaşarsanız:

1. Bu dosyadaki troubleshooting adımlarını uygulayın
2. Terminal'de `top` komutu ile sistem performansını kontrol edin
3. Activity Monitor'da Xcode ve Simulator'ın memory kullanımını takip edin

---

_Son güncelleme: 2024 - Sanal PC kullanıcıları için optimize edildi_
