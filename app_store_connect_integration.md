# 🔑 App Store Connect Integration Kurulumu

## 📋 Şu Anda Durum

✅ **ios-appstore-build** workflow'u hazır
- App Store için signed IPA oluşturur
- Manuel olarak TestFlight'a yükleyebilirsiniz

⚠️ **App Store Connect integration** henüz kurulmadı
- Otomatik TestFlight yükleme için gerekli

## 🚀 İlk Adım: Signed IPA Alalım

### 1. Codemagic'te Build
```
Workflow: ios-appstore-build
```
Bu size App Store'a uygun signed IPA verecek.

### 2. Manuel TestFlight Yükleme
IPA dosyasını aldıktan sonra:
1. **App Store Connect** → **TestFlight**
2. **+** butonuna tıklayın
3. IPA dosyasını yükleyin

## 🔧 App Store Connect Integration Kurulumu

### Adım 1: App Store Connect'te API Key Oluşturma

1. **https://appstoreconnect.apple.com** → Giriş yapın
2. **Users and Access** → **Keys** sekmesi
3. **+** butonuna tıklayın
4. **Key Name**: `Codemagic Integration`
5. **Access**: App Manager
6. **Generate** tıklayın

### Adım 2: Key Bilgilerini Kaydedin

📝 **Bu bilgileri not edin:**
- **Key ID**: (örn: ABC123DEF4)
- **Issuer ID**: (örn: 12345678-1234-1234-1234-123456789012)
- **Private Key**: .p8 dosyasını indirin

### Adım 3: Codemagic'te Integration Ekleme

1. **Codemagic Dashboard** → **Team settings**
2. **Integrations** sekmesi
3. **Add integration** → **App Store Connect**
4. Bilgileri girin:
   - **Integration name**: `codemagic`
   - **Issuer ID**: Yukarıda not ettiğiniz
   - **Key ID**: Yukarıda not ettiğiniz
   - **Private key**: .p8 dosyasının içeriği
5. **Save** tıklayın

### Adım 4: YAML Güncelleme

Integration kurulduktan sonra YAML'a eklenecek:

```yaml
integrations:
  app_store_connect: codemagic
publishing:
  app_store_connect:
    auth: integration
    submit_to_testflight: true
    beta_groups:
      - App Store Connect Users
    submit_to_app_store: false
```

## 📱 App Store Connect'te App Oluşturma

### Adım 1: Yeni App
1. **My Apps** → **+** → **New App**
2. **Platform**: iOS
3. **Name**: `Envanto Barkod`
4. **Primary Language**: Turkish
5. **Bundle ID**: `com.envanto.barcode.ios`
6. **SKU**: `envanto-barkod-ios-2025`

### Adım 2: App Bilgileri
1. **App Information** sekmesi
2. **Subtitle**: `Profesyonel Barkod Tarayıcı`
3. **Category**: Business
4. **Content Rights**: Does Not Use Third-Party Content

### Adım 3: TestFlight Hazırlığı
1. **TestFlight** sekmesi
2. **Test Information** bölümü
3. **Beta App Description**: Uygulama açıklaması
4. **Beta App Review Information**: Test notları

## 🎯 Önerilen Sıralama

### 1. Şimdi: Signed IPA Build
```
Codemagic: ios-appstore-build workflow'unu çalıştırın
```

### 2. Manuel TestFlight Yükleme
- IPA'yı App Store Connect'te manuel yükleyin
- TestFlight'ta test edin

### 3. Integration Kurulumu
- API key oluşturun
- Codemagic'te integration ekleyin
- YAML'ı güncelleyin

### 4. Otomatik TestFlight
- Her build otomatik TestFlight'a yüklenecek

## ✅ Kontrol Listesi

Şu anda yapılacaklar:
- [ ] ios-appstore-build workflow'unu çalıştır
- [ ] Signed IPA al
- [ ] App Store Connect'te app oluştur
- [ ] API key oluştur
- [ ] Codemagic integration kur
- [ ] Manuel TestFlight yükleme dene
- [ ] Otomatik TestFlight'a geç

## 🚀 Hemen Başlayın

**Codemagic'te:**
1. **ios-appstore-build** seçin
2. **Start new build** tıklayın
3. Signed IPA alın

Bu başarılı olursa, App Store Connect kurulumuna geçeriz! 💪