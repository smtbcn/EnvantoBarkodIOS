# 🖥️ Windows'ta iOS Geliştirme Rehberi

## ⚠️ Önemli Not
Windows'ta direkt iOS build almak mümkün değildir çünkü Xcode sadece macOS'ta çalışır.

## 🚀 Windows'tan iOS Build Alma Yöntemleri

### 1. Codemagic (ÖNERİLEN) ✅
- ✅ Tamamen bulut tabanlı
- ✅ Windows'tan kullanılabilir
- ✅ Otomatik signing
- ✅ Direkt iPhone'a build

**Kullanım:**
1. Codemagic'te `ios-device-build` workflow'unu seçin
2. Build'i başlatın
3. IPA dosyasını indirin
4. 3uTools ile iPhone'a kurun

### 2. 3uTools ile IPA Kurulumu ✅
**3uTools İndirin:** https://www.3u.com/

**Kurulum Adımları:**
1. iPhone'unuzu Windows'a bağlayın
2. 3uTools'u açın
3. **Apps** sekmesine gidin
4. **Install** butonuna tıklayın
5. IPA dosyasını seçin
6. Kurulum otomatik başlar

### 3. iTunes ile IPA Kurulumu
1. iTunes'u açın
2. iPhone'unuzu seçin
3. **Apps** bölümüne gidin
4. IPA dosyasını sürükleyip bırakın

### 4. Digiflare (Alternatif Bulut Servisi)
- https://digiflare.com/
- Codemagic'e benzer
- Ücretli servis

### 5. MacinCloud (Uzak Mac Kiralama)
- https://www.macincloud.com/
- Saatlik Mac kiralama
- Xcode erişimi
- Daha pahalı seçenek

## 📱 iPhone Hazırlığı

### Developer Mode Açma (iOS 16+)
1. **Ayarlar** → **Gizlilik ve Güvenlik** → **Developer Mode**
2. Developer Mode'u açın
3. iPhone yeniden başlatılacak
4. Onaylayın

### Güvenilir Geliştirici Ayarı
1. IPA kurduktan sonra uygulamayı açmaya çalışın
2. "Untrusted Developer" hatası alacaksınız
3. **Ayarlar** → **Genel** → **VPN ve Cihaz Yönetimi**
4. Developer App bölümünde hesabınızı bulun
5. **Güven** butonuna tıklayın

## 🎯 Önerilen Akış

### Adım 1: Codemagic Build
1. Codemagic'te `ios-device-build` workflow'unu çalıştırın
2. Build başarılı olursa IPA dosyasını indirin

### Adım 2: 3uTools Kurulumu
1. 3uTools'u indirin ve kurun
2. iPhone'unuzu bağlayın
3. IPA dosyasını kurun

### Adım 3: iPhone Ayarları
1. Developer Mode'u açın
2. Güvenilir geliştirici ayarını yapın
3. Uygulamayı çalıştırın

## 🔧 Sorun Giderme

### "App installation failed" Hatası
- iPhone'da yeterli alan olduğundan emin olun
- Developer Mode'un açık olduğunu kontrol edin
- 3uTools'u yeniden başlatın

### "Untrusted Developer" Hatası
- Güvenilir geliştirici ayarını yapın
- Apple ID'nizin doğru olduğunu kontrol edin

### Build Hatası (Codemagic'te)
- Apple Developer hesabınızın aktif olduğunu kontrol edin
- Bundle ID'nin doğru olduğunu kontrol edin
- Team ID'nin doğru olduğunu kontrol edin

## 💡 İpuçları

1. **İlk build uzun sürebilir** - Provisioning profile oluşturma
2. **3uTools en kolay yöntem** - iTunes'tan daha stabil
3. **Developer Mode şart** - iOS 16+ için
4. **WiFi bağlantısı** - Build indirme için hızlı internet
5. **Sabırlı olun** - İlk kurulum biraz zaman alabilir

## 📞 Yardım

Sorun yaşarsanız:
1. Build loglarını kontrol edin
2. iPhone ayarlarını tekrar kontrol edin
3. 3uTools'u yeniden başlatın
4. Codemagic support'a başvurun