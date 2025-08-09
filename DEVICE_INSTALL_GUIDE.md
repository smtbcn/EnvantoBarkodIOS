# 📱 iPhone'a Kurulum Rehberi

## Ön Gereksinimler

### 1. Apple Developer Hesabı
- ✅ Apple Developer hesabınız olmalı (ücretsiz de olabilir)
- ✅ Xcode'da hesabınızla giriş yapmış olmalısınız

### 2. iPhone Ayarları
- ✅ iPhone'unuz bilgisayara bağlı olmalı
- ✅ "Bu bilgisayara güven" demiş olmalısınız
- ✅ Developer Mode açık olmalı (iOS 16+)

## Adım 1: UDID Alma

### Windows'ta:
1. **3uTools** indirin (önerilir): https://www.3u.com/
2. iPhone'unuzu bağlayın
3. UDID otomatik görünür, kopyalayın

### iTunes ile:
1. iTunes'u açın
2. iPhone'unuzu seçin
3. "Seri Numarası"na tıklayın
4. UDID görünecek, kopyalayın

## Adım 2: Apple Developer Portal

1. https://developer.apple.com → Account
2. **Certificates, Identifiers & Profiles**
3. **Devices** → **+**
4. Device Name: "iPhone - Samet"
5. Device ID: UDID'yi yapıştırın
6. **Continue** → **Register**

## Adım 3: Build Alma

### PowerShell ile (Windows):
```powershell
# PowerShell'i yönetici olarak açın
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\build_for_device.ps1
```

### Bash ile (Mac/Linux):
```bash
chmod +x build_for_device.sh
./build_for_device.sh
```

## Adım 4: iPhone'a Kurulum

### Xcode ile:
1. Xcode'u açın
2. **Window** → **Devices and Simulators**
3. Sol panelden iPhone'unuzu seçin
4. **Installed Apps** bölümünde **+** butonuna tıklayın
5. `build/EnvantoBarkod.ipa` dosyasını seçin
6. **Open** → Kurulum başlar

### 3uTools ile (Alternatif):
1. 3uTools'u açın
2. **Apps** sekmesine gidin
3. **Install** butonuna tıklayın
4. IPA dosyasını seçin

## Adım 5: Güvenilir Geliştirici Ayarı

iPhone'da:
1. **Ayarlar** → **Genel** → **VPN ve Cihaz Yönetimi**
2. **Geliştirici Uygulaması** bölümünde hesabınızı bulun
3. **Güven** butonuna tıklayın
4. **Güven** onaylayın

## Adım 6: Developer Mode (iOS 16+)

iPhone'da:
1. **Ayarlar** → **Gizlilik ve Güvenlik** → **Developer Mode**
2. Developer Mode'u **açın**
3. iPhone yeniden başlatılacak
4. Açıldıktan sonra Developer Mode'u onaylayın

## 🎉 Tamamlandı!

Artık uygulamanız iPhone'unuzda çalışıyor olmalı!

## ❗ Sorun Giderme

### "Untrusted Developer" Hatası
- Adım 5'i tekrar yapın

### "Developer Mode Required" Hatası  
- Adım 6'yı tekrar yapın

### Build Hatası
- Xcode'da hesabınızla giriş yaptığınızdan emin olun
- Team ID'nin doğru olduğunu kontrol edin

### Provisioning Profile Hatası
- Apple Developer Portal'da cihazınızın ekli olduğunu kontrol edin
- Xcode'da **Preferences** → **Accounts** → **Download Manual Profiles**

## 📞 Yardım

Sorun yaşarsanız:
1. Build loglarını kontrol edin
2. Xcode'da **Product** → **Clean Build Folder**
3. Script'i tekrar çalıştırın