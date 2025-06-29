package com.envanto.barcode.service;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.database.Cursor;
import android.os.Build;
import android.os.IBinder;
import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import com.envanto.barcode.MainActivity;
import com.envanto.barcode.R;
import com.envanto.barcode.api.ApiClient;
import com.envanto.barcode.api.UploadResponse;
import com.envanto.barcode.database.DatabaseHelper;
import com.envanto.barcode.utils.ImageStorageManager;
import com.envanto.barcode.utils.NetworkUtils;
import com.envanto.barcode.utils.AppConstants;
import java.io.File;
import java.io.IOException;
import okhttp3.MediaType;
import okhttp3.MultipartBody;
import okhttp3.RequestBody;
import retrofit2.Call;
import retrofit2.Response;
import android.util.Log;
import android.net.Uri;

public class UploadRetryService extends Service {
    private static final String TAG = "UploadRetryService";
    private static final String CHANNEL_ID = "upload_service_channel";
    private static final int NOTIFICATION_ID = 1001;
    
    public static final String EXTRA_WIFI_ONLY = "wifi_only";
    
    private boolean isRunning = false;
    private Thread uploadThread;
    private boolean wifiOnly = true; // Varsayılan olarak WiFi-only
    private NotificationManager notificationManager;

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
        notificationManager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // SharedPreferences'tan servis konfigürasyon durumunu kontrol et
        android.content.SharedPreferences preferences = getSharedPreferences("envanto_barcode_prefs", MODE_PRIVATE);
        boolean serviceConfigured = preferences.getBoolean("service_configured", false);
        
        // Eğer servis konfigüre edilmemişse, hiçbir şey yapma
        if (!serviceConfigured) {
            Log.d(TAG, "UploadRetryService başlatılmadı - Servis konfigüre edilmemiş");
            return START_NOT_STICKY;
        }
        
        // WiFi-only ayarını al
        if (intent != null && intent.hasExtra(EXTRA_WIFI_ONLY)) {
            wifiOnly = intent.getBooleanExtra(EXTRA_WIFI_ONLY, true);
        } else {
            // Eğer intent'ten parametre gelmemişse, SharedPreferences'tan oku
            wifiOnly = preferences.getBoolean("wifi_only", true);
        }
        
        Log.d(TAG, "UploadRetryService başlatıldı - WiFi only: " + wifiOnly);
        
        if (!isRunning) {
            isRunning = true;
            
            // Yüklenecek resim olup olmadığını kontrol et
            DatabaseHelper dbHelper = new DatabaseHelper(this);
            Cursor cursor = dbHelper.getNotUploadedRecords();
            boolean hasImagesToUpload = cursor != null && cursor.getCount() > 0;
            int pendingCount = 0;
            
            if (cursor != null) {
                pendingCount = cursor.getCount();
                cursor.close();
            }
            
            // Sadece yüklenecek resim varsa veya servis konfigüre edilmemişse bildirim göster
            if (hasImagesToUpload || !serviceConfigured) {
                startForeground(NOTIFICATION_ID, createNotification(0, pendingCount));
            } else {
                // Android 8.0+ için foreground servis başlatmak zorunlu, ama hemen bildirim kaldırılabilir
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForeground(NOTIFICATION_ID, createNotification(0, 0));
                    notificationManager.cancel(NOTIFICATION_ID);
                }
            }
            
            // Yükleme thread'ini başlat
            startUploadRetry();
        }
        return START_STICKY;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Resim Yükleme Servisi",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Resimleri arkaplanda sunucuya yükler");
            channel.setShowBadge(false);
            
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    private Notification createNotification(int uploaded, int total) {
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent, 
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0
        );

        // SharedPreferences'tan servis konfigürasyon durumunu kontrol et
        android.content.SharedPreferences preferences = getSharedPreferences("envanto_barcode_prefs", MODE_PRIVATE);
        boolean serviceConfigured = preferences.getBoolean("service_configured", false);

        String contentText;
        String contentTitle = "Envanto Barkod - Arkaplan Yükleme";
        
        if (!serviceConfigured) {
            contentText = "Bağlantı türü ayarlanmadı. Lütfen ayarları yapılandırın.";
            contentTitle = "Envanto Barkod - Ayarlar Gerekli";
        } else if (total > 0) {
            if (uploaded > 0) {
                // Aktif yükleme durumu - percentage hesaplamasını daha doğru yap
                int percentage = (int)Math.round(((double)uploaded / total) * 100);
                contentText = String.format("Yükleniyor: %d/%d resim (%d%%)", 
                    uploaded, total, percentage);
            } else {
                // Bağlantı durumuna göre bilgi ver
                boolean isWifiAvailable = NetworkUtils.isWifiConnected(this);
                boolean isNetworkAvailable = NetworkUtils.isNetworkAvailable(this);
                
                if (!isNetworkAvailable) {
                    // Hiç internet yok
                    contentText = String.format("⚠️ İnternet bağlantısı bekleniyor... (%d resim bekliyor)", total);
                } else if (wifiOnly && !isWifiAvailable) {
                    // WiFi-only seçili ama WiFi yok
                    contentText = String.format("📶 WiFi bağlantısı bekleniyor... (%d resim bekliyor)", total);
                } else {
                    // Yükleme yapılabilir durumda
                    contentText = String.format("🔄 Yükleme hazırlanıyor... (%d resim)", total);
                }
            }
        } else {
            // Bu duruma hiç gelmemeli, çünkü resim yoksa bildirim kaldırılıyor
            contentText = "Yüklenecek resim bulunmuyor";
        }

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setSmallIcon(R.drawable.ic_upload)
            .setContentIntent(pendingIntent)
            .setSilent(true);
            
        // Sadece aktif yükleme sırasında ongoing yap, diğer durumlarda kapatılabilir olsun
        if (total > 0 && uploaded >= 0 && uploaded < total) {
            // Aktif yükleme durumunda kalıcı bildirim
            builder.setOngoing(true);
        } else {
            // Diğer durumlarda (bekleme, hata, vs.) kapatılabilir bildirim
            builder.setOngoing(false);
        }
        
        return builder.build();
    }

    private void startUploadRetry() {
        uploadThread = new Thread(() -> {
            while (isRunning) {
                try {
                    // SharedPreferences'tan servis konfigürasyon durumunu kontrol et
                    android.content.SharedPreferences preferences = getSharedPreferences("envanto_barcode_prefs", MODE_PRIVATE);
                    boolean serviceConfigured = preferences.getBoolean("service_configured", false);
                    
                    // Eğer servis konfigüre edilmemişse, yükleme yapma
                    if (!serviceConfigured) {
                        // Notification'ı güncelle
                        updateNotification(0, 0);
                        Thread.sleep(AppConstants.Service.UPLOAD_SERVICE_INTERVAL);
                        continue;
                    }
                    
                    boolean hasConnection = wifiOnly ? 
                        NetworkUtils.isWifiConnected(this) : 
                        NetworkUtils.isNetworkAvailable(this);
                        
                    // Yüklenmemiş dosyaları kontrol et
                        DatabaseHelper dbHelper = new DatabaseHelper(this);
                    Cursor cursor = dbHelper.getNotUploadedRecords();
                    
                    // Yüklenecek resim var mı kontrol et
                    boolean hasImagesToUpload = cursor != null && cursor.getCount() > 0;
                    
                    if (!hasImagesToUpload) {
                        // Yüklenecek resim yoksa bildirimi kaldır
                        if (notificationManager != null) {
                            notificationManager.cancel(NOTIFICATION_ID);
                        }
                        
                        // Servis çalışma aralığı kadar bekle ve tekrar kontrol et
                        Thread.sleep(AppConstants.Service.UPLOAD_SERVICE_INTERVAL);
                        continue;
                    }
                    
                    // Yüklenecek resim var, bildirimi göster
                    updateNotification(0, cursor.getCount());
                    
                    if (hasConnection && hasImagesToUpload) {
                        // Resim yükleme öncesi kritik güvenlik kontrolü
                        if (!checkDeviceAuthorizationBeforeUpload()) {
                            Log.w(TAG, "Cihaz yetkilendirmesi olmadığı için yükleme durduruluyor");
                            
                            // Yetkilendirme yoksa tüm bekleyen yüklemeleri temizle
                            dbHelper.clearAllPendingUploads();
                            
                            // Bildirim kaldır
                            if (notificationManager != null) {
                                notificationManager.cancel(NOTIFICATION_ID);
                            }
                            
                            // Servis çalışma aralığı kadar bekle
                            Thread.sleep(AppConstants.Service.UPLOAD_SERVICE_INTERVAL);
                            continue;  
                        }
                        
                        // Önce kayıp dosyaları temizle
                        dbHelper.cleanupMissingFiles();
                        
                        // Eski yüklenmiş kayıtları temizle
                        dbHelper.cleanupOldUploadedRecords();
                        
                        // Cursor'ı başa al
                        cursor.moveToFirst();
                        
                            int totalCount = cursor.getCount();
                            int uploadedCount = 0;
                            
                            Log.d(TAG, "Yüklenecek " + totalCount + " resim bulundu");
                            
                            do {
                                try {
                                    int musteriAdiIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_MUSTERI_ADI);
                                    int resimYoluIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_RESIM_YOLU);
                                    int yukleyenIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_YUKLEYEN);

                                    if (musteriAdiIndex < 0 || resimYoluIndex < 0 || yukleyenIndex < 0) {
                                        continue;
                                    }

                                    String musteriAdi = cursor.getString(musteriAdiIndex);
                                    String resimYolu = cursor.getString(resimYoluIndex);
                                    String yukleyen = cursor.getString(yukleyenIndex);

                                    // Yükleme başlamadan önce durumu göster
                                    updateNotification(uploadedCount, totalCount);

                                    // Yükleme işlemini yap
                                    if (uploadImageToServer(musteriAdi, resimYolu, yukleyen)) {
                                        // Yükleme başarılı
                                        Log.d(TAG, "Resim sunucuya yüklendi: " + resimYolu);
                                        
                                        // Yerel dosyayı sil
                                        ImageStorageManager.deleteImage(this, resimYolu);
                                        
                                        // Veritabanı kaydını güncelle (silme)
                                        dbHelper.updateUploadStatus(resimYolu, true);
                                        
                                        uploadedCount++;
                                        
                                        // Yükleme başarılı olduktan sonra notification'ı güncelle
                                        updateNotification(uploadedCount, totalCount);
                                    }
                                } catch (Exception e) {
                                    Log.e(TAG, "Yükleme hatası: " + e.getMessage());
                                }
                            } while (cursor.moveToNext() && isRunning);
                            
                            if (uploadedCount > 0) {
                                Log.d(TAG, uploadedCount + " resim başarıyla yüklendi");
                                // Yükleme tamamlandı, final durumu göster
                                updateNotification(uploadedCount, totalCount);
                            }
                        
                        // Yükleme tamamlandıktan sonra kalan resim sayısını kontrol et
                        Cursor remainingCursor = dbHelper.getNotUploadedRecords();
                        if (remainingCursor != null) {
                            int remainingCount = remainingCursor.getCount();
                            if (remainingCount > 0) {
                                // Hala yüklenecek resim var
                                updateNotification(0, remainingCount);
                            } else if (uploadedCount > 0) {
                                // Tüm resimler yüklendi, kısa süre "Tamamlandı" mesajı göster
                                if (notificationManager != null) {
                                    NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                                        .setContentTitle("Envanto Barkod - Yükleme Tamamlandı")
                                        .setContentText(String.format("✅ %d resim başarıyla yüklendi", uploadedCount))
                                        .setSmallIcon(R.drawable.ic_upload)
                                        .setOngoing(false) // Tamamlandı bildirimi kapatılabilir olsun
                                        .setSilent(true);
                                    
                                    notificationManager.notify(NOTIFICATION_ID, builder.build());
                                    
                                    // 10 saniye bekle ve bildirimi kaldır
                                    new Thread(() -> {
                                        try {
                                            Thread.sleep(AppConstants.Timing.NOTIFICATION_DISPLAY_DURATION);
                                            if (notificationManager != null) {
                                                notificationManager.cancel(NOTIFICATION_ID);
                                            }
                                        } catch (InterruptedException e) {
                                            // Sessizce devam et
                                        }
                                    }).start();
                                }
                            } else {
                                // Hiç yükleme yapılmadı, bildirimi kaldır
                                if (notificationManager != null) {
                                    notificationManager.cancel(NOTIFICATION_ID);
                                }
                            }
                            remainingCursor.close();
                        }
                    } else {
                        // Bağlantı yok ama yüklenecek resim var - uygun bildirimi göster
                        updateNotification(0, cursor.getCount());
                    }
                    
                    // Cursor'ı kapat
                    if (cursor != null) {
                        cursor.close();
                    }
                    
                    // Servis çalışma aralığı kadar bekle
                    Thread.sleep(AppConstants.Service.UPLOAD_SERVICE_INTERVAL);
                } catch (InterruptedException e) {
                    break;
                } catch (Exception e) {
                    Log.e(TAG, "Servis hatası: " + e.getMessage());
                    try {
                        Thread.sleep(AppConstants.Service.UPLOAD_SERVICE_INTERVAL); // Hata durumunda da bekle
                    } catch (InterruptedException ie) {
                        break;
                    }
                }
            }
        });
        
        uploadThread.start();
    }

    private boolean uploadImageToServer(String musteriAdi, String resimYolu, String yukleyen) {
        try {
            // File path kontrol et
            File file = new File(resimYolu);
            if (!file.exists()) {
                Log.w(TAG, "Dosya bulunamadı: " + resimYolu);
                return false;
            }

            // Dosya adını al
            String fileName = file.getName();
            
            // Multipart form data oluştur
            RequestBody actionBody = RequestBody.create(MediaType.parse("text/plain; charset=utf-8"), "upload_file");
            
            // Önce encoding yapmadan dene
            Log.d(TAG, "=== ENCODING TEST (Service) ===");
            Log.d(TAG, "Original müşteri adı: " + musteriAdi);
            Log.d(TAG, "Original yukleyen: " + yukleyen);
            
            // Byte array'leri kontrol et
            byte[] musteriBytes = musteriAdi.getBytes(java.nio.charset.StandardCharsets.UTF_8);
            byte[] yukleyenBytes = yukleyen.getBytes(java.nio.charset.StandardCharsets.UTF_8);
            
            Log.d(TAG, "Müşteri adı UTF-8 bytes: " + java.util.Arrays.toString(musteriBytes));
            Log.d(TAG, "Yükleyen UTF-8 bytes: " + java.util.Arrays.toString(yukleyenBytes));
            
            // Hiç encoding yapmadan gönder
            RequestBody musteriAdiBody = RequestBody.create(MediaType.parse("text/plain; charset=utf-8"), musteriAdi);
            RequestBody yukleyenBody = RequestBody.create(MediaType.parse("text/plain; charset=utf-8"), yukleyen);
            
            Log.d(TAG, "=== SENDING WITHOUT ENCODING (Service) ===");
            
            RequestBody fileBody = RequestBody.create(MediaType.parse("image/*"), file);
            MultipartBody.Part filePart = MultipartBody.Part.createFormData("resim", fileName, fileBody);
            
            // API çağrısı
            Call<UploadResponse> call = ApiClient.getInstance().getApiService().uploadImageFile(
                actionBody, musteriAdiBody, yukleyenBody, filePart
            );
            
            Response<UploadResponse> response = call.execute();
            
            Log.d(TAG, "API Response Code: " + response.code());
            Log.d(TAG, "API Response Success: " + response.isSuccessful());
            
            // Raw response body'yi log'la
            if (response.body() != null) {
                Log.d(TAG, "Response Body: " + response.body().toString());
            }
            
            if (response.errorBody() != null) {
                String errorBody = response.errorBody().string();
                Log.e(TAG, "Error Body: " + errorBody);
                
                // Eğer server'dan HTML hata sayfası geliyorsa
                if (errorBody.contains("<html>") || errorBody.contains("<!DOCTYPE")) {
                    Log.e(TAG, "Server HTML hata sayfası döndü - muhtemelen component hatası");
                    return false;
                }
            }
            
            // Başarı durumunu kontrol et
            if (response.isSuccessful() && response.body() != null && response.body().isSuccess()) {
                // Yükleme başarılı
                Log.d(TAG, "Resim başarıyla yüklendi: " + resimYolu);
                return true;
            }
            
            Log.e(TAG, "Upload response unsuccessful: " + response.code());
            return false;
        } catch (com.google.gson.JsonSyntaxException e) {
            Log.e(TAG, "JSON Parse Error - Server muhtemelen HTML response döndü: " + e.getMessage());
            return false;
        } catch (Exception e) {
            Log.e(TAG, "Upload error: " + e.getMessage());
            return false;
        }
    }

    private void updateNotification(int uploaded, int total) {
        if (notificationManager != null) {
            Notification notification = createNotification(uploaded, total);
            notificationManager.notify(NOTIFICATION_ID, notification);
        }
    }
    
    /**
     * Resim yükleme öncesi cihaz yetkilendirmesini kontrol eder
     * @return Cihaz yetkili ise true, değilse false
     */
    private boolean checkDeviceAuthorizationBeforeUpload() {
        try {
            // Cihaz kimliğini al
            String deviceId = com.envanto.barcode.utils.DeviceIdentifier.getUniqueDeviceId(this);
            
            Log.d(TAG, "Yükleme öncesi yetkilendirme kontrolü başlıyor: " + deviceId);
            
            // Önce yerel veritabanından kontrol et
            DatabaseHelper dbHelper = new DatabaseHelper(this);
            boolean isLocallyAuthorized = dbHelper.isCihazOnaylanmis(deviceId);
            
            if (!isLocallyAuthorized) {
                Log.w(TAG, "Yerel veritabanında yetkilendirme bulunamadı");
                return false;
            }
            
            // İnternet bağlantısı varsa sunucudan da kontrol et
            if (NetworkUtils.isNetworkAvailable(this)) {
                try {
                    Log.d(TAG, "İnternet var, sunucudan yetkilendirme kontrol ediliyor (3s timeout)");
                    
                    // Hızlı API ile kontrol et (3 saniye timeout)
                    retrofit2.Call<com.envanto.barcode.api.DeviceAuthResponse> call = 
                        com.envanto.barcode.api.ApiClient.getInstance().getQuickApiService()
                        .checkDeviceAuth("check", deviceId);
                    
                    retrofit2.Response<com.envanto.barcode.api.DeviceAuthResponse> response = call.execute();
                    
                    if (response.isSuccessful() && response.body() != null) {
                        com.envanto.barcode.api.DeviceAuthResponse authResponse = response.body();
                        
                        if (authResponse.isSuccess()) {
                            Log.d(TAG, "Sunucu yetkilendirme kontrolü başarılı");
                            return true;
                        } else {
                            Log.w(TAG, "Sunucu yetkilendirme kontrolü başarısız: " + authResponse.getMessage());
                            
                            // Sunucuda yetki yok, yerel veritabanından da temizle
                            dbHelper.clearDeviceAuth(deviceId);
                            return false;
                        }
                    } else {
                        Log.w(TAG, "Sunucu yetkilendirme API çağrısı başarısız: " + response.code());
                        // Sunucuya erişemiyorsa yerel yetkilendirme ile devam et
                        return true;
                    }
                } catch (Exception e) {
                    Log.w(TAG, "Sunucu yetkilendirme kontrolü hatası (timeout olabilir): " + e.getMessage());
                    // Sunucuya erişemiyorsa yerel yetkilendirme ile devam et
                    return true;
                }
            } else {
                Log.d(TAG, "İnternet yok, yerel yetkilendirme ile devam ediliyor");
                // İnternet yoksa yerel yetkilendirme ile devam et
                return true;
            }
        } catch (Exception e) {
            Log.e(TAG, "Yetkilendirme kontrolü sırasında beklenmeyen hata: " + e.getMessage());
            return false;
        }
    }

    @Override
    public void onDestroy() {
        isRunning = false;
        if (uploadThread != null) {
            uploadThread.interrupt();
            try {
                uploadThread.join(AppConstants.Network.THREAD_JOIN_TIMEOUT);
            } catch (InterruptedException e) {
                // Sessizce devam et
            }
        }
        super.onDestroy();
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
} 