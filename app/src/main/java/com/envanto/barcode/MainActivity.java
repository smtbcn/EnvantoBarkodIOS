package com.envanto.barcode;

import android.Manifest;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.provider.Settings;
import android.util.Log;
import android.view.View;
import android.widget.Toast;
import android.widget.TextView;
import android.widget.EditText;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;

import com.google.android.material.card.MaterialCardView;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.envanto.barcode.service.UploadRetryService;
import com.envanto.barcode.service.UpdateManager;
import com.envanto.barcode.api.ApiClient;
import com.envanto.barcode.api.ApiService;
import com.envanto.barcode.model.UpdateInfo;
import com.envanto.barcode.utils.AppConstants;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class MainActivity extends AppCompatActivity {

    private ActivityResultLauncher<String[]> permissionLauncher;
    private boolean permissionsGranted = false;
    private SharedPreferences preferences;
    private TextView deviceOwnerText;
    private UpdateManager updateManager;
    
    // Preference keys
    private static final String PREF_NAME = "envanto_barcode_prefs";
    private static final String PREF_SERVICE_CONFIGURED = "service_configured";
    private static final String PREF_PERMISSIONS_ASKED = "permissions_asked";
    private static final String PREF_WIFI_ONLY = "wifi_only";
    private static final String PREF_BATTERY_OPT_INFO_SHOWN = "battery_opt_info_shown";
    private static final String PREF_UPDATE_DIALOG_SHOWN = "update_dialog_shown";
    private static final String PREF_LAST_UPDATE_CHECK = "last_update_check";
    private static final long UPDATE_CHECK_INTERVAL = AppConstants.App.UPDATE_CHECK_INTERVAL;

    private boolean isDialogShowing = false;
    private AlertDialog currentDialog = null;
    private AlertDialog loadingDialog = null;
    private Handler progressHandler = new Handler();
    private Runnable progressRunnable;
    private long currentDownloadId = -1;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // [UPDATE-FUNCTION] Update Manager'ı başlat - Uygulama güncelleme mekanizması
        updateManager = new UpdateManager(this);

        // Action Bar'ı gizle
        if (getSupportActionBar() != null) {
            getSupportActionBar().hide();
        }

        // SharedPreferences'ı başlat
        preferences = getSharedPreferences(PREF_NAME, MODE_PRIVATE);

        // Permission launcher'ı başlat
        setupPermissionLauncher();

        // İzinleri kontrol et ve iste
        checkAndRequestPermissions();

        // Barkod Tara butonu
        MaterialCardView scanButton = findViewById(R.id.scanButton);
        scanButton.setOnClickListener(v -> {
            if (permissionsGranted) {
                Intent intent = new Intent(MainActivity.this, ScannerActivity.class);
                startActivity(intent);
            } else {
                showPermissionRequiredDialog();
            }
        });

        // Barkod Yükle butonu
        MaterialCardView uploadButton = findViewById(R.id.uploadButton);
        uploadButton.setOnClickListener(v -> {
            if (permissionsGranted) {
                Intent intent = new Intent(MainActivity.this, BarcodeUploadActivity.class);
                startActivity(intent);
            } else {
                showPermissionRequiredDialog();
            }
        });
        
        // Müşteri Resimleri butonu
        MaterialCardView customerImagesButton = findViewById(R.id.customerImagesButton);
        customerImagesButton.setOnClickListener(v -> {
            if (permissionsGranted) {
                Intent intent = new Intent(MainActivity.this, CustomerImagesActivity.class);
                startActivity(intent);
            } else {
                showPermissionRequiredDialog();
            }
        });
        
        // Araçtaki Ürünler butonu
        MaterialCardView vehicleProductsButton = findViewById(R.id.vehicleProductsButton);
        vehicleProductsButton.setOnClickListener(v -> {
            if (permissionsGranted) {
                Intent intent = new Intent(MainActivity.this, VehicleProductsActivity.class);
                startActivity(intent);
            } else {
                showPermissionRequiredDialog();
            }
        });
        
        // Ayarlar butonu
        MaterialCardView settingsButton = findViewById(R.id.settingsButton);
        settingsButton.setOnClickListener(v -> showSettingsDialog());
        
        // Cihaz sahibi text'ini bağla
        deviceOwnerText = findViewById(R.id.deviceOwnerText);
        updateDeviceOwnerDisplay();
        
        // Versiyon ismini göster
        TextView versionText = findViewById(R.id.versionText);
        String versionName = BuildConfig.VERSION_NAME;
        versionText.setText("Versiyon: " + versionName);
        
        // NOT: Güncelleme kontrolü artık izinler alındıktan sonra onResume metodunda yapılacak
    }

    // Güncelleme kontrolü yap
    /**
     * [UPDATE-FUNCTION] Uygulama güncellemelerini kontrol eder
     * UpdateManager sınıfı üzerinden güncelleme kontrolü başlatır
     */
    private void checkForUpdates() {
        if (updateManager == null) return;

        // Son güncelleme kontrolünden bu yana geçen süreyi kontrol et
        long lastCheck = preferences.getLong(PREF_LAST_UPDATE_CHECK, 0);
        long currentTime = System.currentTimeMillis();
        
        // Eğer son kontrolden bu yana 1 saat geçmediyse ve dialog daha önce gösterildiyse
        if (currentTime - lastCheck < UPDATE_CHECK_INTERVAL && preferences.getBoolean(PREF_UPDATE_DIALOG_SHOWN, false)) {
            return;
        }

        // Güncelleme kontrolü için yeterli süre bekle
        new Handler().postDelayed(() -> {
            // İzinler ve servis ayarları tamamlandıysa güncelleme kontrolü yap
            if (permissionsGranted && preferences.getBoolean(PREF_SERVICE_CONFIGURED, false)) {
                updateManager.checkForUpdate(true);
                // Son kontrol zamanını güncelle
                preferences.edit()
                    .putLong(PREF_LAST_UPDATE_CHECK, currentTime)
                    .putBoolean(PREF_UPDATE_DIALOG_SHOWN, true)
                    .apply();
            }
        }, AppConstants.Timing.MEDIUM_DELAY);
    }

    private void setupPermissionLauncher() {
        permissionLauncher = registerForActivityResult(
            new ActivityResultContracts.RequestMultiplePermissions(),
            result -> {
                boolean allGranted = true;
                List<String> deniedPermissions = new ArrayList<>();
                
                for (Map.Entry<String, Boolean> entry : result.entrySet()) {
                    if (!entry.getValue()) {
                        allGranted = false;
                        deniedPermissions.add(entry.getKey());
                    }
                }
                
                if (allGranted) {
                    permissionsGranted = true;
                    
                    // İzinlerin sorulduğunu kaydet
                    preferences.edit().putBoolean(PREF_PERMISSIONS_ASKED, true).apply();
                    
                    Toast.makeText(this, "✅ Tüm izinler verildi. Uygulama kullanıma hazır!", Toast.LENGTH_SHORT).show();
                    
                    // Service henüz konfigüre edilmemişse konfigüre et
                    if (!preferences.getBoolean(PREF_SERVICE_CONFIGURED, false)) {
                        // Servis ayarları için bir süre bekle
                        new Handler().postDelayed(() -> {
                            startUploadRetryService();
                        }, AppConstants.Timing.SHORT_DELAY); // Kısa gecikme
                    } else {
                        // Daha önce konfigüre edilmiş ayarları kullan
                        boolean wifiOnly = preferences.getBoolean(PREF_WIFI_ONLY, true);
                        startServiceWithOption(wifiOnly);
                        
                        // Servis ayarları tamamlandı, güncelleme kontrolü yap
                        new Handler().postDelayed(() -> {
                            checkForUpdates();
                        }, AppConstants.Timing.MEDIUM_DELAY); // Orta gecikme
                    }
                } else {
                    permissionsGranted = false;
                    showPermissionDeniedDialog(deniedPermissions);
                }
            }
        );
    }

    private void checkAndRequestPermissions() {
        List<String> permissionsToRequest = new ArrayList<>();
        
        // Kamera izni
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) 
                != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.CAMERA);
        }
        
        // Storage izinleri - Android versiyonuna göre
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ için yeni media permissions
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) 
                    != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_MEDIA_IMAGES);
            }
        } else {
            // Android 12 ve altı için eski storage permissions
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) 
                    != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_EXTERNAL_STORAGE);
            }
            
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                // Android 9 ve altı için write permission
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) 
                        != PackageManager.PERMISSION_GRANTED) {
                    permissionsToRequest.add(Manifest.permission.WRITE_EXTERNAL_STORAGE);
                }
            }
        }
        
        // REQUEST_INSTALL_PACKAGES izni kontrolü (Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (!getPackageManager().canRequestPackageInstalls()) {
                Log.d("MainActivity", "Bilinmeyen kaynaklardan yükleme izni gerekli");
                // Bu izin runtime'da istenmez, ayarlardan verilir
            }
        }
        
        if (permissionsToRequest.isEmpty()) {
            // Tüm izinler zaten verilmiş
            permissionsGranted = true;
            
            // Service henüz konfigüre edilmemişse konfigüre et
            if (!preferences.getBoolean(PREF_SERVICE_CONFIGURED, false)) {
                startUploadRetryService();
            } else {
                // Daha önce konfigüre edilmiş ayarları kullan
                boolean wifiOnly = preferences.getBoolean(PREF_WIFI_ONLY, true);
                startServiceWithOption(wifiOnly);
            }
            
            // İzinler verildiği için güncelleme kontrolü yap
            checkForUpdates();
        } else {
            // İzin açıklama dialog'u göster
            showPermissionExplanationDialog(permissionsToRequest);
        }
    }

    private void showPermissionExplanationDialog(List<String> permissions) {
        if (isDialogShowing) return;
        
        StringBuilder message = new StringBuilder();
        message.append("🔐 Bu uygulama düzgün çalışabilmesi için aşağıdaki izinlere ihtiyaç duyar:\n\n");
        
        for (String permission : permissions) {
            switch (permission) {
                case Manifest.permission.CAMERA:
                    message.append("📷 Kamera İzni\n");
                    message.append("   • Barkod tarama işlemleri için\n");
                    message.append("   • Resim çekme işlemleri için\n\n");
                    break;
                case Manifest.permission.READ_EXTERNAL_STORAGE:
                    message.append("📁 Depolama Okuma İzni\n");
                    message.append("   • Galeri'den resim seçmek için\n");
                    message.append("   • Kayıtlı resimleri görüntülemek için\n\n");
                    break;
                case Manifest.permission.WRITE_EXTERNAL_STORAGE:
                    message.append("💾 Depolama Yazma İzni\n");
                    message.append("   • Resimleri cihaza kaydetmek için\n");
                    message.append("   • Yedekleme işlemleri için\n\n");
                    break;
                case Manifest.permission.READ_MEDIA_IMAGES:
                    message.append("🖼️ Medya Erişim İzni\n");
                    message.append("   • Galeri'den resim seçmek için\n");
                    message.append("   • Resim dosyalarını okumak için\n\n");
                    break;
            }
        }
        
        message.append("✅ İzinleri vermek istiyor musunuz?");
        
        isDialogShowing = true;
        currentDialog = new MaterialAlertDialogBuilder(this)
            .setTitle("🔑 İzin Gerekli")
            .setMessage(message.toString())
            .setPositiveButton("İzin Ver", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
                permissionLauncher.launch(permissions.toArray(new String[0]));
            })
            .setNegativeButton("İptal", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
                permissionsGranted = false;
            })
            .setCancelable(false)
            .setOnDismissListener(dialog -> {
                isDialogShowing = false;
                currentDialog = null;
            })
            .show();
    }

    private void showPermissionDeniedDialog(List<String> deniedPermissions) {
        if (isDialogShowing) return;
        
        StringBuilder message = new StringBuilder();
        message.append("❌ Aşağıdaki izinler reddedildi:\n\n");
        
        for (String permission : deniedPermissions) {
            switch (permission) {
                case Manifest.permission.CAMERA:
                    message.append("📷 Kamera İzni\n");
                    break;
                case Manifest.permission.READ_EXTERNAL_STORAGE:
                    message.append("📁 Depolama Okuma İzni\n");
                    break;
                case Manifest.permission.WRITE_EXTERNAL_STORAGE:
                    message.append("💾 Depolama Yazma İzni\n");
                    break;
                case Manifest.permission.READ_MEDIA_IMAGES:
                    message.append("🖼️ Medya Erişim İzni\n");
                    break;
            }
        }
        
        message.append("\n⚙️ Uygulama ayarlarından izinleri manuel olarak verebilirsiniz.\n\n");
        message.append("💡 İpucu: Ayarlar > Uygulamalar > Envanto Barkod > İzinler");
        
        isDialogShowing = true;
        currentDialog = new MaterialAlertDialogBuilder(this)
            .setTitle("🚫 İzin Reddedildi")
            .setMessage(message.toString())
            .setPositiveButton("🔄 Tekrar Dene", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
                checkAndRequestPermissions();
            })
            .setNegativeButton("Tamam", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
            })
            .setOnDismissListener(dialog -> {
                isDialogShowing = false;
                currentDialog = null;
            })
            .show();
    }

    private void showPermissionRequiredDialog() {
        if (isDialogShowing) return;
        
        isDialogShowing = true;
        currentDialog = new MaterialAlertDialogBuilder(this)
            .setTitle("🔐 İzin Gerekli")
            .setMessage("Bu özelliği kullanabilmek için gerekli izinleri vermeniz gerekiyor.\n\n" +
                       "📱 Uygulama düzgün çalışabilmesi için kamera ve depolama izinlerine ihtiyaç duyar.")
            .setPositiveButton("✅ İzin Ver", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
                checkAndRequestPermissions();
            })
            .setNegativeButton("İptal", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
            })
            .setOnDismissListener(dialog -> {
                isDialogShowing = false;
                currentDialog = null;
            })
            .show();
    }

    @Override
    protected void onResume() {
        super.onResume();
        // İzinleri yeniden kontrol et (kullanıcı ayarlardan değiştirmiş olabilir)
        recheckPermissions();
        
        // Cihaz sahibi bilgisini güncelle
        updateDeviceOwnerDisplay();
        
        // İzin ve servis kontrolleri
        if (!permissionsGranted) {
            // İzinler verilmemiş, kontrol et ve gerekirse sor
            if (!preferences.getBoolean(PREF_PERMISSIONS_ASKED, false)) {
                checkAndRequestPermissions();
            }
        } else {
            // İzinler verilmiş, servis durumunu kontrol et
            if (!preferences.getBoolean(PREF_SERVICE_CONFIGURED, false)) {
                // Servis henüz yapılandırılmamış, kullanıcıya sor
                startUploadRetryService();
            } else {
                // Tüm ayarlar tamam, güncelleme kontrolü yap
                checkForUpdates();
            }
        }
    }
    
    private void recheckPermissions() {
        boolean allPermissionsGranted = true;
        
        // Kamera izni
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) 
                != PackageManager.PERMISSION_GRANTED) {
            allPermissionsGranted = false;
        }
        
        // Storage izinleri
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) 
                    != PackageManager.PERMISSION_GRANTED) {
                allPermissionsGranted = false;
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) 
                    != PackageManager.PERMISSION_GRANTED) {
                allPermissionsGranted = false;
            }
            
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) 
                        != PackageManager.PERMISSION_GRANTED) {
                    allPermissionsGranted = false;
                }
            }
        }
        
        permissionsGranted = allPermissionsGranted;
    }

    private void startUploadRetryService() {
        if (isDialogShowing) return;
        
        isDialogShowing = true;
        currentDialog = new MaterialAlertDialogBuilder(this)
            .setTitle("🚀 Arkaplan Yükleme Ayarı")
            .setMessage("Resimlerin arkaplanda sunucuya yüklenmesi için hangi bağlantı türünü kullanmak istersiniz?\n\n" +
                       "📶 Sadece WiFi: Veri tasarrufu sağlar\n" +
                       "🌐 Tüm Bağlantılar: Hızlı yükleme imkanı\n\n" +
                       "💡 Bu ayarı daha sonra değiştirebilirsiniz.\n\n" +
                       "⚠️ Not: Uygulamanın arka planda sorunsuz çalışması için pil optimizasyonu ayarlarını kapatmanız gerekebilir.")
            .setPositiveButton("📶 Sadece WiFi", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
                saveServicePreference(true);
                startServiceWithOption(true);
                showBatteryOptimizationInfo();
            })
            .setNegativeButton("🌐 Tüm Bağlantılar", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
                saveServicePreference(false);
                startServiceWithOption(false);
                showBatteryOptimizationInfo();
            })
            .setNeutralButton("⏭️ Şimdi Değil", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
                preferences.edit().putBoolean(PREF_SERVICE_CONFIGURED, false).apply();
            })
            .setCancelable(false)
            .setOnDismissListener(dialog -> {
                isDialogShowing = false;
                currentDialog = null;
            })
            .show();
    }
    
    private void saveServicePreference(boolean wifiOnly) {
        preferences.edit()
            .putBoolean(PREF_SERVICE_CONFIGURED, true)
            .putBoolean(PREF_WIFI_ONLY, wifiOnly)
            .apply();
    }
    
    private void startServiceWithOption(boolean wifiOnly) {
        try {
            Intent serviceIntent = new Intent(this, UploadRetryService.class);
            serviceIntent.putExtra(UploadRetryService.EXTRA_WIFI_ONLY, wifiOnly);
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent);
            } else {
                startService(serviceIntent);
            }
            
            Log.d("MainActivity", "UploadRetryService başlatıldı - WiFi only: " + wifiOnly);
        } catch (Exception e) {
            Log.e("MainActivity", "UploadRetryService başlatma hatası: " + e.getMessage());
            Toast.makeText(this, "❌ Arkaplan servis başlatılamadı: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    private void showSettingsDialog() {
        boolean serviceConfigured = preferences.getBoolean(PREF_SERVICE_CONFIGURED, false);
        boolean wifiOnly = preferences.getBoolean(PREF_WIFI_ONLY, true);
        
        String currentSetting = serviceConfigured ? 
            (wifiOnly ? "📶 Sadece WiFi" : "🌐 Tüm Bağlantılar") : "❌ Yapılandırılmamış";
            
        new MaterialAlertDialogBuilder(this)
            .setTitle("⚙️ Uygulama Ayarları")
            .setMessage("Mevcut arkaplan yükleme ayarı:\n" + currentSetting + 
                       "\n\n🔧 Ne yapmak istiyorsunuz?")
            .setPositiveButton("🔄 Ayarları Sıfırla", (dialog, which) -> {
                dialog.dismiss(); // Diyaloğu kapat
                resetAllPreferences();
            })
            .setNegativeButton("📡 Bağlantı Ayarını Değiştir", (dialog, which) -> {
                dialog.dismiss(); // Diyaloğu kapat
                if (serviceConfigured) {
                    startUploadRetryService();
                } else {
                    Toast.makeText(this, "⚠️ Önce izinleri verin", Toast.LENGTH_SHORT).show();
                }
            })
            .setNeutralButton("🔋 Pil Optimizasyonu", (dialog, which) -> {
                dialog.dismiss(); // Diyaloğu kapat
                openBatteryOptimizationSettings();
            })
            .show();
    }
    
    private void openBatteryOptimizationSettings() {
        try {
        Intent intent = new Intent();
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Doğrudan pil optimizasyonu sayfasına git
            intent.setAction(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                intent.setData(Uri.fromParts("package", getPackageName(), null));
            startActivity(intent);
        } else {
            // Eski cihazlarda uygulama ayarlarına git
            intent.setAction(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
            intent.setData(Uri.fromParts("package", getPackageName(), null));
            startActivity(intent);
            }
        } catch (Exception e) {
            Log.e("MainActivity", "Ayarlar sayfası açılamadı: " + e.getMessage());
            Toast.makeText(this, "Ayarlar sayfası açılamadı. Lütfen manuel olarak uygulama ayarlarına gidin.", Toast.LENGTH_LONG).show();
        }
    }
    
    private void resetAllPreferences() {
        new MaterialAlertDialogBuilder(this)
            .setTitle("🔄 Ayarları Sıfırla")
            .setMessage("Tüm uygulama ayarları sıfırlanacak:\n\n" +
                       "• İzin dialog'ları tekrar gösterilecek\n" +
                       "• Arkaplan yükleme ayarları sıfırlanacak\n\n" +
                       "⚠️ Bu işlem geri alınamaz!\n\n" +
                       "Emin misiniz?")
            .setPositiveButton("✅ Evet, Sıfırla", (dialog, which) -> {
                dialog.dismiss(); // Diyaloğu kapat
                preferences.edit().clear().apply();
                permissionsGranted = false;
                Toast.makeText(this, "🔄 Ayarlar sıfırlandı. Uygulamayı yeniden başlatın.", Toast.LENGTH_LONG).show();
                
                // Uygulamayı yeniden başlat
                Intent intent = getIntent();
                finish();
                startActivity(intent);
            })
            .setNegativeButton("❌ İptal", (dialog, which) -> {
                dialog.dismiss(); // Diyaloğu kapat
            })
            .show();
    }

    private void updateDeviceOwnerDisplay() {
        // Cihaz kimliğini al
        String deviceId = com.envanto.barcode.utils.DeviceIdentifier.getUniqueDeviceId(this);
        
        // Veritabanından cihaz sahibi bilgisini çek
        com.envanto.barcode.database.DatabaseHelper dbHelper = new com.envanto.barcode.database.DatabaseHelper(this);
        String deviceOwner = dbHelper.getCihazSahibi(deviceId);
        
        if (deviceOwner != null && !deviceOwner.trim().isEmpty()) {
            deviceOwnerText.setText("👤 Cihaz Sahibi: " + deviceOwner);
            deviceOwnerText.setVisibility(View.VISIBLE);
        } else {
            deviceOwnerText.setText("👤 Cihaz Sahibi: Belirtilmemiş");
            deviceOwnerText.setVisibility(View.GONE);
        }
    }

    private void showBatteryOptimizationInfo() {
        if (isDialogShowing || preferences.getBoolean(PREF_BATTERY_OPT_INFO_SHOWN, false)) return;

        isDialogShowing = true;
        currentDialog = new MaterialAlertDialogBuilder(this)
            .setTitle("🔋 Pil Optimizasyonu Ayarı")
            .setMessage("Uygulamanın arka planda sorunsuz çalışabilmesi için lütfen şu adımları izleyin:\n\n" +
                        "1. Açılacak ayarlar sayfasında 'Pil' veya 'Batarya' bölümüne gidin\n" +
                        "2. Envanto Barkod uygulamasının pil kullanımı ayarlarını bulun\n" +
                        "3. 'Kısıtlanmamış' veya 'Optimize' seçeneğini belirleyin\n\n" +
                        "Bu ayar, resimlerin arka planda güvenilir şekilde yüklenebilmesi için çok önemlidir.")
            .setPositiveButton("Anladım", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
                preferences.edit().putBoolean(PREF_BATTERY_OPT_INFO_SHOWN, true).apply();
            })
            .setNegativeButton("Ayarlara Git", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
                preferences.edit().putBoolean(PREF_BATTERY_OPT_INFO_SHOWN, true).apply();
                
                // Uygulamanın kendi ayarlar sayfasını aç
                Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                Uri uri = Uri.fromParts("package", getPackageName(), null);
                intent.setData(uri);
                startActivity(intent);
            })
            .setCancelable(false)
            .setOnDismissListener(dialog -> {
                isDialogShowing = false;
                currentDialog = null;
            })
            .show();
    }

    /**
     * Yakında eklenecek özellikler için bilgi diyaloğu gösterir
     */
    private void showComingSoonDialog(String feature) {
        if (isDialogShowing) return;
        
        isDialogShowing = true;
        currentDialog = new MaterialAlertDialogBuilder(this)
            .setTitle(feature)
            .setMessage(getString(R.string.coming_soon))
            .setPositiveButton("Tamam", (dialog, which) -> {
                isDialogShowing = false;
                currentDialog = null;
            })
            .setOnDismissListener(dialog -> {
                isDialogShowing = false;
                currentDialog = null;
            })
            .show();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (loadingDialog != null && loadingDialog.isShowing()) {
            loadingDialog.dismiss();
        }
    }
} 