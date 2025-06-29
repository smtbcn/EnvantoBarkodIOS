<!-- @format -->

# CİHAZ YETKİ KONTROLÜ TEMPLATE

Tüm yeni sayfalarda **BİREBİR AYNI** cihaz kontrolü mantığını kullanmak için bu template'i kopyalayın.

## 1. Gerekli Import'lar

```java
import com.envanto.barcode.utils.DeviceAuthManager;
```

Eğer Handler kullanıyorsanız:

```java
import android.os.Handler;
import android.os.Looper;
private Handler handler = new Handler(Looper.getMainLooper());
```

## 2. Ana Cihaz Kontrolü Metodu

**Bu metod TÜM sayfalarda BİREBİR AYNI olmalıdır:**

```java
/**
 * Cihaz yetkilendirme kontrolü yapar
 */
private void checkDeviceAuthorization() {
    DeviceAuthManager.checkDeviceAuthorization(this, new DeviceAuthManager.DeviceAuthCallback() {
        @Override
        public void onAuthSuccess() {
            // Yetkilendirme başarılı - sayfa özel işlemleri
            onDeviceAuthSuccess();
        }

        @Override
        public void onAuthFailure() {
            // Yetkilendirme başarısız - sayfa özel işlemleri
            onDeviceAuthFailure();
        }

        @Override
        public void onShowLoading() {
            // Yükleme başladı - sayfa özel işlemleri
            onDeviceAuthShowLoading();
        }

        @Override
        public void onHideLoading() {
            // Yükleme bitti - sayfa özel işlemleri
            onDeviceAuthHideLoading();
        }
    });
}
```

## 3. Sayfa Özel Metodlar

**Bu metodları sayfa ihtiyacına göre düzenleyin:**

```java
/**
 * Cihaz yetkilendirme başarılı olduğunda çalışır
 */
private void onDeviceAuthSuccess() {
    // Örnek: Veri yükle, içeriği göster, vs.
    // loadData();
    // binding.mainContent.setVisibility(View.VISIBLE);
}

/**
 * Cihaz yetkilendirme başarısız olduğunda çalışır
 */
private void onDeviceAuthFailure() {
    // Örnek: İçeriği gizle
    // binding.mainContent.setVisibility(View.GONE);
    // Activity zaten kapanacak
}

/**
 * Cihaz yetkilendirme yükleme başladığında çalışır
 */
private void onDeviceAuthShowLoading() {
    // Basit progress bar:
    // progressBar.setVisibility(View.VISIBLE);

    // Veya BarcodeUploadActivity gibi detaylı progress:
    // binding.progressBar.setVisibility(View.VISIBLE);
    // binding.progressText.setVisibility(View.VISIBLE);
    // binding.progressText.setText("Cihaz yetkilendirme kontrolü yapılıyor...");
    // binding.progressBar.setMax(100);
    // binding.progressBar.setProgress(30);
}

/**
 * Cihaz yetkilendirme yükleme bittiğinde çalışır
 */
private void onDeviceAuthHideLoading() {
    // Basit progress bar:
    // progressBar.setVisibility(View.GONE);

    // Veya BarcodeUploadActivity gibi detaylı progress:
    // binding.progressBar.setProgress(100);
    // handler.postDelayed(() -> {
    //     binding.progressBar.setVisibility(View.GONE);
    //     binding.progressText.setVisibility(View.GONE);
    // }, 500);
}
```

## 4. onCreate() İçinde Çağırma

```java
@Override
protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    // ... diğer kodlar ...

    // Cihaz yetkilendirme kontrolü
    checkDeviceAuthorization();
}
```

## 5. Mevcut Örnekler

- **VehicleProductsActivity.java** - Basit progress bar kullanımı
- **BarcodeUploadActivity.java** - Detaylı progress bar kullanımı

## ÖNEMLİ NOTLAR

1. `checkDeviceAuthorization()` metodu **TÜM sayfalarda BİREBİR AYNI** olmalıdır
2. Sadece `onDeviceAuth*` metodları sayfa ihtiyacına göre değiştirilir
3. Tek bir virgül bile farklı olmamalıdır
4. Yeni sayfalar eklerken bu template'i kullanın
