package com.envanto.barcode;

import android.Manifest;
import android.animation.ObjectAnimator;
import android.animation.ValueAnimator;
import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.util.Log;
import android.util.Size;
import android.view.Menu;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.WindowInsetsController;
import android.widget.ImageButton;
import android.widget.ToggleButton;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.browser.customtabs.CustomTabsIntent;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraControl;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.FocusMeteringAction;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.MeteringPoint;
import androidx.camera.core.MeteringPointFactory;
import androidx.camera.core.Preview;
import androidx.camera.core.SurfaceOrientedMeteringPointFactory;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import com.google.common.util.concurrent.ListenableFuture;
import com.google.mlkit.vision.barcode.BarcodeScanner;
import com.google.mlkit.vision.barcode.BarcodeScannerOptions;
import com.google.mlkit.vision.barcode.BarcodeScanning;
import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.common.InputImage;
import com.envanto.barcode.utils.AppConstants;

import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.List;
import java.util.ArrayList;

/**
 * Envanto Barkod Tarayıcı
 * 
 * QR kod ve DataMatrix barkodları taramak için CameraX ve ML Kit kullanan aktivite.
 * Taranan barkod içeriğini bir web sayfasına yönlendirir.
 */
public class ScannerActivity extends AppCompatActivity {

    // -------------------- Sabitler --------------------
    private static final String TAG = "ScannerActivity";
    private static final int CAMERA_PERMISSION_REQUEST = 100;
    private static final long AUTO_FOCUS_INTERVAL = AppConstants.Camera.AUTO_FOCUS_INTERVAL; // Otomatik fokus aralığı
    private static final String PREFS_NAME = "EnvantoBarcodePrefs";
    private static final String KEY_URL_BASE = "url_base";
    
    // -------------------- UI Bileşenleri --------------------
    private PreviewView previewView;
    private ToggleButton switchFlashlightButton;
    private View scannerLine;
    
    // -------------------- Kamera Bileşenleri --------------------
    private Camera camera;
    private ExecutorService cameraExecutor;
    private boolean isFlashOn = false;
    
    // -------------------- Gelişmiş Odaklama Sistemi --------------------
    private ScheduledExecutorService autoFocusExecutor;
    private ScheduledFuture<?> autoFocusTask;
    private boolean isAutoFocusEnabled = true;
    private long optimalFocusInterval;
    private int currentFocusZone = 0; // Multi-zone focus için
    
    // -------------------- Barkod Tarama Bileşenleri --------------------
    private BarcodeScanner barcodeScanner;
    private boolean isScanning = true; // Tekrarlayan taramayı önlemek için
    
    // -------------------- Geri Bildirim Bileşenleri --------------------
    private MediaPlayer mediaPlayer;
    private Vibrator vibrator;
    
    // -------------------- İzin İsteme Launcher --------------------
    private ActivityResultLauncher<String> requestPermissionLauncher;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            setupWindow();
            
            // Status bar ve navigation bar ayarları için modern API kullan
            Window window = getWindow();
            WindowCompat.setDecorFitsSystemWindows(window, false);
            WindowInsetsControllerCompat controller = new WindowInsetsControllerCompat(window, window.getDecorView());
            
            // Status bar ve navigation bar'ı şeffaf yap
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);
            
            // Status bar ikonlarını koyu yap
            controller.setAppearanceLightStatusBars(true);
            controller.setAppearanceLightNavigationBars(true);
            
            setContentView(R.layout.activity_scanner);
            
            // Action Bar'ı gizle
            if (getSupportActionBar() != null) {
                getSupportActionBar().hide();
            }
            
            // İzin isteme launcher'ını başlat
            setupPermissionLauncher();
            
            initViews();
            initFeedbackComponents();
            initBarcodeScannerOptions();
            
            // Kamera izinlerini kontrol et
            checkCameraPermission();
            
            // CameraX ve AutoFocus için executor'ları oluştur
            if (cameraExecutor == null) {
                cameraExecutor = Executors.newSingleThreadExecutor();
            }
            if (autoFocusExecutor == null) {
                autoFocusExecutor = Executors.newSingleThreadScheduledExecutor();
            }
            
            // Cihaza uygun odaklama parametrelerini hesapla
            optimalFocusInterval = calculateOptimalFocusInterval();
        } catch (Exception e) {
            Log.e(TAG, "onCreate hatası: " + e.getMessage());
            Toast.makeText(this, "Uygulama başlatılamadı: " + e.getMessage(), Toast.LENGTH_LONG).show();
            finish();
        }
    }
    
    /**
     * İzin isteme launcher'ını başlatır
     */
    private void setupPermissionLauncher() {
        requestPermissionLauncher = registerForActivityResult(
            new ActivityResultContracts.RequestPermission(),
            isGranted -> {
                if (isGranted) {
                    startCamera();
                } else {
                    Toast.makeText(this, R.string.no_camera_permission, Toast.LENGTH_LONG).show();
                    finish();
                }
            }
        );
    }
    
    /**
     * Pencere parametrelerini ayarlar
     */
    private void setupWindow() {
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setTurnScreenOn(true);
            setShowWhenLocked(true);
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        } else {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                    | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED);
        }
    }
    
    /**
     * UI bileşenlerini başlatır
     */
    private void initViews() {
        try {
            previewView = findViewById(R.id.preview_view);
            switchFlashlightButton = findViewById(R.id.switch_flashlight);
            scannerLine = findViewById(R.id.scanner_line);
            
            // Flash butonu başlangıçta kapalı (false) durumda
            switchFlashlightButton.setChecked(false);
            
            // Flash butonuna hızlı yanıt veren tıklama eylemini ekle
            switchFlashlightButton.setOnCheckedChangeListener((buttonView, isChecked) -> {
                // Anlık UI geri bildirimi için hemen tepki ver
                Log.d(TAG, "Flash button tıklandı: " + (isChecked ? "AÇILIYOR" : "KAPANIYOR"));
                
                // Flash toggle işlemini hemen başlat
                toggleFlash(isChecked);
            });
            
            // Home butonuna tıklama eylemini ekle
            ImageButton homeButton = findViewById(R.id.home_button);
            homeButton.setOnClickListener(v -> {
                // Ana sayfaya dön
                Intent intent = new Intent(this, MainActivity.class);
                intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                startActivity(intent);
                finish();
            });
            
            // Ayarlar butonuna tıklama eylemini ekle
            View settingsButton = findViewById(R.id.settings_button);
            if (settingsButton != null) {
                settingsButton.setOnClickListener(v -> {
                    try {
                        // Ayarlar aktivitesine git
                        Intent intent = new Intent(this, SettingsActivity.class);
                        startActivity(intent);
                    } catch (Exception e) {
                        Log.e(TAG, "Ayarlar açılırken hata: " + e.getMessage());
                        Toast.makeText(this, "Ayarlar açılamadı: " + e.getMessage(), Toast.LENGTH_SHORT).show();
                    }
                });
            }
            
            // Tarama çizgisi animasyonunu başlat
            startScannerAnimation();
        } catch (Exception e) {
            Log.e(TAG, "initViews hatası: " + e.getMessage());
            Toast.makeText(this, "UI başlatılamadı: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }
    
    /**
     * Ses ve titreşim geri bildirim bileşenlerini başlatır
     */
    private void initFeedbackComponents() {
        // Titreşim servisini başlat
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+ için VibratorManager kullan
            VibratorManager vibratorManager = (VibratorManager) getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
            vibrator = vibratorManager.getDefaultVibrator();
        } else {
            // Android 12 öncesi için direkt Vibrator servisini kullan
            vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
        }
        
        // Bip sesi için MediaPlayer'ı başlat
        try {
            mediaPlayer = MediaPlayer.create(this, R.raw.beep);
        } catch (Exception e) {
            mediaPlayer = null;
            Log.e(TAG, "MediaPlayer başlatılamadı: " + e.getMessage());
        }
    }
    
    /**
     * ML Kit barkod tarayıcı seçeneklerini ayarlar (Performans için optimize)
     */
    private void initBarcodeScannerOptions() {
        try {
            // Sadece gerekli formatlar - daha hızlı işlem
            BarcodeScannerOptions options = new BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(
                        Barcode.FORMAT_QR_CODE,
                        Barcode.FORMAT_DATA_MATRIX)
                    .enableAllPotentialBarcodes() // Tüm potansiyel barkodları tespit et - hız için
                    .build();
            
            barcodeScanner = BarcodeScanning.getClient(options);
            
            // Performans için optimize edilmiş thread pool
            if (cameraExecutor == null) {
                cameraExecutor = Executors.newSingleThreadExecutor(r -> {
                    Thread t = new Thread(r);
                    t.setName("BarcodeAnalysis");
                    t.setPriority(Thread.MAX_PRIORITY); // En yüksek öncelik
                    return t;
                });
            }
            
            Log.d(TAG, "Performans odaklı barkod tarayıcı yapılandırıldı");
        } catch (Exception e) {
            Log.e(TAG, "Barkod tarayıcı yapılandırma hatası: " + e.getMessage(), e);
            Toast.makeText(this, "Barkod tarayıcı başlatılamadı: " + e.getMessage(), 
                    Toast.LENGTH_LONG).show();
        }
    }
    
    /**
     * Kamera izinlerini kontrol eder
     */
    private void checkCameraPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED) {
            // ActivityResultLauncher kullanarak modern izin isteği
            requestPermissionLauncher.launch(Manifest.permission.CAMERA);
        } else {
            startCamera();
        }
    }
    
    /**
     * Tarama çizgisi animasyonunu oluşturur ve başlatır
     */
    private void startScannerAnimation() {
        ObjectAnimator animator = ObjectAnimator.ofFloat(
                scannerLine, 
                "translationY", 
                -100f, 100f);
        
                    animator.setDuration(AppConstants.Camera.SCAN_ANIMATION_DURATION);
        animator.setRepeatCount(ValueAnimator.INFINITE);
        animator.setRepeatMode(ValueAnimator.REVERSE);
        animator.start();
    }
    
    /**
     * Kamera ve tarama işlemini başlatır
     */
    private void startCamera() {
        try {
            ListenableFuture<ProcessCameraProvider> cameraProviderFuture = 
                    ProcessCameraProvider.getInstance(this);
                    
            cameraProviderFuture.addListener(() -> {
                try {
                    ProcessCameraProvider cameraProvider = cameraProviderFuture.get();
                    bindCameraUseCases(cameraProvider);
                } catch (ExecutionException | InterruptedException e) {
                    Log.e(TAG, "Kamera başlatma hatası: " + e.getMessage(), e);
                    Toast.makeText(this, "Kamera başlatılamadı: " + e.getMessage(), 
                            Toast.LENGTH_LONG).show();
                } catch (Exception e) {
                    Log.e(TAG, "Beklenmeyen kamera hatası: " + e.getMessage(), e);
                    Toast.makeText(this, "Kamera başlatılamadı: Beklenmeyen hata", 
                            Toast.LENGTH_LONG).show();
                }
            }, ContextCompat.getMainExecutor(this));
        } catch (Exception e) {
            Log.e(TAG, "Kamera sağlayıcı başlatma hatası: " + e.getMessage(), e);
            Toast.makeText(this, "Kamera sistemi başlatılamadı: " + e.getMessage(), 
                    Toast.LENGTH_LONG).show();
        }
    }
    
    /**
     * Kamera kullanım senaryolarını bağlar
     */
    private void bindCameraUseCases(ProcessCameraProvider cameraProvider) {
        try {
            // Kamera yapılandırması
            CameraSelector cameraSelector = new CameraSelector.Builder()
                    .requireLensFacing(CameraSelector.LENS_FACING_BACK)
                    .build();
            
            // Barkod tarama için optimize edilmiş çözünürlük - cihaz uyumlu
            Preview preview = new Preview.Builder()
                    .setTargetResolution(new Size(720, 1280))
                    .build();
                    
            preview.setSurfaceProvider(previewView.getSurfaceProvider());
            
            // Hızlı barkod tarama için optimize edilmiş çözünürlük - daha uyumlu boyut
            ImageAnalysis imageAnalysis = new ImageAnalysis.Builder()
                    .setTargetResolution(new Size(640, 480)) // Barkod için ideal çözünürlük
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888) // ML Kit için optimize
                    .build();
                    
            imageAnalysis.setAnalyzer(cameraExecutor, new BarcodeAnalyzer());
            
            // Mevcut kullanım durumlarını temizle
            cameraProvider.unbindAll();
            
            // Kamerayı yaşam döngüsüne bağla
            camera = cameraProvider.bindToLifecycle(
                    this, cameraSelector, preview, imageAnalysis);
            
            // Kamera kontrol özelliklerini cihaz dostu şekilde ayarla
            configureCameraControl(camera.getCameraControl());
            
            Log.d(TAG, "Kamera başarıyla başlatıldı - Cihaz dostu mod");
            
        } catch (Exception e) {
            Log.e(TAG, "Kamera bağlama hatası: " + e.getMessage(), e);
            Toast.makeText(this, "Kamera kullanımı başlatılamadı: " + e.getMessage(), 
                    Toast.LENGTH_LONG).show();
        }
    }
    
    /**
     * Kamera kontrolünü yapılandırır (Flash için optimize)
     */
    private void configureCameraControl(CameraControl cameraControl) {
        // Flash durumunu kontrollü ayarla (ToggleButton durumuna göre)
        isFlashOn = switchFlashlightButton.isChecked();
        
        // Flash'ı arka planda güvenli ayarla (UI thread'i bloklamaz)
        cameraExecutor.execute(() -> {
            try {
                // Flash'ı kademeli olarak aç (ani parlaklık değişimini engelle)
                cameraControl.enableTorch(isFlashOn);
                Log.d(TAG, "Başlangıç flash durumu: " + (isFlashOn ? "AÇIK" : "KAPALI"));
            } catch (Exception e) {
                Log.e(TAG, "Başlangıç flash ayarı hatası: " + e.getMessage());
                // Flash hatası durumunda UI'yı güncelle
                runOnUiThread(() -> {
                    switchFlashlightButton.setChecked(false);
                    isFlashOn = false;
                });
            }
        });
        
        // Barkod tarama için çok hafif zoom (performans dostu)
        try {
            cameraControl.setLinearZoom(0.05f); // %5 zoom - daha az agresif
        } catch (Exception e) {
            Log.w(TAG, "Zoom ayarı desteklenmiyor: " + e.getMessage());
        }
        
        // Otomatik odaklama özelliklerini yumuşak ayarla
        setupAutoFocus(cameraControl);
        
        // Dokunmatik odaklama özelliğini yumuşak ayarla
        setupTapToFocus(cameraControl);
    }
    
    /**
     * Cihaza özgü optimal odaklama aralığını hesaplar
     */
    private long calculateOptimalFocusInterval() {
        try {
            String manufacturer = Build.MANUFACTURER.toLowerCase();
            String model = Build.MODEL.toLowerCase();
            int sdkVersion = Build.VERSION.SDK_INT;
            
            Log.d(TAG, "=== AF Optimization ===");
            Log.d(TAG, "Device: " + Build.MANUFACTURER + " " + Build.MODEL);
            Log.d(TAG, "Android SDK: " + sdkVersion);
            
            // Samsung cihazlar - genelde güçlü AF hardware
            if (manufacturer.contains("samsung")) {
                if (model.contains("galaxy s") || model.contains("note")) {
                    return 800L; // Flagship Samsung - hızlı AF
                }
                return 1200L; // Mid-range Samsung
            }
            
            // Xiaomi/Redmi - değişken AF kalitesi  
            if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi")) {
                if (sdkVersion >= 28) { // Android 9+
                    return 1800L; // Yeni Xiaomi - orta hız
                }
                return 2500L; // Eski Xiaomi - yavaş
            }
            
            // Huawei/Honor - custom AF implementation
            if (manufacturer.contains("huawei") || manufacturer.contains("honor")) {
                return 2200L; // Güvenli Huawei interval
            }
            
            // OnePlus - hızlı AF
            if (manufacturer.contains("oneplus")) {
                return 1000L;
            }
            
            // Google Pixel - çok optimize AF
            if (manufacturer.contains("google")) {
                return 900L;
            }
            
            // LG - eski modeller için yavaş
            if (manufacturer.contains("lg")) {
                return 2800L;
            }
            
            // Motorola - orta seviye AF
            if (manufacturer.contains("motorola")) {
                return 2000L;
            }
            
            // Bilinmeyen marka - güvenli değer
            long defaultInterval = 2500L;
            if (sdkVersion >= 30) { // Android 11+
                defaultInterval = 2000L; // Yeni Android daha hızlı
            }
            
            Log.d(TAG, "Calculated AF interval: " + defaultInterval + "ms (default)");
            return defaultInterval;
            
        } catch (Exception e) {
            Log.e(TAG, "AF interval hesaplama hatası: " + e.getMessage());
            return 2500L; // Ultra-safe fallback
        }
    }

    /**
     * Gelişmiş çoklu-bölge odaklama sistemi (Profesyonel yaklaşım)
     */
    private void setupAutoFocus(CameraControl cameraControl) {
        // PreviewView boyutları hazır olana kadar bekle
        previewView.post(() -> {
            try {
                int width = previewView.getWidth();
                int height = previewView.getHeight();
                
                // Güvenli boyut kontrolü
                if (width <= 0 || height <= 0) {
                    width = 720;
                    height = 1280;
                    Log.w(TAG, "PreviewView boyutları hazır değil, varsayılan değerler kullanılıyor: " + width + "x" + height);
                }
                
                Log.d(TAG, "AF setup - Preview size: " + width + "x" + height + ", Interval: " + optimalFocusInterval + "ms");
                
                // Multi-zone focus sistemi başlat
                startMultiZoneAutoFocus(cameraControl, width, height);
                
            } catch (Exception e) {
                Log.e(TAG, "AutoFocus kurulum hatası: " + e.getMessage());
                // Fallback: Basic single-point focus
                startBasicAutoFocus(cameraControl);
            }
        });
    }

    /**
     * Çoklu bölge odaklama noktalarını oluşturur (5-Zone System)
     */
    private List<MeteringPoint> createFocusZones(MeteringPointFactory factory, int width, int height) {
        List<MeteringPoint> zones = new ArrayList<>();
        
        try {
            // Zone 0: Merkez (en prioriteli - barkodlar genelde burada)
            zones.add(factory.createPoint(width * 0.5f, height * 0.5f));
            
            // Zone 1: Sol üst bölge
            zones.add(factory.createPoint(width * 0.35f, height * 0.4f));
            
            // Zone 2: Sağ üst bölge  
            zones.add(factory.createPoint(width * 0.65f, height * 0.4f));
            
            // Zone 3: Sol alt bölge
            zones.add(factory.createPoint(width * 0.35f, height * 0.6f));
            
            // Zone 4: Sağ alt bölge
            zones.add(factory.createPoint(width * 0.65f, height * 0.6f));
            
            Log.d(TAG, "Focus zones created: " + zones.size() + " zones");
            
        } catch (Exception e) {
            Log.e(TAG, "Focus zone oluşturma hatası: " + e.getMessage());
            // Fallback: Sadece merkez
            zones.clear();
            zones.add(factory.createPoint(width * 0.5f, height * 0.5f));
        }
        
        return zones;
    }

    /**
     * Gelişmiş çoklu-bölge otomatik odaklama başlatır
     */
    private void startMultiZoneAutoFocus(CameraControl cameraControl, int width, int height) {
        try {
            // Önceki AF task'ı iptal et
            stopAutoFocus();
            
            MeteringPointFactory factory = new SurfaceOrientedMeteringPointFactory(width, height);
            List<MeteringPoint> focusZones = createFocusZones(factory, width, height);
            
            if (focusZones.isEmpty()) {
                Log.w(TAG, "Focus zones boş, basic AF'e geçiliyor");
                startBasicAutoFocus(cameraControl);
                return;
            }
            
            Log.d(TAG, "Multi-zone AF başlatılıyor - " + focusZones.size() + " zone, interval: " + optimalFocusInterval + "ms");
            
            // İlk odaklanma: merkez bölge
            performInitialFocus(cameraControl, focusZones.get(0));
            
            // Sürekli çoklu-bölge odaklama task'ı
            autoFocusTask = autoFocusExecutor.scheduleAtFixedRate(() -> {
                try {
                    if (!isAutoFocusEnabled || cameraControl == null) {
                        return;
                    }
                    
                    // Progressive focus: sırayla farklı bölgelere odaklan
                    MeteringPoint currentZone = focusZones.get(currentFocusZone);
                    
                    // Gelişmiş odaklama action'ı oluştur
                    FocusMeteringAction action = new FocusMeteringAction.Builder(currentZone)
                            .setAutoCancelDuration(optimalFocusInterval * 2, TimeUnit.MILLISECONDS)
                            .build();
                    
                    cameraControl.startFocusAndMetering(action);
                    
                    // Sonraki zone'a geç (progressive rotation)
                    currentFocusZone = (currentFocusZone + 1) % focusZones.size();
                    
                    Log.v(TAG, "AF cycle - Zone: " + currentFocusZone + "/" + focusZones.size());
                    
                } catch (Exception e) {
                    Log.w(TAG, "Multi-zone AF cycle hatası: " + e.getMessage());
                }
            }, 1500L, optimalFocusInterval, TimeUnit.MILLISECONDS); // 1.5s gecikme ile başla
            
            Log.i(TAG, "Multi-zone AutoFocus başarıyla başlatıldı");
            
        } catch (Exception e) {
            Log.e(TAG, "Multi-zone AF başlatma hatası: " + e.getMessage());
            startBasicAutoFocus(cameraControl);
        }
    }

    /**
     * İlk odaklanma işlemini gerçekleştirir (Smooth startup)
     */
    private void performInitialFocus(CameraControl cameraControl, MeteringPoint centerPoint) {
        try {
            FocusMeteringAction initialAction = new FocusMeteringAction.Builder(centerPoint)
                    .setAutoCancelDuration(2000, TimeUnit.MILLISECONDS) // İlk odaklama daha uzun
                    .build();
            
            cameraControl.startFocusAndMetering(initialAction);
            Log.d(TAG, "Initial focus completed - Center zone");
            
        } catch (Exception e) {
            Log.w(TAG, "Initial focus hatası: " + e.getMessage());
        }
    }

    /**
     * Fallback: Basit tek nokta otomatik odaklama (Eski sistem)
     */
    private void startBasicAutoFocus(CameraControl cameraControl) {
        try {
            Log.w(TAG, "Fallback: Basic single-point AF başlatılıyor");
            
            autoFocusTask = autoFocusExecutor.scheduleAtFixedRate(() -> {
                try {
                    if (!isAutoFocusEnabled) return;
                    
                    // Basit merkez odaklama
                    MeteringPointFactory factory = new SurfaceOrientedMeteringPointFactory(720, 1280);
                    MeteringPoint center = factory.createPoint(360, 640);
                    
                    FocusMeteringAction action = new FocusMeteringAction.Builder(center)
                            .setAutoCancelDuration(optimalFocusInterval, TimeUnit.MILLISECONDS)
                            .build();
                    
                    cameraControl.startFocusAndMetering(action);
                    
                } catch (Exception e) {
                    Log.w(TAG, "Basic AF hatası: " + e.getMessage());
                }
            }, 2000L, optimalFocusInterval, TimeUnit.MILLISECONDS);
            
        } catch (Exception e) {
            Log.e(TAG, "Basic AF başlatma hatası: " + e.getMessage());
        }
    }

    /**
     * AutoFocus sistemini durdurur (Lifecycle management)
     */
    private void stopAutoFocus() {
        try {
            if (autoFocusTask != null && !autoFocusTask.isCancelled()) {
                autoFocusTask.cancel(true);
                autoFocusTask = null;
                Log.d(TAG, "AutoFocus task durduruldu");
            }
        } catch (Exception e) {
            Log.w(TAG, "AutoFocus durdurma hatası: " + e.getMessage());
        }
    }
    
    /**
     * Dokunmatik odaklama özelliğini ayarlar
     */
    private void setupTapToFocus(CameraControl cameraControl) {
        previewView.setOnTouchListener((view, event) -> {
            try {
                // Sadece ACTION_DOWN'da odaklan (çok fazla odaklama önlenir)
                if (event.getAction() != MotionEvent.ACTION_DOWN) {
                    return true;
                }
                
                int width = view.getWidth();
                int height = view.getHeight();
                
                // Güvenli boyut kontrolü
                if (width <= 0 || height <= 0) {
                    Log.w(TAG, "Dokunma odaklama için geçersiz boyutlar");
                    return true;
                }
                
                MeteringPointFactory factory = new SurfaceOrientedMeteringPointFactory(width, height);
                MeteringPoint point = factory.createPoint(event.getX(), event.getY());
                
                // Daha uzun süreli ve yumuşak odaklama
                FocusMeteringAction action = new FocusMeteringAction.Builder(point)
                        .setAutoCancelDuration(2000, TimeUnit.MILLISECONDS) // 2 saniye
                        .build();
                        
                cameraControl.startFocusAndMetering(action);
                
                Log.d(TAG, "Dokunmatik odaklama: X=" + event.getX() + ", Y=" + event.getY());
            } catch (Exception e) {
                Log.w(TAG, "Dokunmatik odaklama hatası: " + e.getMessage());
            }
            return true;
        });
    }
    
    /**
     * Flash açma/kapama işlemini hızlı gerçekleştirir
     * 
     * @param isOn Flash'ın açık olup olmayacağı
     */
    private void toggleFlash(boolean isOn) {
        if (camera != null && camera.getCameraControl() != null) {
            CameraControl cameraControl = camera.getCameraControl();
            
            // Flash toggle işlemini arka planda yumuşak yap
            cameraExecutor.execute(() -> {
                try {
                    // CameraX flash kontrolü - yumuşak açma/kapama
                    cameraControl.enableTorch(isOn);
                    
                    // Flash durumunu güncelle
                    isFlashOn = isOn;
                    
                    // Log ile durum kontrolü
                    Log.d(TAG, "Flash durumu değiştirildi: " + (isFlashOn ? "AÇIK" : "KAPALI"));
                    
                    // UI thread'e ana durumu bildir
                    runOnUiThread(() -> {
                        // Flash açıldığında ekran parlaklığını yumuşak ayarla
                        if (isFlashOn) {
                            // Flash açıkken arka plan overlay'i hafif aktif et (gözü korumak için)
                            View overlay = findViewById(R.id.scanner_overlay);
                            if (overlay != null) {
                                overlay.setVisibility(View.VISIBLE);
                                overlay.setAlpha(0.15f); // Çok hafif karartma
                            }
                        } else {
                            // Flash kapalıyken overlay'i kapat
                            View overlay = findViewById(R.id.scanner_overlay);
                            if (overlay != null) {
                                overlay.setVisibility(View.GONE);
                            }
                        }
                    });
                    
                } catch (Exception e) {
                    Log.e(TAG, "Flash toggle hatası: " + e.getMessage());
                    
                    // Hata durumunda UI'daki button durumunu geri al
                    runOnUiThread(() -> {
                        switchFlashlightButton.setChecked(!isOn);
                        isFlashOn = !isOn;
                        
                        // Overlay'i de eski durumuna getir
                        View overlay = findViewById(R.id.scanner_overlay);
                        if (overlay != null) {
                            overlay.setVisibility(View.GONE);
                        }
                    });
                }
            });
            
            // UI geri bildirimi için çok hafif titreşim (isteğe bağlı)
            if (vibrator != null) {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        VibrationEffect effect = VibrationEffect.createOneShot(30, VibrationEffect.DEFAULT_AMPLITUDE);
                        vibrator.vibrate(effect);
                    } else {
                        vibrator.vibrate(30L); // Daha kısa titreşim
                    }
                } catch (Exception e) {
                    // Titreşim hatası olursa sessizce devam et
                }
            }
        } else {
            Log.w(TAG, "Kamera hazır değil, flash toggle iptal edildi");
            
            // Kamera hazır değilse button durumunu eski haline getir
            switchFlashlightButton.setChecked(!isOn);
        }
    }
    
    /**
     * Barkod tarama analizini gerçekleştiren iç sınıf
     */
    private class BarcodeAnalyzer implements ImageAnalysis.Analyzer {
        private long lastAnalysisTime = 0;
        private static final long MIN_ANALYSIS_INTERVAL = 100; // ms - Çok hızlı analiz
        
        @SuppressLint("UnsafeOptInUsageError")
        @Override
        public void analyze(@NonNull ImageProxy imageProxy) {
            // Tarama veya görüntü yoksa işlemi iptal et
            if (imageProxy.getImage() == null || !isScanning) {
                imageProxy.close();
                return;
            }
            
            // Frame skip ile performans optimize et
            long currentTime = System.currentTimeMillis();
            if (currentTime - lastAnalysisTime < MIN_ANALYSIS_INTERVAL) {
                imageProxy.close();
                return;
            }
            lastAnalysisTime = currentTime;
            
            // ML Kit için görüntüyü hızlı hazırlama
            InputImage inputImage = InputImage.fromMediaImage(
                    imageProxy.getImage(), 
                    imageProxy.getImageInfo().getRotationDegrees());
            
            // Hızlı barkod tarama - tek seferde sonuç al
            barcodeScanner.process(inputImage)
                    .addOnSuccessListener(barcodes -> {
                        if (!barcodes.isEmpty() && isScanning) {
                            // İlk geçerli barkodu hemen işle
                            for (Barcode barcode : barcodes) {
                            String barcodeValue = extractBarcodeValue(barcode);
                            
                                // Sadece geçerli QR/DataMatrix değerlerini işle
                                if (barcodeValue != null && !barcodeValue.trim().isEmpty()) {
                                    isScanning = false; // Hemen durdur
                                    runOnUiThread(() -> handleScannedBarcode(barcodeValue.trim()));
                                    return; // İlk geçerli barkod bulundu, çık
                                }
                            }
                            // Hiç geçerli barkod bulunamadı, taramaya devam et
                            Log.d(TAG, "Bulunan barkodlarda geçerli değer yok, taramaya devam...");
                        }
                    })
                    .addOnFailureListener(e -> {
                        // Hata logunu minimize et - performans için
                        if (isScanning) {
                            Log.w(TAG, "Analiz hatası: " + e.getMessage());
                        }
                    })
                    .addOnCompleteListener(task -> imageProxy.close());
        }
        
        /**
         * Barkod nesnesinden değer çıkarır (Sadece QR ve DataMatrix)
         */
        private String extractBarcodeValue(Barcode barcode) {
            // Sadece desteklenen formatları kabul et
            if (barcode.getFormat() != Barcode.FORMAT_QR_CODE && 
                barcode.getFormat() != Barcode.FORMAT_DATA_MATRIX) {
                Log.d(TAG, "Desteklenmeyen barkod formatı: " + getBarcodeFormatName(barcode.getFormat()));
                return null; // Desteklenmeyen format
            }
            
            // Öncelikle raw değeri dene
            String barcodeValue = barcode.getRawValue();
            
            // Raw değer yoksa display değeri dene
            if (barcodeValue == null || barcodeValue.isEmpty()) {
                barcodeValue = barcode.getDisplayValue();
            }
            
            // Değer hala yoksa geçersiz kabul et
            if (barcodeValue == null || barcodeValue.isEmpty()) {
                Log.w(TAG, "Barkod değeri boş - Format: " + getBarcodeFormatName(barcode.getFormat()));
                return null; // Geçersiz barkod
            }
            
            Log.d(TAG, "Geçerli barkod bulundu - Format: " + getBarcodeFormatName(barcode.getFormat()) + ", Değer: " + barcodeValue);
            return barcodeValue;
        }
        
        /**
         * Barkod format tipine göre isim döndürür (Sadece desteklenen formatlar)
         */
        private String getBarcodeFormatName(int formatType) {
            switch (formatType) {
                case Barcode.FORMAT_QR_CODE:
                    return "QR Code";
                case Barcode.FORMAT_DATA_MATRIX:
                    return "DataMatrix";
                default:
                    return "Desteklenmeyen Format (" + formatType + ")";
            }
        }
    }
    
    /**
     * Taranan barkod işleme
     */
    private void handleScannedBarcode(String barcodeContent) {
        // Ses ve titreşim geri bildirimi
        playBeepSound();
        vibrate();
        
        // Barkod içeriğini logla
        Log.i(TAG, "Okunan Barkod: " + barcodeContent);
        
        // Kullanıcıya bilgi ver
        Toast.makeText(this, "Barkod: " + barcodeContent, Toast.LENGTH_SHORT).show();
        
        // Sonucu web sayfasına gönder
        navigateToResultWebsite(barcodeContent);
    }
    
    /**
     * Web sayfasına barkod sonucuyla navigasyon yapar
     */
    private void navigateToResultWebsite(String barcodeContent) {
        try {
            // Kullanıcının ayarladığı URL temel adresini al (her seferinde fresh al)
            String urlBase = getUrlBase();
            
            // Kullanıcının yazdığı URL'yi olduğu gibi kullan ve sadece barkod içeriğini sonuna ekle
            String finalUrl = urlBase + Uri.encode(barcodeContent);
            
            Log.i(TAG, "URL Oluşturma Detayları:");
            Log.i(TAG, "  - Kullanıcının URL'si: " + urlBase);
            Log.i(TAG, "  - Barkod İçeriği: " + barcodeContent);
            Log.i(TAG, "  - Final URL: " + finalUrl);
            
            // Öncelikle Chrome'da açılmayı dene
            try {
                // Chrome Custom Tabs kullan
                CustomTabsIntent.Builder builder = new CustomTabsIntent.Builder();
                
                // Renkleri ve animasyonları ayarla - tema ile uyumlu olması için
                builder.setToolbarColor(ContextCompat.getColor(this, android.R.color.black));
                builder.setShowTitle(true);
                
                // Sekme davranışını ayarla - mevcut sekmeyi kullanması için
                CustomTabsIntent customTabsIntent = builder.build();
                customTabsIntent.intent.setFlags(Intent.FLAG_ACTIVITY_NO_HISTORY | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                
                // CHROME öncelikli olarak kullanılsın
                customTabsIntent.intent.setPackage("com.android.chrome");
                
                // Chrome ile aç
                customTabsIntent.launchUrl(this, Uri.parse(finalUrl));
                Log.i(TAG, "Chrome ile açıldı: " + finalUrl);
            } catch (Exception e) {
                Log.i(TAG, "Chrome açılamadı, varsayılan tarayıcı kullanılacak: " + e.getMessage());
                
                // Chrome açılamazsa varsayılan tarayıcı ile dene
                CustomTabsIntent.Builder builderDefault = new CustomTabsIntent.Builder();
                builderDefault.setToolbarColor(ContextCompat.getColor(this, android.R.color.black));
                builderDefault.setShowTitle(true);
                
                CustomTabsIntent defaultTabsIntent = builderDefault.build();
                defaultTabsIntent.intent.setFlags(Intent.FLAG_ACTIVITY_NO_HISTORY | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                
                // Varsayılan tarayıcı ile aç
                defaultTabsIntent.launchUrl(this, Uri.parse(finalUrl));
                Log.i(TAG, "Varsayılan tarayıcı ile açıldı: " + finalUrl);
            }
            
            // Bu aktiviteyi kapat
            finish();
        } catch (Exception e) {
            Log.e(TAG, "URL açma hatası: " + e.getMessage());
            Toast.makeText(this, "Barkod sonucu açılamadı: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }
    
    /**
     * Ayarlardan URL temel adresini alır veya varsayılanı döndürür
     */
    private String getUrlBase() {
        try {
            SharedPreferences settings = getSharedPreferences(PREFS_NAME, 0);
            String savedUrl = settings.getString(KEY_URL_BASE, AppConstants.Api.DEFAULT_BARCODE_URL_BASE);
            
            // URL kontrolü ve debugging
            Log.d(TAG, "Kaydedilmiş URL: " + savedUrl);
            Log.d(TAG, "Varsayılan URL: " + AppConstants.Api.DEFAULT_BARCODE_URL_BASE);
            
            // URL boş veya geçersizse varsayılanı kullan
            if (savedUrl == null || savedUrl.trim().isEmpty()) {
                Log.w(TAG, "Kaydedilmiş URL boş, varsayılan kullanılıyor");
                return AppConstants.Api.DEFAULT_BARCODE_URL_BASE;
            }
            
            // URL format kontrolü
            String trimmedUrl = savedUrl.trim();
            if (!trimmedUrl.startsWith("http://") && !trimmedUrl.startsWith("https://")) {
                Log.w(TAG, "Geçersiz URL formatı: " + trimmedUrl + ", varsayılan kullanılıyor");
                return AppConstants.Api.DEFAULT_BARCODE_URL_BASE;
            }
            
            Log.i(TAG, "Kullanılan URL: " + trimmedUrl);
            return trimmedUrl;
            
        } catch (Exception e) {
            Log.e(TAG, "URL okuma hatası: " + e.getMessage());
            return AppConstants.Api.DEFAULT_BARCODE_URL_BASE;
        }
    }
    
    /**
     * Bip sesi çalar
     */
    private void playBeepSound() {
        // Ses çalma işlemi
        if (mediaPlayer != null) {
            try {
                if (mediaPlayer.isPlaying()) {
                    mediaPlayer.stop();
                    mediaPlayer.reset();
                    mediaPlayer = MediaPlayer.create(this, R.raw.beep);
                }
                mediaPlayer.start();
            } catch (Exception e) {
                Log.e(TAG, "Ses çalma hatası: " + e.getMessage());
            }
        }
    }
    
    /**
     * Cihazda titreşim oluşturur
     */
    private void vibrate() {
        if (vibrator != null) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Android 12+ için
                    VibrationEffect effect = VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK);
                    vibrator.vibrate(effect);
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Android 8-11 için
                    VibrationEffect effect = VibrationEffect.createOneShot(300, VibrationEffect.DEFAULT_AMPLITUDE);
                    vibrator.vibrate(effect);
                } else {
                    // Android 7 ve öncesi için
                    vibrator.vibrate(300L);
                }
            } catch (Exception e) {
                Log.e(TAG, "Titreşim hatası: " + e.getMessage());
            }
        }
    }
    
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_scanner, menu);
        return true;
    }
    
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();
        
        if (id == R.id.action_settings) {
            // Ayarlar aktivitesine git
            Intent intent = new Intent(this, SettingsActivity.class);
            startActivity(intent);
            return true;
        }
        
        return super.onOptionsItemSelected(item);
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        
        // AutoFocus'u yeniden etkinleştir
        isAutoFocusEnabled = true;
        
        // Settings'ten döndüğünde güncel URL'yi kontrol et ve logla
        try {
            String currentUrl = getUrlBase();
            Log.i(TAG, "onResume - Güncel URL: " + currentUrl + ", AF enabled: " + isAutoFocusEnabled);
        } catch (Exception e) {
            Log.e(TAG, "onResume URL kontrolü hatası: " + e.getMessage());
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        
        // Activity pause olduğunda AutoFocus'u durdur (batarya optimizasyonu)
        isAutoFocusEnabled = false;
        stopAutoFocus();
        
        Log.d(TAG, "onPause - AutoFocus durduruldu");
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        isScanning = false;
        isAutoFocusEnabled = false; // AF sistemini durdur
        releaseResources();
    }
    
    /**
     * Kaynakları güvenli şekilde serbest bırakır (Gelişmiş lifecycle management)
     */
    private void releaseResources() {
        try {
            Log.d(TAG, "Resource cleanup başlatıldı");
            
            // AutoFocus sistemini güvenli şekilde durdur
            stopAutoFocus();
            
            // AutoFocus executor'ü kapat
            if (autoFocusExecutor != null && !autoFocusExecutor.isShutdown()) {
                autoFocusExecutor.shutdown();
                try {
                    if (!autoFocusExecutor.awaitTermination(1000, TimeUnit.MILLISECONDS)) {
                        autoFocusExecutor.shutdownNow();
                        Log.w(TAG, "AutoFocus executor zorla kapatıldı");
                    } else {
                        Log.d(TAG, "AutoFocus executor başarıyla kapatıldı");
                    }
                } catch (InterruptedException e) {
                    autoFocusExecutor.shutdownNow();
                    Thread.currentThread().interrupt();
                    Log.w(TAG, "AutoFocus executor interrupt ile kapatıldı");
                }
            }
            
            // Camera executor'ü kapat
            if (cameraExecutor != null && !cameraExecutor.isShutdown()) {
                cameraExecutor.shutdown();
                try {
                    if (!cameraExecutor.awaitTermination(1000, TimeUnit.MILLISECONDS)) {
                        cameraExecutor.shutdownNow();
                    }
                    Log.d(TAG, "Camera executor kapatıldı");
                } catch (InterruptedException e) {
                    cameraExecutor.shutdownNow();
                    Thread.currentThread().interrupt();
                }
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Executor kapatma hatası: " + e.getMessage());
        }
        
        // MediaPlayer'ı temizle
        if (mediaPlayer != null) {
            try {
                if (mediaPlayer.isPlaying()) {
                    mediaPlayer.stop();
                }
                mediaPlayer.release();
                mediaPlayer = null;
                Log.d(TAG, "MediaPlayer kapatıldı");
            } catch (Exception e) {
                Log.e(TAG, "MediaPlayer kapatma hatası: " + e.getMessage());
            }
        }
        
        // Barkod tarayıcıyı kapat
        if (barcodeScanner != null) {
            try {
                barcodeScanner.close();
                Log.d(TAG, "BarcodeScanner kapatıldı");
            } catch (Exception e) {
                Log.e(TAG, "BarcodeScanner kapatma hatası: " + e.getMessage());
            }
        }
        
        Log.i(TAG, "Tüm kaynaklar başarıyla serbest bırakıldı");
    }
} 