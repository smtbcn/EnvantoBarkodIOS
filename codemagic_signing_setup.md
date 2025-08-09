# 🔐 Codemagic iOS Signing Kurulumu

## ❌ Sorun: "No Accounts" Hatası

Codemagic'te Apple Developer hesabı bağlı değil. Bu yüzden automatic signing çalışmıyor.

## ✅ Çözüm: Codemagic Signing

Codemagic'in kendi signing sistemini kullanacağız.

## 🚀 Adım 1: Apple Developer Portal Kurulumu

### 1. Apple Developer Portal'a Giriş
1. **https://developer.apple.com** → Account
2. Apple ID ile giriş: **samet.bicen@icloud.com**

### 2. Certificate Oluşturma
1. **Certificates, Identifiers & Profiles**
2. **Certificates** → **+**
3. **iOS App Development** seçin
4. **Continue**

### 3. CSR (Certificate Signing Request) Oluşturma
**Mac'te:**
1. **Keychain Access** açın
2. **Certificate Assistant** → **Request a Certificate from a Certificate Authority**
3. **User Email**: samet.bicen@icloud.com
4. **Common Name**: Samet Bicen
5. **Saved to disk** seçin
6. **Continue** → CSR dosyasını kaydedin

**Windows'ta (Alternatif):**
1. OpenSSL kullanın veya
2. Online CSR generator kullanın

### 4. Certificate İndirme
1. CSR dosyasını yükleyin
2. **Continue** → **Download**
3. .cer dosyasını kaydedin

### 5. Bundle ID Oluşturma
1. **Identifiers** → **+**
2. **App IDs** seçin
3. **Bundle ID**: `com.envanto.barcode.ios`
4. **Description**: `Envanto Barkod iOS`
5. **Capabilities**: Camera seçin
6. **Continue** → **Register**

### 6. Provisioning Profile Oluşturma
1. **Profiles** → **+**
2. **iOS App Development** seçin
3. **App ID**: `com.envanto.barcode.ios` seçin
4. **Certificate**: Oluşturduğunuz certificate'ı seçin
5. **Devices**: Tüm cihazları seçin (veya hiçbirini)
6. **Profile Name**: `Envanto Barkod Development`
7. **Generate** → **Download**

## 🔧 Adım 2: Codemagic'te Signing Kurulumu

### 1. Codemagic Dashboard
1. **Team settings** → **Code signing identities**
2. **iOS** sekmesi

### 2. Certificate Yükleme
1. **Add certificate** tıklayın
2. **Certificate**: .cer dosyasını yükleyin
3. **Certificate password**: (varsa)
4. **Certificate name**: `iOS Development`

### 3. Provisioning Profile Yükleme
1. **Add profile** tıklayın
2. **Provisioning profile**: .mobileprovision dosyasını yükleyin
3. **Profile name**: `Envanto Barkod Development`

## 🎯 Adım 3: Build Testi

### 1. Workflow Seçimi
```
Codemagic'te: ios-codemagic-signing workflow'unu seçin
```

### 2. Beklenen Sonuç
- ✅ Codemagic otomatik signing kullanacak
- ✅ Development IPA oluşturacak
- ✅ iPhone'a kurulabilir

## 🔄 Alternatif: Basit Çözüm

Eğer Apple Developer kurulumu karmaşık geliyorsa:

### 1. Unsigned IPA ile Devam
```
Workflow: ios-no-signing-build (zaten başarılı)
```

### 2. Re-signing Araçları
- **iOS App Signer** (Mac)
- **3uTools** (Windows)
- **AltStore** (iPhone'da)

### 3. Sideloading
- **AltStore** ile iPhone'a yükleme
- **Sideloadly** kullanma
- **TrollStore** (jailbreak gerekli)

## 📱 Hızlı Test: AltStore

### 1. AltStore Kurulumu
1. **https://altstore.io** → İndirin
2. iPhone'unuza kurun
3. Apple ID ile giriş yapın

### 2. IPA Kurulumu
1. Unsigned IPA'yı AltStore'a ekleyin
2. AltStore otomatik sign edecek
3. iPhone'unuzda çalışacak

## ✅ Önerilen Sıralama

### Seçenek 1: Codemagic Signing (Profesyonel)
1. Apple Developer Portal kurulumu
2. Certificate ve profile oluşturma
3. Codemagic'te signing kurulumu
4. ios-codemagic-signing workflow'u

### Seçenek 2: AltStore (Hızlı)
1. AltStore kurulumu
2. Unsigned IPA kullanma
3. AltStore ile signing

### Seçenek 3: 3uTools (Windows)
1. 3uTools kurulumu
2. Unsigned IPA'yı re-sign etme
3. iPhone'a kurulum

## 🎯 Hangi Yöntemi Tercih Edersiniz?

1. **Profesyonel**: Apple Developer + Codemagic signing
2. **Hızlı**: AltStore ile sideloading
3. **Windows**: 3uTools ile re-signing

Tercihinizi bildirin, o yöntemle devam edelim! 💪