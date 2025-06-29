package com.envanto.barcode;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;
import android.widget.TextView;

import androidx.appcompat.app.ActionBar;
import androidx.appcompat.app.AppCompatActivity;
import com.envanto.barcode.utils.AppConstants;

/**
 * Envanto Barkod Tarayıcı Ayarlar Ekranı
 * 
 * Kullanıcının barkod sonuçlarının gönderileceği URL temel adresini
 * ayarlamasını sağlayan aktivite.
 * public static final String DEFAULT_URL_BASE = "https://milasoft.com.tr/EnvantoBarkod/?barcode=";
 */
public class SettingsActivity extends AppCompatActivity {

    private static final String TAG = "SettingsActivity";
    private static final String PREFS_NAME = "EnvantoBarcodePrefs";
    private static final String KEY_URL_BASE = "url_base";
    public static final String DEFAULT_URL_BASE = AppConstants.Api.DEFAULT_BARCODE_URL_BASE;

    private EditText urlEditText;
    private Button saveButton;
    private Button resetButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            setContentView(R.layout.activity_settings);

            // Geri butonu için action bar'ı ayarla
            ActionBar actionBar = getSupportActionBar();
            if (actionBar != null) {
                actionBar.setDisplayHomeAsUpEnabled(true);
                actionBar.setTitle(R.string.settings_title);
            }

            // UI bileşenlerini başlat
            initViews();
            
            // Kaydedilmiş URL'yi yükle
            loadSavedUrl();
            
            // Buton işlevlerini ayarla
            setupButtonListeners();

            // Versiyon ismini göster
            TextView versionText = findViewById(R.id.versionText);
            String versionName = BuildConfig.VERSION_NAME;
            versionText.setText("Versiyon: " + versionName);
        } catch (Exception e) {
            Log.e(TAG, "onCreate hatası: " + e.getMessage());
            Toast.makeText(this, "Ayarlar sayfası açılamadı: " + e.getMessage(), Toast.LENGTH_LONG).show();
            finish();
        }
    }
    
    /**
     * UI bileşenlerini başlatır
     */
    private void initViews() {
        try {
            urlEditText = findViewById(R.id.url_base_edit_text);
            saveButton = findViewById(R.id.save_button);
            resetButton = findViewById(R.id.reset_button);
        } catch (Exception e) {
            Log.e(TAG, "UI bileşenleri başlatılamadı: " + e.getMessage());
        }
    }
    
    /**
     * Daha önce kaydedilmiş URL'yi yükler ve UI'a yerleştirir
     */
    private void loadSavedUrl() {
        try {
            SharedPreferences settings = getSharedPreferences(PREFS_NAME, 0);
            String savedUrl = settings.getString(KEY_URL_BASE, DEFAULT_URL_BASE);
            
            Log.d(TAG, "Yüklenen URL: " + savedUrl);
            
            // Kullanıcının kaydettiği URL'yi olduğu gibi göster - hiçbir temizleme yapma
            if (urlEditText != null) {
                urlEditText.setText(savedUrl);
            }
        } catch (Exception e) {
            Log.e(TAG, "URL yüklenemedi: " + e.getMessage());
            // Hata durumunda varsayılan URL'yi yükle
            if (urlEditText != null) {
                urlEditText.setText(DEFAULT_URL_BASE);
            }
        }
    }
    
    /**
     * Buton dinleyicilerini ayarlar
     */
    private void setupButtonListeners() {
        try {
            // Kaydet butonu işlevi
            if (saveButton != null) {
                saveButton.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        saveUrlSettings();
                    }
                });
            }
            
            // Sıfırla butonu işlevi
            if (resetButton != null) {
                resetButton.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        if (urlEditText != null) {
                            urlEditText.setText(DEFAULT_URL_BASE);
                        }
                        saveUrlSettings();
                    }
                });
            }
        } catch (Exception e) {
            Log.e(TAG, "Buton listenerları ayarlanamadı: " + e.getMessage());
        }
    }
    
    /**
     * URL ayarını kaydeder
     */
    private void saveUrlSettings() {
        try {
            if (urlEditText == null) {
                Toast.makeText(this, "URL girişi bulunamadı", Toast.LENGTH_SHORT).show();
                return;
            }
            
            String url = urlEditText.getText().toString().trim();
            
            // URL boşsa uyarı ver
            if (url.isEmpty()) {
                Toast.makeText(this, R.string.error_empty_url, Toast.LENGTH_SHORT).show();
                return;
            }
            
            // URL formatını kontrol et
            if (!url.startsWith("http://") && !url.startsWith("https://")) {
                Toast.makeText(this, R.string.error_invalid_url, Toast.LENGTH_SHORT).show();
                return;
            }
            
            // Kullanıcının yazdığı URL'yi olduğu gibi kaydet - hiçbir değişiklik yapma
            Log.d(TAG, "Kaydedilecek URL (kullanıcının yazdığı gibi): " + url);
            
            // URL'yi SharedPreferences'a kaydet
            SharedPreferences settings = getSharedPreferences(PREFS_NAME, 0);
            SharedPreferences.Editor editor = settings.edit();
            editor.putString(KEY_URL_BASE, url);
            boolean saved = editor.commit(); // apply() yerine commit() kullan - anında kaydet
            
            if (saved) {
                Log.i(TAG, "URL başarıyla kaydedildi: " + url);
                Toast.makeText(this, R.string.settings_saved, Toast.LENGTH_SHORT).show();
                
                // Kaydetme sonrası kontrol et
                String verifyUrl = settings.getString(KEY_URL_BASE, "KAYIT YOK");
                Log.d(TAG, "Kayıt sonrası kontrol - Okunan URL: " + verifyUrl);
                
                finish();
            } else {
                Log.e(TAG, "URL kaydedilemedi!");
                Toast.makeText(this, "Ayarlar kaydedilemedi", Toast.LENGTH_SHORT).show();
            }
            
        } catch (Exception e) {
            Log.e(TAG, "URL ayarları kaydedilemedi: " + e.getMessage());
            Toast.makeText(this, "Ayarlar kaydedilemedi: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }
    
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        if (item.getItemId() == android.R.id.home) {
            onBackPressed();
            return true;
        }
        return super.onOptionsItemSelected(item);
    }
} 