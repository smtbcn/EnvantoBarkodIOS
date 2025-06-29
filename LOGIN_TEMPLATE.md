<!-- @format -->

# LOGİN SİSTEMİ TEMPLATE

Tüm yeni sayfalarda **BİREBİR AYNI** login kontrolü mantığını kullanmak için bu template'i kopyalayın.

## 1. Gerekli Import'lar

```java
import com.envanto.barcode.api.LoginResponse;
import com.envanto.barcode.utils.LoginManager;
```

## 2. Activity'de Kullanım Sırası

```java
@Override
protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    // ... diğer kodlar ...

    // 1. Önce cihaz kontrolü
    checkDeviceAuthorization();
}
```

## 3. Cihaz Yetki Başarı Callback'i

**DeviceAuthManager callback'inde login kontrolü ekleyin:**

```java
/**
 * Cihaz yetkilendirme başarılı olduğunda çalışır
 */
private void onDeviceAuthSuccess() {
    // Cihaz yetkilendirme başarılı, şimdi kullanıcı girişi kontrol et
    checkUserLogin();
}
```

## 4. Login Kontrol Metodu

**Bu metod TÜM sayfalarda BİREBİR AYNI olmalıdır:**

```java
/**
 * Kullanıcı girişi kontrolü yapar
 */
private void checkUserLogin() {
    // Eğer kullanıcı zaten giriş yapmışsa ve oturum süresi dolmamışsa
    if (LoginManager.isLoggedIn(this) && !LoginManager.isSessionExpired(this)) {
        // Direkt ana içeriği yükle
        onLoginSuccess();
    } else {
        // Login ekranını göster
        showLoginDialog();
    }
}
```

## 5. Login Dialog Metodu

**Bu metod TÜM sayfalarda BİREBİR AYNI olmalıdır:**

```java
/**
 * Login dialog'unu gösterir
 */
private void showLoginDialog() {
    // TODO: Login dialog implementation
    // Şimdilik geçici olarak ana içeriği yükle
    onLoginSuccess();
}
```

## 6. Login Başarı Callback'i

**Bu metodu sayfa ihtiyacına göre düzenleyin:**

```java
/**
 * Login başarılı olduğunda çalışır
 */
private void onLoginSuccess() {
    // Örnek: Ana içeriği yükle
    // loadMainContent();
    // loadVehicleProducts();
    // loadCustomers();
}
```

## 7. LoginManager Metodları

### Giriş Kontrolü:

```java
LoginManager.isLoggedIn(this)           // Giriş yapılmış mı?
LoginManager.isSessionExpired(this)     // Oturum süresi dolmuş mu?
LoginManager.getCurrentUser(this)       // Mevcut kullanıcı bilgileri
LoginManager.getUserToken(this)         // Kullanıcı token'ı
```

### Oturum Yönetimi:

```java
LoginManager.logout(this)               // Çıkış yap
```

### Login İşlemi:

```java
LoginManager.login(this, email, password, new LoginManager.LoginCallback() {
    @Override
    public void onLoginSuccess(LoginResponse.User user) {
        // Giriş başarılı
        onLoginSuccess();
    }

    @Override
    public void onLoginFailure(String message, String errorCode) {
        // Giriş başarısız
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }

    @Override
    public void onShowLoading() {
        // Yükleme göster
    }

    @Override
    public void onHideLoading() {
        // Yükleme gizle
    }
});
```

## 8. Tam Akış Örneği

```java
onCreate()
    ↓
checkDeviceAuthorization()
    ↓
onDeviceAuthSuccess()
    ↓
checkUserLogin()
    ↓
LoginManager.isLoggedIn() && !isSessionExpired()
    ↓
onLoginSuccess() → Ana içerik yüklenir
```

## 9. Backend API

- **Endpoint**: `login_api.asp`
- **Method**: POST
- **Parameters**:
  - `action=login`
  - `email=kullanici@email.com`
  - `password=sifre123`

## 10. Mevcut Örnekler

- **VehicleProductsActivity.java** - Temel login entegrasyonu

## ÖNEMLİ NOTLAR

1. `checkUserLogin()` metodu **TÜM sayfalarda BİREBİR AYNI** olmalıdır
2. `showLoginDialog()` metodu **TÜM sayfalarda BİREBİR AYNI** olmalıdır
3. Sadece `onLoginSuccess()` metodu sayfa ihtiyacına göre değiştirilir
4. Login kontrolü her zaman cihaz kontrolünden SONRA yapılır
5. Oturum süresi 24 saattir
6. Token tabanlı session yönetimi kullanılır
