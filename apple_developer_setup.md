# 🍎 Apple Developer Portal Kurulum Rehberi

## 📱 Cihaz Kaydı (ZORUNLU)

### Adım 1: Apple Developer Portal'a Giriş
1. **https://developer.apple.com** adresine gidin
2. **Account** butonuna tıklayın
3. Apple ID ile giriş yapın: **samet.bicen@icloud.com**

### Adım 2: Certificates, Identifiers & Profiles
1. Giriş yaptıktan sonra **Certificates, Identifiers & Profiles** bölümüne gidin
2. Sol menüden **Devices** seçin

### Adım 3: Cihaz Ekleme
1. **+** (Register a New Device) butonuna tıklayın
2. Şu bilgileri girin:
   - **Platform**: iOS
   - **Device Name**: `SMTBCN 16pro`
   - **Device ID (UDID)**: `00008140-001469903469801C`
3. **Continue** butonuna tıklayın
4. **Register** butonuna tıklayın

### Adım 4: Onay
✅ "Device successfully registered" mesajını görmelisiniz

## 🔧 Bundle ID Kontrolü

### Adım 1: Identifiers Bölümü
1. Sol menüden **Identifiers** seçin
2. **App IDs** sekmesinde olduğunuzdan emin olun

### Adım 2: Bundle ID Arama
1. Arama kutusuna `com.envanto.barcode.ios` yazın
2. Eğer bulunamazsa **+** butonuna tıklayın

### Adım 3: Yeni Bundle ID Oluşturma (Gerekirse)
1. **App IDs** seçin
2. **App** seçin
3. **Continue** tıklayın
4. Şu bilgileri girin:
   - **Description**: `Envanto Barkod iOS`
   - **Bundle ID**: `com.envanto.barcode.ios`
5. **Capabilities** bölümünde gerekli izinleri seçin:
   - ✅ Camera
   - ✅ Background App Refresh
6. **Continue** → **Register**

## 🎯 Provisioning Profile Oluşturma

### Adım 1: Profiles Bölümü
1. Sol menüden **Profiles** seçin
2. **+** (Generate a profile) butonuna tıklayın

### Adım 2: Development Profile
1. **iOS App Development** seçin
2. **Continue** tıklayın

### Adım 3: App ID Seçimi
1. **App ID** dropdown'dan `com.envanto.barcode.ios` seçin
2. **Continue** tıklayın

### Adım 4: Certificate Seçimi
1. Development certificate'ınızı seçin
2. Eğer yoksa önce certificate oluşturmanız gerekir
3. **Continue** tıklayın

### Adım 5: Device Seçimi
1. **SMTBCN 16pro** cihazınızı seçin
2. **Continue** tıklayın

### Adım 6: Profile Adı
1. **Provisioning Profile Name**: `Envanto Barkod Development`
2. **Generate** tıklayın

### Adım 7: İndirme
1. **Download** butonuna tıklayın
2. Profile'ı bilgisayarınıza kaydedin

## 🔐 Development Certificate (Gerekirse)

Eğer development certificate'ınız yoksa:

### Adım 1: Certificates Bölümü
1. Sol menüden **Certificates** seçin
2. **+** butonuna tıklayın

### Adım 2: Certificate Türü
1. **iOS App Development** seçin
2. **Continue** tıklayın

### Adım 3: CSR Oluşturma
1. Mac'te **Keychain Access** açın
2. **Certificate Assistant** → **Request a Certificate from a Certificate Authority**
3. Email: `samet.bicen@icloud.com`
4. Common Name: `Samet Bicen`
5. **Saved to disk** seçin
6. **Continue** → CSR dosyasını kaydedin

### Adım 4: CSR Yükleme
1. **Choose File** ile CSR dosyasını seçin
2. **Continue** tıklayın
3. **Download** ile certificate'ı indirin

## ✅ Kontrol Listesi

Tamamlanması gerekenler:
- [ ] Apple Developer Portal'a giriş yapıldı
- [ ] Cihaz kaydedildi (SMTBCN 16pro)
- [ ] Bundle ID oluşturuldu/kontrol edildi
- [ ] Development certificate var
- [ ] Provisioning profile oluşturuldu

## 🚀 Sonraki Adım

Bu adımları tamamladıktan sonra:
1. Codemagic'te **ios-manual-signing** workflow'unu çalıştırın
2. Bu sefer provisioning profile bulunacak
3. Başarılı build alacaksınız

## ❗ Önemli Notlar

1. **Ücretsiz Apple Developer hesabı** yeterli (99$/yıl gerekmez)
2. **Cihaz kaydı zorunlu** - Bu olmadan build alamazsınız
3. **Certificate süresi** - 1 yıl geçerli
4. **Provisioning profile süresi** - 1 yıl geçerli
5. **Maksimum cihaz sayısı** - Ücretsiz hesapta 100 cihaz

Bu adımları tamamladıktan sonra build almayı tekrar deneyin!