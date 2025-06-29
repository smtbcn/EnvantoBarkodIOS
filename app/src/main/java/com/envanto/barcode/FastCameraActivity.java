package com.envanto.barcode;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Toast;
import android.content.Context;

import android.os.Vibrator;
import android.os.VibrationEffect;
import android.os.Handler;
import android.os.Looper;
import android.media.MediaPlayer;
import android.media.ToneGenerator;
import android.media.AudioManager;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraControl;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.ImageCaptureException;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.LifecycleOwner;
import java.util.concurrent.ExecutionException;
import com.envanto.barcode.databinding.ActivityFastCameraBinding;
import com.google.common.util.concurrent.ListenableFuture;
import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class FastCameraActivity extends AppCompatActivity {
    private static final String TAG = "FastCameraActivity";
    public static final String EXTRA_IMAGE_URI = "image_uri";
    
    private ActivityFastCameraBinding binding;
    private ImageCapture imageCapture;
    private Camera camera;
    private boolean isFlashEnabled = false;
    private MediaPlayer shutterPlayer;
    private ToneGenerator toneGenerator;
    private ExecutorService cameraExecutor;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityFastCameraBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        // Kamera executor'ını başlat
        cameraExecutor = Executors.newSingleThreadExecutor();
        
        // Basit kamerayı başlat
        startCamera();
        
        // Buton event'lerini ayarla
        setupButtonEvents();
        
        // Deklanşör sesi hazırla
        setupShutterSound();
    }
    
    private void setupButtonEvents() {
        // Resim çekme butonu
        binding.captureButton.setOnClickListener(v -> {
            binding.captureButton.setEnabled(false);
            takePhoto();
        });
        
        // Kapat butonu
        binding.closeButton.setOnClickListener(v -> {
            setResult(RESULT_CANCELED);
            finish();
        });
        
        // Flash butonu
        binding.flashButton.setOnClickListener(v -> {
            boolean newState = !isFlashEnabled;
            toggleFlash(newState);
        });
    }
    
    private void startCamera() {
        ListenableFuture<ProcessCameraProvider> cameraProviderFuture = 
            ProcessCameraProvider.getInstance(this);
        
        cameraProviderFuture.addListener(() -> {
            try {
                ProcessCameraProvider cameraProvider = cameraProviderFuture.get();
                bindCameraUseCases(cameraProvider);
            } catch (ExecutionException | InterruptedException e) {
                Log.e(TAG, "Kamera başlatma hatası", e);
                Toast.makeText(this, "Kamera başlatılamadı", Toast.LENGTH_SHORT).show();
                finish();
            }
        }, ContextCompat.getMainExecutor(this));
    }
    
    private void bindCameraUseCases(@NonNull ProcessCameraProvider cameraProvider) {
        // Preview use case
        Preview preview = new Preview.Builder().build();
        preview.setSurfaceProvider(binding.previewView.getSurfaceProvider());
        
        // ImageCapture use case
        imageCapture = new ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .build();
        
        // Basit arka kamera seçici
        CameraSelector cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA;
        
        try {
            // Önceki bağlantıları temizle
            cameraProvider.unbindAll();
            
            // Kamera use case'lerini bağla
            camera = cameraProvider.bindToLifecycle(
                (LifecycleOwner) this, 
                cameraSelector, 
                preview, 
                imageCapture
            );
            
            // Flash butonunu başlat
            initFlashButton();
            
        } catch (Exception e) {
            Log.e(TAG, "Kamera bağlama hatası", e);
            Toast.makeText(this, "Kamera bağlanamadı", Toast.LENGTH_SHORT).show();
            finish();
        }
    }
    
    private void takePhoto() {
        if (imageCapture == null) {
            binding.captureButton.setEnabled(true);
            return;
        }
        
        // Geri bildirim efektleri
        playShutterFeedback();
        
        // Resim dosyası oluştur
        File photoFile = createImageFile();
        if (photoFile == null) {
            binding.captureButton.setEnabled(true);
            Toast.makeText(this, "Resim dosyası oluşturulamadı", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Çıkış seçenekleri
        ImageCapture.OutputFileOptions outputOptions = new ImageCapture.OutputFileOptions.Builder(photoFile).build();
        
        // Resim çek
        imageCapture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(this),
            new ImageCapture.OnImageSavedCallback() {
                @Override
                public void onImageSaved(@NonNull ImageCapture.OutputFileResults output) {
                    // Başarılı - resim URI'sini geri döndür
                    Uri imageUri = Uri.fromFile(photoFile);
                    
                    Intent resultIntent = new Intent();
                    resultIntent.putExtra(EXTRA_IMAGE_URI, imageUri.toString());
                    setResult(RESULT_OK, resultIntent);
                    
                    // Başarı animasyonu
                    showCaptureSuccess();
                    
                    // Kısa bir gecikme sonrası kapat
                    binding.captureButton.postDelayed(() -> finish(), 300);
                }
                
                @Override
                public void onError(@NonNull ImageCaptureException exception) {
                    Log.e(TAG, "Resim çekme hatası", exception);
                    Toast.makeText(FastCameraActivity.this, "Resim çekilemedi", Toast.LENGTH_SHORT).show();
                    binding.captureButton.setEnabled(true);
                }
            }
        );
    }
    
    private File createImageFile() {
        try {
            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
            String imageFileName = "FAST_CAMERA_" + timeStamp;
            
            File cacheDir = getCacheDir();
            File tempImagesDir = new File(cacheDir, "fast_camera");
            
            if (!tempImagesDir.exists()) {
                tempImagesDir.mkdirs();
            }
            
            return File.createTempFile(imageFileName, ".jpg", tempImagesDir);
            
        } catch (Exception e) {
            Log.e(TAG, "Resim dosyası oluşturma hatası", e);
            return null;
        }
    }
    
    private void initFlashButton() {
        // Flash varsa butonu göster
        if (camera != null && camera.getCameraInfo().hasFlashUnit()) {
            binding.flashButton.setVisibility(View.VISIBLE);
        } else {
            binding.flashButton.setVisibility(View.VISIBLE); // Test için görünür
        }
        
        // Başlangıç UI'ını ayarla
        updateFlashButtonUI();
    }
    
    /**
     * Flash açma/kapama işlemini hızlı ve güvenli gerçekleştirir
     */
    private void toggleFlash(boolean isOn) {
        if (camera != null && camera.getCameraControl() != null) {
            // Anlık durum değişimi için optimizasyon
            CameraControl cameraControl = camera.getCameraControl();
            
            // Flash durumunu hemen güncelle
            isFlashEnabled = isOn;
            updateFlashButtonUI();
            
            // Flash toggle işlemini arka planda hızlı yap
            cameraExecutor.execute(() -> {
                try {
                    // CameraX flash kontrolü - anlık açma/kapama
                    cameraControl.enableTorch(isFlashEnabled);
                    
                    Log.d(TAG, "Flash durumu değiştirildi: " + (isFlashEnabled ? "AÇIK" : "KAPALI"));
                } catch (Exception e) {
                    Log.e(TAG, "Flash toggle hatası: " + e.getMessage());
                    
                    // Hata durumunda UI'daki button durumunu geri al
                    runOnUiThread(() -> {
                        isFlashEnabled = !isOn;
                        updateFlashButtonUI();
                    });
                }
            });
            
            // UI geri bildirimi için hafif titreşim
            try {
                Vibrator vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
                if (vibrator != null && vibrator.hasVibrator()) {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        VibrationEffect effect = VibrationEffect.createOneShot(30, VibrationEffect.DEFAULT_AMPLITUDE);
                        vibrator.vibrate(effect);
                    } else {
                        vibrator.vibrate(30L);
                    }
                }
            } catch (Exception e) {
                // Titreşim hatası olursa sessizce devam et
            }
        } else {
            Log.w(TAG, "Kamera hazır değil, flash toggle iptal edildi");
        }
    }
    
    private void updateFlashButtonUI() {
        // Manuel olarak arka plan rengini ayarla
        if (isFlashEnabled) {
            // Flash açık - kırmızı arka plan
            binding.flashButton.setBackgroundTintList(
                ContextCompat.getColorStateList(this, R.color.error)
            );
        } else {
            // Flash kapalı - yeşil arka plan  
            binding.flashButton.setBackgroundTintList(
                ContextCompat.getColorStateList(this, R.color.success)
            );
        }
    }
    
    private void setupShutterSound() {
        try {
            // Önce ses dosyasını dene
            shutterPlayer = MediaPlayer.create(this, R.raw.beep);
            
            if (shutterPlayer != null) {
                shutterPlayer.setVolume(0.5f, 0.5f);
                Log.d(TAG, "MediaPlayer deklanşör sesi hazırlandı");
            }
            
            // Alternatif olarak ToneGenerator hazırla
            try {
                toneGenerator = new ToneGenerator(AudioManager.STREAM_SYSTEM, 80);
                Log.d(TAG, "ToneGenerator hazırlandı");
            } catch (Exception e) {
                Log.w(TAG, "ToneGenerator oluşturulamadı", e);
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Deklanşör sesi yüklenemiyor", e);
        }
    }
    
    private void playShutterFeedback() {
        // Titreşim efekti
        try {
            Vibrator vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
            if (vibrator != null && vibrator.hasVibrator()) {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    // Yeni API - kısa ve hafif titreşim
                    VibrationEffect effect = VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE);
                    vibrator.vibrate(effect);
                } else {
                    // Eski API
                    vibrator.vibrate(50);
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Titreşim hatası", e);
        }
        
        // Deklanşör sesi
        playShutterSound();
    }
    
    private void playShutterSound() {
        // İlk önce MediaPlayer'ı dene
        boolean soundPlayed = false;
        
        try {
            if (shutterPlayer != null && !shutterPlayer.isPlaying()) {
                shutterPlayer.start();
                soundPlayed = true;
                Log.d(TAG, "MediaPlayer ses çalındı");
            }
        } catch (Exception e) {
            Log.w(TAG, "MediaPlayer ses çalma hatası", e);
        }
        
        // MediaPlayer çalışmazsa ToneGenerator dene
        if (!soundPlayed) {
            try {
                if (toneGenerator != null) {
                    // Kısa bir "click" sesi
                    toneGenerator.startTone(ToneGenerator.TONE_PROP_BEEP, 100);
                    Log.d(TAG, "ToneGenerator ses çalındı");
                }
            } catch (Exception e) {
                Log.w(TAG, "ToneGenerator ses çalma hatası", e);
            }
        }
    }
    
    private void showCaptureSuccess() {
        // Ekran yanıp sönme efekti
        binding.getRoot().setAlpha(0.3f);
        binding.getRoot().animate()
            .alpha(1.0f)
            .setDuration(200)
            .start();
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        cameraExecutor.shutdown();
        
        if (shutterPlayer != null) {
            shutterPlayer.release();
            shutterPlayer = null;
        }
        
        if (toneGenerator != null) {
            toneGenerator.release();
            toneGenerator = null;
        }
    }
} 