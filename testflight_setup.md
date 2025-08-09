# 🚀 TestFlight Kurulum Rehberi

## 📋 TestFlight Avantajları

✅ **Kolay kurulum** - App Store'dan TestFlight indirin
✅ **Otomatik güncellemeler** - Yeni build'ler otomatik gelir
✅ **Beta test yönetimi** - Kullanıcı grupları oluşturabilirsiniz
✅ **Crash raporları** - Otomatik hata raporları
✅ **Geri bildirim** - Kullanıcılardan feedback alabilirsiniz
✅ **Profesyonel** - Gerçek App Store deneyimi

## 🍎 App Store Connect Kurulumu

### Adım 1: App Store Connect'e Giriş
1. **https://appstoreconnect.apple.com** adresine gidin
2. Apple ID ile giriş yapın: **samet.bicen@icloud.com**

### Adım 2: Yeni App Oluşturma
1. **My Apps** bölümüne gidin
2. **+** butonuna tıklayın → **New App**
3. Şu bilgileri girin:
   - **Platform**: iOS
   - **Name**: `Envanto Barkod`
   - **Primary Language**: Turkish
   - **Bundle ID**: `com.envanto.barcode.ios`
   - **SKU**: `envanto-barkod-ios-2025`
   - **User Access**: Full Access

### Adım 3: App Bilgileri
1. **App Information** sekmesine gidin
2. Temel bilgileri doldurun:
   - **Subtitle**: `Profesyonel Barkod Tarayıcı`
   - **Category**: Business veya Utilities
   - **Content Rights**: Does Not Use Third-Party Content

### Adım 4: TestFlight Ayarları
1. **TestFlight** sekmesine gidin
2. **Test Information** bölümünde:
   - **Beta App Description**: Uygulama açıklaması
   - **Beta App Review Information**: Test için notlar
   - **Test Details**: Ne test edileceği

## 🔑 API Key Oluşturma (Codemagic için)

### Adım 1: Users and Access
1. App Store Connect'te **Users and Access** bölümüne gidin
2. **Keys** sekmesini seçin

### Adım 2: Yeni API Key
1. **+** butonuna tıklayın
2. **Key Name**: `Codemagic API Key`
3. **Access**: App Manager
4. **Generate** tıklayın

### Adım 3: Key Bilgilerini Kaydedin
📝 **Önemli bilgileri not edin:**
- **Key ID**: (örn: ABC123DEF4)
- **Issuer ID**: (örn: 12345678-1234-1234-1234-123456789012)
- **Private Key**: .p8 dosyasını indirin

## ⚙️ Codemagic Konfigürasyonu

### Adım 1: Codemagic'te App Store Connect Integration
1. Codemagic dashboard'a gidin
2. **Team settings** → **Integrations**
3. **App Store Connect** bölümünde **Add integration**

### Adım 2: API Key Bilgilerini Girin
- **Integration name**: `App Store Connect`
- **Issuer ID**: Yukarıda not ettiğiniz ID
- **Key ID**: Yukarıda not ettiğiniz ID
- **Private key**: .p8 dosyasının içeriğini yapıştırın

### Adım 3: Integration'ı Kaydedin
✅ **Save** butonuna tıklayın

## 🚀 İlk TestFlight Build

### Adım 1: Workflow Seçimi
Codemagic'te **ios-testflight-workflow** seçin

### Adım 2: Build Başlatma
**Start new build** butonuna tıklayın

### Adım 3: Beklenen Süreç
1. ⏱️ Build süresi: ~10-15 dakika
2. 📦 IPA oluşturulacak
3. 🚀 Otomatik TestFlight'a yüklenecek
4. ✅ Email ile bildirim gelecek

## 📱 TestFlight'tan Uygulama İndirme

### Adım 1: TestFlight App İndirin
- App Store'dan **TestFlight** uygulamasını indirin
- Apple ID ile giriş yapın

### Adım 2: Beta Davetini Kabul Edin
1. App Store Connect'te kendinizi beta tester olarak ekleyin
2. Email'e gelen daveti kabul edin
3. TestFlight'ta uygulama görünecek

### Adım 3: Uygulamayı İndirin
- TestFlight'ta **Install** butonuna tıklayın
- Uygulama iPhone'unuza kurulacak

## 🔄 Otomatik Güncellemeler

Her yeni build'de:
1. 🔄 Codemagic otomatik build alır
2. 📤 TestFlight'a yükler
3. 📱 TestFlight'ta güncelleme bildirimi gelir
4. 🆕 Tek tıkla güncelleme yapabilirsiniz

## 📊 TestFlight Özellikleri

### Beta Test Yönetimi
- **Internal Testing**: Takım üyeleri (25 kişi)
- **External Testing**: Dış kullanıcılar (10,000 kişi)
- **Test Groups**: Kullanıcı grupları oluşturma

### Analytics
- **Crash Reports**: Otomatik hata raporları
- **Usage Data**: Kullanım istatistikleri
- **Feedback**: Kullanıcı geri bildirimleri

### Build Yönetimi
- **Build History**: Tüm build'lerin geçmişi
- **Release Notes**: Her build için notlar
- **Expiration**: Build'ler 90 gün geçerli

## ✅ Kontrol Listesi

TestFlight kurulumu için:
- [ ] App Store Connect'te app oluşturuldu
- [ ] API Key oluşturuldu
- [ ] Codemagic'te integration yapıldı
- [ ] İlk build başlatıldı
- [ ] TestFlight app indirildi
- [ ] Beta tester olarak eklendi

## 🎯 Sonuç

TestFlight kurulumu tamamlandıktan sonra:
- ✅ Profesyonel beta test ortamı
- ✅ Kolay dağıtım ve güncelleme
- ✅ Gerçek kullanıcı testleri
- ✅ App Store'a hazırlık

Bu kurulum bir kez yapıldıktan sonra, her kod değişikliğinde otomatik olarak yeni build TestFlight'a yüklenecek! 🚀