package com.envanto.barcode.utils;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.envanto.barcode.R;
import com.envanto.barcode.api.ApiClient;
import com.envanto.barcode.api.DeviceAuthResponse;
import com.envanto.barcode.database.DatabaseHelper;
import com.envanto.barcode.utils.AppConstants;
import com.envanto.barcode.utils.DeviceIdentifier;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

/**
 * Cihaz yetkilendirme kontrolü için ortak utility sınıfı
 */
public class DeviceAuthManager {
    private static final String TAG = "DeviceAuthManager";
    
    /**
     * Cihaz yetkilendirme durumları için callback interface
     */
    public interface DeviceAuthCallback {
        void onAuthSuccess();
        void onAuthFailure();
        void onShowLoading();
        void onHideLoading();
    }
    

    
    /**
     * Cihaz yetkilendirme kontrolü yapar
     * 
     * @param activity Context olarak kullanılacak AppCompatActivity
     * @param callback Yetkilendirme durumları için callback
     */
    public static void checkDeviceAuthorization(AppCompatActivity activity, DeviceAuthCallback callback) {
        try {
            // Yükleme ekranını göster
            callback.onShowLoading();
            
            // Cihaz kimliğini al
            String deviceId = DeviceIdentifier.getUniqueDeviceId(activity);
            
            // DatabaseHelper'ı tek kez oluştur
            DatabaseHelper dbHelper = new DatabaseHelper(activity);
            
            android.util.Log.d(TAG, "Cihaz Kimliği: " + deviceId);
            android.util.Log.d(TAG, "Cihaz Bilgileri: " + DeviceIdentifier.getReadableDeviceInfo(activity));
        
        // Sunucudan cihaz yetkilendirme durumunu kontrol et (3 saniyelik timeout ile)
        ApiClient.getInstance().getQuickApiService().checkDeviceAuth("check", deviceId)
            .enqueue(new Callback<DeviceAuthResponse>() {
                @Override
                public void onResponse(Call<DeviceAuthResponse> call, Response<DeviceAuthResponse> response) {
                    // Kısa bir süre bekle
                    new Handler(Looper.getMainLooper()).postDelayed(() -> {
                        callback.onHideLoading();
                    }, AppConstants.Timing.LOADING_DIALOG_DELAY);
                    
                    if (response.isSuccessful() && response.body() != null) {
                        DeviceAuthResponse authResponse = response.body();
                        
                        if (authResponse.isSuccess()) {
                            // Cihaz yetkili, normal kullanıma devam et
                            AppConstants.Prefs.setDeviceAuthChecked(activity, true);
                            
                            // Cihaz sahibini al
                            String serverDeviceOwner = authResponse.getDeviceOwner();
                            
                            // Yerel veritabanına kaydet
                            dbHelper.saveCihazYetki(deviceId, serverDeviceOwner, 1);
                            
                            android.util.Log.d(TAG, "Cihaz yetkili: " + authResponse.getMessage());
                            android.util.Log.d(TAG, "Cihaz sahibi: " + serverDeviceOwner);
                            
                            // Başarı callback'i çağır
                            callback.onAuthSuccess();
                        } else {
                            // Cihaz yetkili değil, uyarı göster
                            AppConstants.Prefs.setDeviceAuthChecked(activity, false);
                            
                            // Yerel veritabanına kaydet (onaysız olarak)
                            dbHelper.saveCihazYetki(deviceId, "", 0);
                            
                            android.util.Log.w(TAG, "Cihaz yetkili değil: " + authResponse.getMessage());
                            
                            // Uyarı diyaloğu göster
                            showAuthorizationErrorDialog(activity, authResponse.getMessage(), deviceId);
                            callback.onAuthFailure();
                        }
                    } else {
                        // Sunucu hatası durumunda yerel veritabanını kontrol et
                        boolean isLocallyAuthorized = dbHelper.isCihazOnaylanmis(deviceId);
                        
                        if (isLocallyAuthorized) {
                            // Yerel veritabanında onaylı olarak kayıtlı
                            android.util.Log.d(TAG, "Sunucu hatası, yerel veritabanında onaylı");
                            callback.onAuthSuccess();
                        } else {
                            // Sunucu hatası ve yerel veritabanında onaylı değil
                            android.util.Log.e(TAG, "Sunucu yanıt hatası: " + 
                                (response.errorBody() != null ? "Hata kodu: " + response.code() : "Bilinmeyen hata"));
                            
                            // Uyarı diyaloğu göster
                            showAuthorizationErrorDialog(activity, "Sunucu ile iletişim kurulamadı. Lütfen daha sonra tekrar deneyin.", deviceId);
                            callback.onAuthFailure();
                        }
                    }
                }
                
                @Override
                public void onFailure(Call<DeviceAuthResponse> call, Throwable t) {
                    callback.onHideLoading();
                    
                    // Ağ hatası durumunda yerel veritabanını kontrol et (3 saniye timeout)
                    android.util.Log.e(TAG, "Cihaz yetkilendirme kontrolü başarısız (3s timeout): " + t.getMessage());
                    
                    boolean isLocallyAuthorized = dbHelper.isCihazOnaylanmis(deviceId);
                    
                    if (isLocallyAuthorized) {
                        // Yerel veritabanında onaylı olarak kayıtlı
                        android.util.Log.d(TAG, "3s timeout sonrası yerel veritabanından onaylı, sessizce devam ediliyor");
                        callback.onAuthSuccess();
                    } else {
                        // Ağ hatası ve yerel veritabanında onaylı değil
                        android.util.Log.e(TAG, "Ağ hatası ve yerel yetki yok: " + t.getMessage());
                        
                        // Uyarı diyaloğu göster
                        showAuthorizationErrorDialog(activity,
                            "Sunucu ile iletişim kurulamadı (3s timeout) ve yerel yetkilendirme bulunamadı. " +
                            "Lütfen internet bağlantınızı kontrol edin ve cihazınızın yetkilendirildiğinden emin olun.", 
                            deviceId);
                        callback.onAuthFailure();
                    }
                }
            });
        } catch (Exception e) {
            android.util.Log.e(TAG, "DeviceAuthManager genel hatası: " + e.getMessage());
            callback.onHideLoading();
            callback.onAuthFailure();
        }
    }
    
    /**
     * Yetkilendirme hatası diyaloğunu gösterir
     * 
     * @param activity Dialog'u gösterecek activity
     * @param message Gösterilecek hata mesajı
     * @param deviceId Cihaz kimliği
     */
    private static void showAuthorizationErrorDialog(AppCompatActivity activity, String message, String deviceId) {
        View dialogView = activity.getLayoutInflater().inflate(R.layout.dialog_device_auth, null);
        TextView deviceIdTextView = dialogView.findViewById(R.id.text_device_id);
        deviceIdTextView.setText(deviceId);
        
        MaterialAlertDialogBuilder builder = new MaterialAlertDialogBuilder(activity)
            .setTitle("Yetkilendirme Hatası")
            .setMessage(message)
            .setView(dialogView)
            .setPositiveButton("Cihaz ID Kopyala", (dialog, which) -> {
                // Cihaz kimliğini panoya kopyala
                ClipboardManager clipboard = (ClipboardManager) activity.getSystemService(Context.CLIPBOARD_SERVICE);
                ClipData clip = ClipData.newPlainText("Cihaz Kimliği", deviceId);
                clipboard.setPrimaryClip(clip);
                Toast.makeText(activity, "Cihaz kimliği kopyalandı", Toast.LENGTH_SHORT).show();
                activity.finish(); // Aktiviteyi kapat
            })
            .setNegativeButton("Kapat", (dialog, which) -> {
                activity.finish(); // Aktiviteyi kapat
            })
            .setCancelable(false);
        
        builder.show();
    }
} 