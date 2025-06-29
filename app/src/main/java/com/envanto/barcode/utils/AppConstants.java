package com.envanto.barcode.utils;

import android.content.Context;
import android.content.SharedPreferences;
import com.envanto.barcode.BuildConfig;

/**
 * Uygulama genelinde kullanılan sabit değerleri içeren sınıf.
 * Bu sınıf, kodun farklı yerlerinde kullanılan yapılandırma değerlerini merkezi bir yerde toplar.
 */
public class AppConstants {
    // Veritabanı ile ilgili sabitler
    public static final class Database {
        // Yüklenmiş kayıtların silinme süresi (milisaniye cinsinden)
        public static final long UPLOADED_RECORDS_RETENTION_TIME = BuildConfig.UPLOADED_RECORDS_RETENTION_TIME;
    }
    
    // Servis ile ilgili sabitler
    public static final class Service {
        // Yükleme servisinin çalışma aralığı (milisaniye cinsinden)
        public static final long UPLOAD_SERVICE_INTERVAL = BuildConfig.UPLOAD_SERVICE_INTERVAL;
    }
    
    // Uygulama ile ilgili sabitler
    public static final class App {
        // Otomatik yenileme aralığı (milisaniye cinsinden)
        public static final int AUTO_REFRESH_INTERVAL = BuildConfig.AUTO_REFRESH_INTERVAL;
        
        // APK güncelleme kontrol aralığı (milisaniye cinsinden)
        public static final long UPDATE_CHECK_INTERVAL = BuildConfig.UPDATE_CHECK_INTERVAL;
        
        // Müşteri listesi önbellek güncelleme aralığı (6 saat - milisaniye cinsinden)
        public static final long CUSTOMER_CACHE_UPDATE_INTERVAL = BuildConfig.CUSTOMER_CACHE_UPDATE_INTERVAL;
        
        // Kullanıcı oturum süresi (milisaniye cinsinden)
        public static final long SESSION_DURATION = BuildConfig.SESSION_DURATION;
        
    }
    
    // API ile ilgili sabitler
    public static final class Api {
        // API temel URL'i
        public static final String BASE_URL = BuildConfig.API_BASE_URL;
        
        // APK güncelleme indirme temel URL'i
        public static final String APK_DOWNLOAD_BASE_URL = BuildConfig.APK_DOWNLOAD_BASE_URL;
        
        // Varsayılan barkod URL'i
        public static final String DEFAULT_BARCODE_URL_BASE = BuildConfig.DEFAULT_BARCODE_URL_BASE;
        
        // Tam güncelleme kontrol URL'i
        public static final String UPDATE_CHECK_URL = BuildConfig.UPDATE_CHECK_URL;
    }
    
    // UI ve UX ile ilgili süre sabitleri
    public static final class Timing {
        // Yükleme dialog gecikmesi (ms) - Kullanıcı deneyimi için kısa gecikme
        public static final int LOADING_DIALOG_DELAY = BuildConfig.LOADING_DIALOG_DELAY;
        
        // Kısa gecikme süresi (ms) - Genel amaçlı kısa bekleme
        public static final int SHORT_DELAY = BuildConfig.SHORT_DELAY;
        
        // Orta gecikme süresi (ms) - Kullanıcı algısı için orta bekleme
        public static final int MEDIUM_DELAY = BuildConfig.MEDIUM_DELAY;
        
        // Bildirim gösterim süresi (ms) - Başarı mesajlarının görüntülenmesi
        public static final int NOTIFICATION_DISPLAY_DURATION = BuildConfig.NOTIFICATION_DISPLAY_DURATION;
    }
    
    // Kamera ve tarama ile ilgili süre sabitleri
    public static final class Camera {
        // Otomatik fokus aralığı (ms) - Kamera sürekli odaklama
        public static final long AUTO_FOCUS_INTERVAL = BuildConfig.AUTO_FOCUS_INTERVAL;
        
        // Tarama animasyon süresi (ms) - Barkod tanıma animasyonu
        public static final int SCAN_ANIMATION_DURATION = BuildConfig.SCAN_ANIMATION_DURATION;
    }
    
    // Network ve API timeout'ları
    public static final class Network {
        // Hızlı API işlemler için timeout (ms) - Cihaz yetkilendirme gibi
        public static final int QUICK_API_TIMEOUT = BuildConfig.QUICK_API_TIMEOUT;
        
        // Thread join timeout (ms) - Thread sonlandırma beklemesi
        public static final int THREAD_JOIN_TIMEOUT = BuildConfig.THREAD_JOIN_TIMEOUT;
    }
    
    // Shared Preferences ile ilgili sabitler
    public static final class Prefs {
        public static final String PREF_NAME = "envanto_barcode_prefs";
        public static final String DEVICE_AUTH_CHECKED = "device_auth_checked";
        public static final String LAST_CUSTOMER_CACHE_UPDATE = "last_customer_cache_update";
        
        // Yardımcı metotlar
        public static SharedPreferences getPrefs(Context context) {
            return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        }
        
        public static boolean isDeviceAuthChecked(Context context) {
            return getPrefs(context).getBoolean(DEVICE_AUTH_CHECKED, false);
        }
        
        public static void setDeviceAuthChecked(Context context, boolean checked) {
            getPrefs(context).edit().putBoolean(DEVICE_AUTH_CHECKED, checked).apply();
        }
    }
} 