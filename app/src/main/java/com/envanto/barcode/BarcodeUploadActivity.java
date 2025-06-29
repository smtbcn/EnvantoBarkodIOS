package com.envanto.barcode;

/*
 * KAMERA GEÇMİŞ NOTLARI:
 * 
 * Bu aktivite önceden cihazın varsayılan kamera uygulamasını kullanıyordu.
 * Performans iyileştirmesi için FastCameraActivity (CameraX tabanlı) ile değiştirildi.
 * 
 * Eski kamera kodları yorum satırı olarak korunmuştur:
 * - startCamera() metodu: Satır ~740 civarında
 * - cameraLauncher: Satır ~95 civarında
 * - ActivityResultContracts.TakePicture() launcher: Satır ~630 civarında
 * 
 * İleride geri dönüş gerekirse bu kodları yorum satırından çıkarabilirsiniz.
 */

import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.MenuItem;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.envanto.barcode.adapter.CustomerImagesAdapter;
import com.envanto.barcode.api.ApiClient;
import com.envanto.barcode.api.Customer;
import com.envanto.barcode.api.UploadResponse;
import com.envanto.barcode.databinding.ActivityBarcodeUploadBinding;
import com.envanto.barcode.utils.AppConstants;
import com.envanto.barcode.utils.DeviceAuthManager;
import com.envanto.barcode.utils.DeviceIdentifier;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.android.material.textfield.MaterialAutoCompleteTextView;
import java.util.ArrayList;
import java.util.List;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.io.IOException;
import android.os.Handler;
import android.os.Looper;
import android.widget.AdapterView;
import android.widget.Filter;
import android.widget.Filterable;
import android.widget.BaseAdapter;
import android.view.ViewGroup;
import android.view.LayoutInflater;
import android.widget.TextView;
import android.view.inputmethod.InputMethodManager;
import android.content.Context;
import android.app.Activity;
import android.view.WindowManager;
import android.content.Intent;
import android.net.Uri;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.core.content.FileProvider;
import java.io.File;
import android.os.Environment;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import com.envanto.barcode.database.DatabaseHelper;
import com.envanto.barcode.utils.ImageStorageManager;
import android.os.Build;
import com.envanto.barcode.utils.NetworkUtils;
import okhttp3.MediaType;
import okhttp3.MultipartBody;
import okhttp3.RequestBody;
import com.envanto.barcode.service.UploadRetryService;
import android.database.Cursor;
import android.text.TextUtils;
import android.widget.ImageButton;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import android.content.pm.PackageManager;
import android.Manifest;
import android.content.SharedPreferences;
import android.provider.MediaStore;
import android.hardware.Camera;
import android.database.sqlite.SQLiteDatabase;
import android.app.AlertDialog;
import android.view.Menu;
import android.widget.Button;
import android.widget.LinearLayout;
import android.provider.Settings;
import androidx.recyclerview.widget.LinearLayoutManager;
import java.util.HashMap;
import java.util.Map;

public class BarcodeUploadActivity extends AppCompatActivity {
    private static final String TAG = "BarcodeUploadActivity";
    private static final int STORAGE_PERMISSION_REQUEST = 101;
    
    private ActivityBarcodeUploadBinding binding;
    private CustomerAdapter customerAdapter;
    private Customer selectedCustomer;
    private Handler handler;
    private List<Customer> currentCustomers = new ArrayList<>();
    private MaterialAutoCompleteTextView autoCompleteTextView;
    private ActivityResultLauncher<Intent> imagePickerLauncher;
    // YORUM: Eski cihaz kamerası launcher - artık fastCameraLauncher kullanılıyor
    // private ActivityResultLauncher<Uri> cameraLauncher;
    private ActivityResultLauncher<Intent> fastCameraLauncher;
    private Uri currentPhotoUri;
    private Handler autoRefreshHandler;
    private Runnable autoRefreshRunnable;
    private boolean isActivityActive = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityBarcodeUploadBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        setSupportActionBar(binding.toolbar);
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setTitle("Barkod Resmi Yükleme");
        }

        handler = new Handler(Looper.getMainLooper());
        autoRefreshHandler = new Handler(Looper.getMainLooper());
        
        // Cihaz yetkilendirme kontrolü
        checkDeviceAuthorization();
        
        // Storage permissions kontrolü
        checkRequiredPermissions();
        
        setupCustomerSearch();
        setupImageHandling();
        setupAutoRefresh();
        
        // Yükleme servisini başlat
        try {
            Intent serviceIntent = new Intent(this, UploadRetryService.class);
            
            // Kullanıcının tercih ettiği bağlantı ayarını oku (MainActivity'den)
            SharedPreferences preferences = getSharedPreferences("envanto_barcode_prefs", MODE_PRIVATE);
            boolean wifiOnly = preferences.getBoolean("wifi_only", true); // Varsayılan WiFi-only
            
            serviceIntent.putExtra(UploadRetryService.EXTRA_WIFI_ONLY, wifiOnly);
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent);
            } else {
                startService(serviceIntent);
            }
            
            android.util.Log.d(TAG, "UploadRetryService başlatıldı - WiFi only: " + wifiOnly);
        } catch (Exception e) {
            // Sessizce devam et
            android.util.Log.e(TAG, "Service başlatma hatası: " + e.getMessage());
        }
        
        // Kayıtlı resimleri listeleyen recycler view'ı ayarla
        setupSavedImagesList();
        
        // İlk açılışta müşteri listesini kontrol et ve gerekirse önbelleğe al
        checkAndUpdateCustomerCache();
    }
    
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
    
    /**
     * Cihaz yetkilendirme başarılı olduğunda çalışır
     */
    private void onDeviceAuthSuccess() {
        // İçeriği göster
        binding.mainContent.setVisibility(View.VISIBLE);
    }
    
    /**
     * Cihaz yetkilendirme başarısız olduğunda çalışır
     */
    private void onDeviceAuthFailure() {
        // İçeriği gizle
        binding.mainContent.setVisibility(View.GONE);
        // Activity zaten kapanacak
    }
    
    /**
     * Cihaz yetkilendirme yükleme başladığında çalışır
     */
    private void onDeviceAuthShowLoading() {
        // Cihaz yetkilendirme kontrolü arka planda sessizce yapılır
        // Progress bar gösterilmez
        android.util.Log.d(TAG, "Cihaz yetkilendirme kontrolü başlatıldı (sessizce)");
    }
    
    /**
     * Cihaz yetkilendirme yükleme bittiğinde çalışır
     */
    private void onDeviceAuthHideLoading() {
        // Cihaz yetkilendirme kontrolü tamamlandı
        // Progress bar zaten gösterilmediği için gizleme işlemi yok
        android.util.Log.d(TAG, "Cihaz yetkilendirme kontrolü tamamlandı (sessizce)");
    }
    
    private void setupAutoRefresh() {
        // Otomatik yenileme için bir Runnable oluştur
        autoRefreshRunnable = new Runnable() {
            @Override
            public void run() {
                if (isActivityActive) {
                    android.util.Log.d(TAG, "Otomatik liste yenilemesi çalışıyor");
                    refreshSavedImagesList();
                    // Kendini tekrar çağır
                    autoRefreshHandler.postDelayed(this, AppConstants.App.AUTO_REFRESH_INTERVAL);
                }
            }
        };
    }
    
    private void startAutoRefresh() {
        isActivityActive = true;
        // Varolan tüm bekleyen görevleri temizle ve yenisini başlat
        autoRefreshHandler.removeCallbacks(autoRefreshRunnable);
        autoRefreshHandler.postDelayed(autoRefreshRunnable, AppConstants.App.AUTO_REFRESH_INTERVAL);
        android.util.Log.d(TAG, "Otomatik yenileme başlatıldı");
    }
    
    private void stopAutoRefresh() {
        isActivityActive = false;
        autoRefreshHandler.removeCallbacks(autoRefreshRunnable);
        android.util.Log.d(TAG, "Otomatik yenileme durduruldu");
    }

    private void setupSavedImagesList() {
        // RecyclerView'ı ayarla - LinearLayoutManager kullan
        binding.savedImagesRecyclerView.setLayoutManager(new LinearLayoutManager(this));
        
        // Kayıtlı resimleri göster
        refreshSavedImagesList();
        
        // Yenileme butonunu gizle
        binding.refreshSavedImagesButton.setVisibility(View.GONE);
    }
    
    private void refreshSavedImagesList() {
        DatabaseHelper dbHelper = new DatabaseHelper(this);
        Cursor cursor = dbHelper.getAllPendingUploads();
        
        // Mevcut scroll pozisyonunu ve expanded states'i koru
        int savedScrollPosition = 0;
        Map<String, Boolean> savedExpandedStates = new HashMap<>();
        
        // Eğer adapter zaten varsa, mevcut durumları kaydet
        RecyclerView.Adapter currentAdapter = binding.savedImagesRecyclerView.getAdapter();
        if (currentAdapter instanceof CustomerImagesAdapter) {
            CustomerImagesAdapter existingAdapter = (CustomerImagesAdapter) currentAdapter;
            
            // Scroll pozisyonunu kaydet
            RecyclerView.LayoutManager layoutManager = binding.savedImagesRecyclerView.getLayoutManager();
            if (layoutManager instanceof LinearLayoutManager) {
                savedScrollPosition = ((LinearLayoutManager) layoutManager).findFirstVisibleItemPosition();
            }
            
            // Expanded states'i al
            savedExpandedStates = existingAdapter.getExpandedStates();
            
            // Mevcut adapter'ı güncelle (yeni adapter oluşturmak yerine)
            existingAdapter.updateCursor(cursor);
            
            // Expanded states'i geri yükle
            existingAdapter.setExpandedStates(savedExpandedStates);
            
            // Scroll pozisyonunu geri yükle
            if (savedScrollPosition > 0) {
                binding.savedImagesRecyclerView.scrollToPosition(savedScrollPosition);
            }
            
        } else {
            // İlk kez adapter oluşturuluyorsa normal akış
            CustomerImagesAdapter adapter = new CustomerImagesAdapter(this, cursor, new CustomerImagesAdapter.OnImageActionListener() {
                @Override
                public void onImageDelete(int id, String imagePath) {
                    // Resim dosyasının varlığını kontrol et
                    File imageFile = new File(imagePath);
                    boolean fileExists = imageFile.exists();

                    // Resim dosyasını silmeye çalış
                    boolean fileDeleted = fileExists ? ImageStorageManager.deleteImage(BarcodeUploadActivity.this, imagePath) : true;
                    
                    // Veritabanından silmeye çalış
                    boolean dbDeleted = dbHelper.deleteImage(id);
                    
                    if (fileDeleted && dbDeleted) {
                        if (fileExists) {
                            Toast.makeText(BarcodeUploadActivity.this, "Resim ve kayıt başarıyla silindi", Toast.LENGTH_SHORT).show();
                        } else {
                            Toast.makeText(BarcodeUploadActivity.this, "Resim kaydı silindi (dosya zaten silinmiş)", Toast.LENGTH_SHORT).show();
                        }
                        refreshSavedImagesList();
                    } else {
                        Toast.makeText(BarcodeUploadActivity.this, "Silme işlemi sırasında hata oluştu", Toast.LENGTH_LONG).show();
                    }
                }
                
                @Override
                public void onImageView(String imagePath) {
                    // Resim görüntüleme işlemi
                    try {
                        File imageFile = new File(imagePath);
                        if (imageFile.exists()) {
                            android.util.Log.d(TAG, "Resim dosyası bulundu: " + imagePath);
                            
                            Intent intent = new Intent();
                            intent.setAction(Intent.ACTION_VIEW);
                            
                            // FileProvider kullanarak güvenli URI oluştur
                            Uri imageUri = FileProvider.getUriForFile(
                                BarcodeUploadActivity.this,
                                "com.envanto.barcode.provider",
                                imageFile
                            );
                            
                            android.util.Log.d(TAG, "FileProvider URI oluşturuldu: " + imageUri.toString());
                            
                            // Görüntüleme uygulamasına geçici okuma izni ver
                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                            intent.setDataAndType(imageUri, "image/*");
                            
                            // Intent'in çözülebilir olduğunu kontrol et
                            if (intent.resolveActivity(getPackageManager()) != null) {
                            startActivity(intent);
                                android.util.Log.d(TAG, "Resim görüntüleme uygulaması başlatıldı");
                            } else {
                                // Hiçbir uygulama bulunamazsa bilgi ver
                                Toast.makeText(BarcodeUploadActivity.this, "Resim görüntülemek için uygun uygulama bulunamadı", Toast.LENGTH_SHORT).show();
                                android.util.Log.w(TAG, "Resim görüntüleme uygulaması bulunamadı");
                            }
                        } else {
                            Toast.makeText(BarcodeUploadActivity.this, "Resim dosyası bulunamadı", Toast.LENGTH_SHORT).show();
                            android.util.Log.w(TAG, "Resim dosyası bulunamadı: " + imagePath);
                        }
                    } catch (IllegalArgumentException e) {
                        // FileProvider hatası
                        Toast.makeText(BarcodeUploadActivity.this, "Dosya erişim hatası: " + e.getMessage(), Toast.LENGTH_SHORT).show();
                        android.util.Log.e(TAG, "FileProvider hatası: " + e.getMessage());
                    } catch (Exception e) {
                        Toast.makeText(BarcodeUploadActivity.this, "Resim açılırken hata: " + e.getMessage(), Toast.LENGTH_SHORT).show();
                        android.util.Log.e(TAG, "Resim görüntüleme hatası: " + e.getMessage());
                    }
                }
                
                @Override
                public void onCustomerDelete(String customerName) {
                    // Müşteriye ait yüklenmiş ve yüklenmemiş resimleri ayrı ayrı işle
                    deleteCustomerUploadedImages(customerName);
                }
            });
            
            binding.savedImagesRecyclerView.setAdapter(adapter);
        }
        
        // Kayıt sayısını başlıkta göster
        int count = cursor != null ? cursor.getCount() : 0;
        binding.savedImagesTitle.setText("Kayıtlı Resimler (" + count + ")");
        
        // Eğer kayıtlı resim yoksa layout'u gizle, varsa göster
        if (count == 0) {
            binding.savedImagesLayout.setVisibility(View.GONE);
        } else {
            binding.savedImagesLayout.setVisibility(View.VISIBLE);
        }
    }
    
    /**
     * Müşteriye ait yüklenmiş resimleri siler.
     * Eğer müşterinin tüm resimleri yüklenmişse, klasörü ve tüm kayıtları siler.
     * Eğer müşterinin yüklenmemiş resimleri varsa, sadece yüklenmiş olanları siler.
     * 
     * @param customerName Müşteri adı
     */
    private void deleteCustomerUploadedImages(String customerName) {
        DatabaseHelper dbHelper = new DatabaseHelper(this);
        
        // Müşteriye ait tüm resimleri getir
        Cursor cursor = dbHelper.getMusteriResimleri(customerName);
        
        if (cursor == null) {
            Toast.makeText(this, "Müşteri resimleri alınamadı", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (cursor.getCount() == 0) {
            Toast.makeText(this, "Müşteriye ait resim bulunamadı", Toast.LENGTH_SHORT).show();
            cursor.close();
            return;
        }
        
        // Yüklenmiş ve yüklenmemiş resimleri ayır
        List<Integer> uploadedImageIds = new ArrayList<>();
        List<String> uploadedImagePaths = new ArrayList<>();
        List<Integer> pendingImageIds = new ArrayList<>();
        List<String> pendingImagePaths = new ArrayList<>();
        
        int idIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_ID);
        int pathIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_RESIM_YOLU);
        int uploadedIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_YUKLENDI);
        
        cursor.moveToFirst();
        do {
            int id = cursor.getInt(idIndex);
            String path = cursor.getString(pathIndex);
            boolean isUploaded = cursor.getInt(uploadedIndex) == 1;
            
            if (isUploaded) {
                uploadedImageIds.add(id);
                uploadedImagePaths.add(path);
            } else {
                pendingImageIds.add(id);
                pendingImagePaths.add(path);
            }
        } while (cursor.moveToNext());
        
        cursor.close();
        
        // İstatistikleri göster
        int totalImages = uploadedImageIds.size() + pendingImageIds.size();
        int uploadedImages = uploadedImageIds.size();
        int pendingImages = pendingImageIds.size();
        
        android.util.Log.d(TAG, "Müşteri: " + customerName);
        android.util.Log.d(TAG, "Toplam resim: " + totalImages);
        android.util.Log.d(TAG, "Yüklenmiş resim: " + uploadedImages);
        android.util.Log.d(TAG, "Bekleyen resim: " + pendingImages);
        
        // Eğer bekleyen resim yoksa, tüm resimleri ve klasörü sil
        if (pendingImages == 0 && uploadedImages > 0) {
            // Tüm resimleri sil
            for (String path : uploadedImagePaths) {
                File file = new File(path);
                if (file.exists()) {
                    boolean deleted = file.delete();
                    android.util.Log.d(TAG, "Resim silindi: " + path + " - " + deleted);
                }
            }
            
            // Veritabanından tüm kayıtları sil
            boolean dbDeleted = dbHelper.deleteMusteriResimleri(customerName);
            
            // Müşteri klasörünü sil
            String customerDir = getCustomerDirectory(customerName);
            if (customerDir != null) {
                File directory = new File(customerDir);
                if (directory.exists()) {
                    boolean dirDeleted = deleteDirectory(directory);
                    android.util.Log.d(TAG, "Klasör silindi: " + customerDir + " - " + dirDeleted);
                }
            }
            
            Toast.makeText(this, customerName + " müşterisine ait tüm resimler ve klasör silindi", Toast.LENGTH_LONG).show();
        } 
        // Bekleyen resimler varsa, sadece yüklenmiş olanları sil
        else if (uploadedImages > 0) {
            int deletedCount = 0;
            
            // Sadece yüklenmiş resimleri sil
            for (int i = 0; i < uploadedImageIds.size(); i++) {
                int id = uploadedImageIds.get(i);
                String path = uploadedImagePaths.get(i);
                
                // Dosyayı sil
                File file = new File(path);
                if (file.exists()) {
                    boolean fileDeleted = file.delete();
                    android.util.Log.d(TAG, "Resim silindi: " + path + " - " + fileDeleted);
                }
                
                // Veritabanından kaydı sil
                boolean dbDeleted = dbHelper.deleteImage(id);
                
                if (dbDeleted) {
                    deletedCount++;
                }
            }
            
            Toast.makeText(this, customerName + " müşterisine ait " + deletedCount + " yüklenmiş resim silindi.\n" +
                          pendingImages + " adet yüklenmeyi bekleyen resim korundu.", Toast.LENGTH_LONG).show();
        } else {
            Toast.makeText(this, customerName + " müşterisine ait yüklenmiş resim bulunamadı", Toast.LENGTH_SHORT).show();
        }
        
        // Listeyi yenile
        refreshSavedImagesList();
    }
    
    /**
     * Müşteri resimleri için klasör yolunu döndürür
     */
    private String getCustomerDirectory(String customerName) {
        try {
            File picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
            File appDir = new File(picturesDir, "EnvantoBarkod");
            File customerDir = new File(appDir, customerName);
            return customerDir.getAbsolutePath();
        } catch (Exception e) {
            android.util.Log.e(TAG, "Müşteri klasörü alınamadı: " + e.getMessage());
            return null;
        }
    }
    
    /**
     * Klasör ve içeriğini siler
     */
    private boolean deleteDirectory(File directory) {
        if (directory.exists()) {
            File[] files = directory.listFiles();
            if (files != null) {
                for (File file : files) {
                    if (file.isDirectory()) {
                        deleteDirectory(file);
                    } else {
                        file.delete();
                    }
                }
            }
        }
        return directory.delete();
    }

    private void setupCustomerSearch() {
        customerAdapter = new CustomerAdapter();
        autoCompleteTextView = binding.customerSearchAutoComplete;
        autoCompleteTextView.setAdapter(customerAdapter);

        autoCompleteTextView.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                String query = s.toString().trim();
                if (query.length() >= 2) {
                    try {
                        String encodedQuery = URLEncoder.encode(query, StandardCharsets.UTF_8.toString())
                            .replace("+", "%20");
                        searchCustomers(encodedQuery);
                    } catch (UnsupportedEncodingException e) {
                        e.printStackTrace();
                        searchCustomers(query);
                    }
                }
                binding.imageUploadLayout.setVisibility(View.GONE);
            }

            @Override
            public void afterTextChanged(Editable s) {}
        });

        autoCompleteTextView.setOnItemClickListener((parent, view, position, id) -> {
            selectedCustomer = currentCustomers.get(position);
            if (selectedCustomer != null) {
                // Dropdown'ı zorla kapat
                forceCloseDropdown();
                
                // UI'ı güncelle
                binding.customerSearchLayout.setVisibility(View.GONE);
                binding.selectedCustomerLayout.setVisibility(View.VISIBLE);
                binding.selectedCustomerName.setText(selectedCustomer.getName());
                binding.imageUploadLayout.setVisibility(View.VISIBLE);
            }
        });

        binding.clearCustomerButton.setOnClickListener(v -> {
            selectedCustomer = null;
            binding.customerSearchLayout.setVisibility(View.VISIBLE);
            binding.selectedCustomerLayout.setVisibility(View.GONE);
            binding.imageUploadLayout.setVisibility(View.GONE);
            autoCompleteTextView.setText("");
            currentCustomers.clear();
            customerAdapter.notifyDataSetChanged();
            forceCloseDropdown();
        });
    }

    private void setupImageHandling() {
        // Galeri için launcher - Resimler direk kaydedilecek
        imagePickerLauncher = registerForActivityResult(
            new ActivityResultContracts.StartActivityForResult(),
            result -> {
                if (result.getResultCode() == Activity.RESULT_OK) {
                    Intent data = result.getData();
                    if (data != null) {
                        if (selectedCustomer == null) {
                            Toast.makeText(this, "Lütfen önce müşteri seçiniz", Toast.LENGTH_SHORT).show();
                            return;
                        }
                        
                        List<Uri> selectedUris = new ArrayList<>();
                        if (data.getClipData() != null) {
                            int count = data.getClipData().getItemCount();
                            for (int i = 0; i < count; i++) {
                                Uri imageUri = data.getClipData().getItemAt(i).getUri();
                                selectedUris.add(imageUri);
                            }
                        } else if (data.getData() != null) {
                            Uri imageUri = data.getData();
                            selectedUris.add(imageUri);
                        }
                        
                        // Seçilen resimleri direk kaydet
                        if (!selectedUris.isEmpty()) {
                            directSaveImages(selectedUris);
                        }
                    }
                }
            }
        );

        // YORUM: Eski cihaz kamerası launcher - artık fastCameraLauncher kullanılıyor
        // Kamera için launcher - Resim direk kaydedilecek
        /*
        cameraLauncher = registerForActivityResult(
            new ActivityResultContracts.TakePicture(),
            success -> {
                if (success && currentPhotoUri != null) {
                    // Çekilen resmi direk kaydet
                    directSaveImage(currentPhotoUri);
                }
            }
        );
        */

        // Hızlı kamera için launcher
        fastCameraLauncher = registerForActivityResult(
            new ActivityResultContracts.StartActivityForResult(),
            result -> {
                if (result.getResultCode() == Activity.RESULT_OK) {
                    Intent data = result.getData();
                    if (data != null) {
                        String imageUriString = data.getStringExtra(FastCameraActivity.EXTRA_IMAGE_URI);
                        if (imageUriString != null) {
                            Uri imageUri = Uri.parse(imageUriString);
                            // Çekilen resmi direk kaydet
                            directSaveImage(imageUri);
                        }
                    }
                }
            }
        );

        // Galeri butonu
        binding.selectImagesButton.setOnClickListener(v -> {
            if (selectedCustomer == null) {
                Toast.makeText(this, "Lütfen önce müşteri seçiniz", Toast.LENGTH_SHORT).show();
                return;
            }
            Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
            intent.setType("image/*");
            intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
            imagePickerLauncher.launch(intent);
        });

        // Kamera butonu - Hızlı kamera kullan (eski: startCamera() çağrısı)
        binding.takePictureButton.setOnClickListener(v -> {
            if (selectedCustomer == null) {
                Toast.makeText(this, "Lütfen önce müşteri seçiniz", Toast.LENGTH_SHORT).show();
                return;
            }
            startFastCamera(); // YORUM: Eski kod: startCamera();
        });
    }

    /**
     * Hızlı kamera aktivitesini başlat
     */
    private void startFastCamera() {
        try {
            android.util.Log.d(TAG, "startFastCamera() çağrıldı");
            
            if (selectedCustomer == null) {
                Toast.makeText(this, "Lütfen önce müşteri seçiniz", Toast.LENGTH_SHORT).show();
                android.util.Log.w(TAG, "Müşteri seçilmemiş");
                return;
            }
            
            android.util.Log.d(TAG, "Seçili müşteri: " + selectedCustomer.getName());
            
            // Kamera izni kontrolü
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                android.util.Log.w(TAG, "Kamera izni yok");
                new MaterialAlertDialogBuilder(this)
                    .setTitle("Kamera İzni Gerekli")
                    .setMessage("Kamera kullanabilmek için izin vermeniz gerekiyor. Ayarlar'dan kamera iznini etkinleştirin.")
                    .setPositiveButton("Ayarlar", (dialog, which) -> {
                        try {
                            Intent intent = new Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                            Uri uri = Uri.fromParts("package", getPackageName(), null);
                            intent.setData(uri);
                            startActivity(intent);
                        } catch (Exception e) {
                            android.util.Log.e(TAG, "Ayarlar açma hatası: " + e.getMessage());
                            Toast.makeText(this, "Ayarlar açılamadı", Toast.LENGTH_SHORT).show();
                        }
                    })
                    .setNegativeButton("İptal", null)
                    .show();
                return;
            }
            
            // Hızlı kamera aktivitesini başlat
            Intent fastCameraIntent = new Intent(this, FastCameraActivity.class);
            fastCameraLauncher.launch(fastCameraIntent);
            android.util.Log.d(TAG, "Hızlı kamera başlatıldı");
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "startFastCamera genel hatası: " + e.getMessage());
            e.printStackTrace();
            Toast.makeText(this, "Hızlı kamera başlatma hatası: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    /**
     * YORUM: Eski cihaz kamerası metodu - artık startFastCamera() kullanılıyor
     * Bu kod ileride tekrar kullanılmak üzere yorum satırı olarak korunuyor
     */
    /*
    private void startCamera() {
        try {
            android.util.Log.d(TAG, "startCamera() çağrıldı");
            
            if (selectedCustomer == null) {
                Toast.makeText(this, "Lütfen önce müşteri seçiniz", Toast.LENGTH_SHORT).show();
                android.util.Log.w(TAG, "Müşteri seçilmemiş");
                return;
            }
            
            android.util.Log.d(TAG, "Seçili müşteri: " + selectedCustomer.getName());
            
            // Kamera izni kontrolü - eğer izin yoksa sadece uyarı ver, activity'yi kapatma
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                android.util.Log.w(TAG, "Kamera izni yok");
                new MaterialAlertDialogBuilder(this)
                    .setTitle("Kamera İzni Gerekli")
                    .setMessage("Kamera kullanabilmek için izin vermeniz gerekiyor. Ayarlar'dan kamera iznini etkinleştirin.")
                    .setPositiveButton("Ayarlar", (dialog, which) -> {
                        try {
                            // Uygulama ayarlarına yönlendir
                            Intent intent = new Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                            Uri uri = Uri.fromParts("package", getPackageName(), null);
                            intent.setData(uri);
                            startActivity(intent);
                        } catch (Exception e) {
                            android.util.Log.e(TAG, "Ayarlar açma hatası: " + e.getMessage());
                            Toast.makeText(this, "Ayarlar açılamadı", Toast.LENGTH_SHORT).show();
                        }
                    })
                    .setNegativeButton("İptal", null)
                    .show();
                return;
            }
            
            android.util.Log.d(TAG, "Kamera izni var, dosya oluşturuluyor");
            
            File photoFile = createImageFile();
            if (photoFile != null) {
                android.util.Log.d(TAG, "Foto dosyası oluşturuldu: " + photoFile.getAbsolutePath());
                
                try {
                    currentPhotoUri = FileProvider.getUriForFile(
                        this,
                        "com.envanto.barcode.provider",
                        photoFile
                    );
                    android.util.Log.d(TAG, "FileProvider URI oluşturuldu: " + currentPhotoUri.toString());
                    
                    // Kamera ayarlarını yapılandır (arka kamerayı kullan)
                    Intent takePictureIntent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
                    takePictureIntent.putExtra(MediaStore.EXTRA_OUTPUT, currentPhotoUri);
                    
                    // Arka kamerayı kullanmak için lens seçimi - Android 11+ için
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        takePictureIntent.putExtra("android.intent.extras.CAMERA_FACING", android.hardware.Camera.CameraInfo.CAMERA_FACING_BACK);
                        takePictureIntent.putExtra("android.intent.extras.LENS_FACING_FRONT", 0);
                        takePictureIntent.putExtra("android.intent.extra.USE_FRONT_CAMERA", false);
                    } else {
                        // Eski Android sürümleri için
                        takePictureIntent.putExtra("android.intent.extras.CAMERA_FACING", 0); // 0=arka, 1=ön
                    }
                    
                    // Kamera açma intent'ini başlat
                    try {
                        // Önce doğrudan intent kullanmayı dene
                        if (takePictureIntent.resolveActivity(getPackageManager()) != null) {
                            startActivityForResult(takePictureIntent, 123); // 123 = kamera request code
                            android.util.Log.d(TAG, "Doğrudan kamera intent'i başlatıldı");
                        } else {
                            // Intent bulunamazsa launcher'ı dene
                            cameraLauncher.launch(currentPhotoUri);
                            android.util.Log.d(TAG, "Kamera launcher başlatıldı");
                        }
                    } catch (Exception e) {
                        android.util.Log.e(TAG, "Kamera başlatma hatası: " + e.getMessage());
                        Toast.makeText(this, "Kamera başlatılamadı: " + e.getMessage(), Toast.LENGTH_SHORT).show();
                    }
                } catch (Exception e) {
                    android.util.Log.e(TAG, "FileProvider URI oluşturma hatası: " + e.getMessage());
                    e.printStackTrace();
                    Toast.makeText(this, "Kamera başlatma hatası: " + e.getMessage(), Toast.LENGTH_LONG).show();
                }
            } else {
                android.util.Log.e(TAG, "Foto dosyası oluşturulamadı");
                Toast.makeText(this, "Resim dosyası oluşturulamadı", Toast.LENGTH_SHORT).show();
            }
        } catch (Exception e) {
            android.util.Log.e(TAG, "startCamera genel hatası: " + e.getMessage());
            e.printStackTrace();
            Toast.makeText(this, "Kamera başlatma hatası: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }
    */

    private File createImageFile() {
        try {
            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
            String imageFileName = "CAMERA_" + timeStamp;
            
            // GÜNCELLEME: Geçici dosya için cache directory kullan
            File cacheDir = getCacheDir();
            File tempImagesDir = new File(cacheDir, "temp_camera");
            
            // Dizin yoksa oluştur ve izinlerini kontrol et
            if (!tempImagesDir.exists()) {
                boolean created = tempImagesDir.mkdirs();
                if (!created) {
                    android.util.Log.e(TAG, "Temp dizini oluşturulamadı");
                    // Ana cache dizinini kullan
                    tempImagesDir = getCacheDir();
                }
            }
            
            // Dizin yazılabilir mi kontrol et
            if (!tempImagesDir.canWrite()) {
                android.util.Log.e(TAG, "Temp dizinine yazma izni yok");
                // Ana cache dizinini kullan
                tempImagesDir = getCacheDir();
            }
            
            android.util.Log.d(TAG, "Temporary camera storage: " + tempImagesDir.getAbsolutePath());
            
            File imageFile = File.createTempFile(imageFileName, ".jpg", tempImagesDir);
            android.util.Log.d(TAG, "Created image file: " + imageFile.getAbsolutePath());
            return imageFile;
            
        } catch (IOException e) {
            android.util.Log.e(TAG, "createImageFile IOException: " + e.getMessage());
            e.printStackTrace();
            return null;
        } catch (Exception e) {
            android.util.Log.e(TAG, "createImageFile Exception: " + e.getMessage());
            e.printStackTrace();
            return null;
        }
    }
    
    // GÜNCELLEME: Geçici kamera dosyalarını temizle
    private void cleanupTempFiles() {
        try {
            File cacheDir = getCacheDir();
            File tempImagesDir = new File(cacheDir, "temp_camera");
            if (tempImagesDir.exists()) {
                File[] files = tempImagesDir.listFiles();
                if (files != null) {
                    for (File file : files) {
                        if (file.isFile()) {
                            file.delete();
                        }
                    }
                }
            }
            android.util.Log.d(TAG, "Geçici kamera dosyaları temizlendi");
        } catch (Exception e) {
            android.util.Log.e(TAG, "Geçici dosya temizleme hatası: " + e.getMessage());
        }
    }

    // GÜNCELLEME: Tek resim için direk kayıt fonksiyonu
    private void directSaveImage(Uri imageUri) {
        if (selectedCustomer == null) {
            Toast.makeText(this, "Müşteri seçimi yapılmamış", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Progress göster
        binding.progressBar.setVisibility(View.VISIBLE);
        binding.progressText.setText("Resim kaydediliyor...");
        
        new Thread(() -> {
            try {
                // Cihaz kimliğini al
                String deviceId = DeviceIdentifier.getUniqueDeviceId(this);
                
                // Veritabanından cihaz sahibi bilgisini çek
                DatabaseHelper dbHelper = new DatabaseHelper(this);
                String deviceOwner = dbHelper.getCihazSahibi(deviceId);
                
                // Eğer cihaz sahibi bilgisi yoksa, varsayılan değer olarak cihaz bilgisini kullan
                if (deviceOwner == null || deviceOwner.isEmpty()) {
                    deviceOwner = DeviceIdentifier.getReadableDeviceInfo(this);
                }
                
                // Resmi cihaza kaydet - Kamera kaynaklı olarak işaretle (imageUri currentPhotoUri ise kameradan)
                boolean isGallery = currentPhotoUri == null || !currentPhotoUri.equals(imageUri);
                String savedImagePath = ImageStorageManager.saveImage(
                    this, 
                    imageUri, 
                    selectedCustomer.getName(),
                    isGallery
                );
                
                if (savedImagePath != null) {
                    // Veritabanına kaydet - cihaz sahibi bilgisini kullan
                    long result = dbHelper.addBarkodResim(
                        selectedCustomer.getName(),
                        savedImagePath,
                        deviceOwner
                    );
                    
                    runOnUiThread(() -> {
                        binding.progressBar.setVisibility(View.GONE);
                        binding.progressText.setText("");
                        
                        if (result != -1) {
                            Toast.makeText(this, "✅ Resim başarıyla kaydedildi", Toast.LENGTH_SHORT).show();
                            refreshSavedImagesList();
                            
                            // Başarılı kayıt sonrası cihaz yetkilendirmesini kontrol et
                            checkDeviceAuthorization();
                            
                            // Otomatik olarak hızlı kamerayı tekrar başlat (eski: startCamera())
                            startFastCamera(); // YORUM: Eski kod: startCamera();
                        } else {
                            Toast.makeText(this, "❌ Veritabanı kayıt hatası", Toast.LENGTH_LONG).show();
                        }
                    });
                } else {
                    runOnUiThread(() -> {
                        binding.progressBar.setVisibility(View.GONE);
                        binding.progressText.setText("");
                        Toast.makeText(this, "❌ Resim kaydetme hatası", Toast.LENGTH_LONG).show();
                    });
                }
            } catch (Exception e) {
                runOnUiThread(() -> {
                    binding.progressBar.setVisibility(View.GONE);
                    binding.progressText.setText("");
                    Toast.makeText(this, "❌ Hata: " + e.getMessage(), Toast.LENGTH_LONG).show();
                });
            }
        }).start();
    }
    
    // GÜNCELLEME: Çoklu resim için direk kayıt fonksiyonu
    private void directSaveImages(List<Uri> imageUris) {
        if (selectedCustomer == null) {
            Toast.makeText(this, "Müşteri seçimi yapılmamış", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Progress göster
        binding.progressBar.setVisibility(View.VISIBLE);
        updateProgress(0, imageUris.size());
        
        new Thread(() -> {
            // Cihaz kimliğini al
            String deviceId = DeviceIdentifier.getUniqueDeviceId(this);
            
            // Veritabanından cihaz sahibi bilgisini çek
            DatabaseHelper dbHelper = new DatabaseHelper(this);
            String deviceOwner = dbHelper.getCihazSahibi(deviceId);
            
            // Eğer cihaz sahibi bilgisi yoksa, varsayılan değer olarak cihaz bilgisini kullan
            if (deviceOwner == null || deviceOwner.isEmpty()) {
                deviceOwner = DeviceIdentifier.getReadableDeviceInfo(this);
            }
            
            int totalImages = imageUris.size();
            int successCount = 0;
            int errorCount = 0;
            
            for (int i = 0; i < imageUris.size(); i++) {
                Uri imageUri = imageUris.get(i);
                
                try {
                    // Resmi cihaza kaydet - Gallery için isGallery=true
                    String savedImagePath = ImageStorageManager.saveImage(
                        this, 
                        imageUri, 
                        selectedCustomer.getName(),
                        true // Çoklu seçim her zaman galeriden gelir
                    );
                    
                    if (savedImagePath != null) {
                        // Veritabanına kaydet - cihaz sahibi bilgisini kullan
                        long result = dbHelper.addBarkodResim(
                            selectedCustomer.getName(),
                            savedImagePath,
                            deviceOwner
                        );
                        
                        if (result != -1) {
                            successCount++;
                        } else {
                            errorCount++;
                        }
                    } else {
                        errorCount++;
                    }
                } catch (Exception e) {
                    errorCount++;
                }
                
                // Progress güncelle
                final int currentProgress = i + 1;
                updateProgress(currentProgress, totalImages);
            }
            
            final int finalSuccessCount = successCount;
            final int finalErrorCount = errorCount;
            
            runOnUiThread(() -> {
                binding.progressBar.setVisibility(View.GONE);
                binding.progressText.setText("");
                
                if (finalErrorCount == 0) {
                    Toast.makeText(this, "✅ " + finalSuccessCount + " resim başarıyla kaydedildi", Toast.LENGTH_SHORT).show();
                } else {
                    Toast.makeText(this, 
                        "⚠️ " + finalSuccessCount + " başarılı, " + finalErrorCount + " hatalı", 
                        Toast.LENGTH_LONG).show();
                }
                
                refreshSavedImagesList();
                
                // Başarılı kayıt sonrası cihaz yetkilendirmesini kontrol et
                if (finalSuccessCount > 0) {
                    checkDeviceAuthorization();
                }
            });
        }).start();
    }

    private void showContinueDialog() {
        new MaterialAlertDialogBuilder(this)
            .setTitle("📷 Resim Çekimi")
            .setMessage("Başka resim çekmek istiyor musunuz?")
            .setPositiveButton("📷 Devam Et", (dialog, which) -> startFastCamera()) // YORUM: Eski kod: startCamera()
            .setNegativeButton("✅ Bitir", (dialog, which) -> dialog.dismiss())
            .show();
    }

    private void updateProgress(int current, int total) {
        runOnUiThread(() -> {
            // Progress bar'ın max değerini ayarla
            binding.progressBar.setMax(total);
            // Mevcut progress'i ayarla
            binding.progressBar.setProgress(current);
            // Text'i güncelle
            binding.progressText.setText(String.format("%d/%d", current, total));
        });
    }

    private void updateServerUploadProgress(int current, int total) {
        runOnUiThread(() -> {
            int progressPercent = total > 0 ? (int)((float)current / total * 100) : 0;
            binding.serverUploadProgressBar.setProgress(progressPercent);
            
            String progressText;
            if (total > 0) {
                progressText = String.format("📤 Sunucuya gönderiliyor: %d/%d (%d%%)", current, total, progressPercent);
            } else {
                progressText = "📤 Hazırlanıyor...";
            }
            binding.serverUploadProgressText.setText(progressText);
        });
    }

    private void forceCloseDropdown() {
        // 1. Dropdown'ı kapat
        autoCompleteTextView.dismissDropDown();
        
        // 2. Odağı kaldır
        autoCompleteTextView.clearFocus();
        
        // 3. Listeyi temizle
        currentCustomers.clear();
        customerAdapter.notifyDataSetChanged();
        
        // 4. Klavyeyi gizle
        InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
        imm.hideSoftInputFromWindow(autoCompleteTextView.getWindowToken(), 0);
        
        // 5. Activity'nin odağını al
        View currentFocus = getCurrentFocus();
        if (currentFocus != null) {
            currentFocus.clearFocus();
        }
        
        // 6. Soft input modu güncelle
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN);
    }

    private class CustomerAdapter extends BaseAdapter implements Filterable {
        @Override
        public int getCount() {
            return currentCustomers.size();
        }

        @Override
        public Customer getItem(int position) {
            return currentCustomers.get(position);
        }

        @Override
        public long getItemId(int position) {
            return position;
        }

        @Override
        public View getView(int position, View convertView, ViewGroup parent) {
            if (convertView == null) {
                convertView = LayoutInflater.from(BarcodeUploadActivity.this)
                    .inflate(android.R.layout.simple_dropdown_item_1line, parent, false);
            }

            TextView textView = (TextView) convertView;
            Customer customer = getItem(position);
            textView.setText(customer.getName());
            textView.setPadding(32, 32, 32, 32);

            return convertView;
        }

        @Override
        public Filter getFilter() {
            return new Filter() {
                @Override
                protected FilterResults performFiltering(CharSequence constraint) {
                    FilterResults results = new FilterResults();
                    results.values = currentCustomers;
                    results.count = currentCustomers.size();
                    return results;
                }

                @Override
                protected void publishResults(CharSequence constraint, FilterResults results) {
                    notifyDataSetChanged();
                }
            };
        }
    }
    
    private void searchCustomers(String query) {
        android.util.Log.d(TAG, "Müşteri arama başlatıldı: " + query);
        
        // Önce anında yerel aramayı başlat (kullanıcı deneyimi için)
        searchOfflineCustomers(query);
        
        // Paralel olarak sunucu araması da yap (eğer İnternet varsa)
        if (NetworkUtils.isNetworkAvailable(this)) {
            android.util.Log.d(TAG, "Paralel sunucu araması başlatılıyor: " + query);
            
            // Hızlı API ile sunucu araması (3s timeout)
            ApiClient.getInstance().getQuickApiService().searchCustomers("search", query)
            .enqueue(new Callback<List<Customer>>() {
                @Override
                public void onResponse(Call<List<Customer>> call, Response<List<Customer>> response) {
                    if (response.isSuccessful() && response.body() != null) {
                            List<Customer> serverCustomers = response.body();
                        
                            if (!serverCustomers.isEmpty()) {
                        handler.post(() -> {
                                    android.util.Log.d(TAG, "Sunucu araması başarılı, sonuçlar güncelleniyor");
                                    
                                    // Sunucu sonuçları ile yerel sonuçları birleştir
                            currentCustomers.clear();
                                    currentCustomers.addAll(serverCustomers);
                            customerAdapter.notifyDataSetChanged();
                            
                                    if (autoCompleteTextView.hasFocus()) {
                                autoCompleteTextView.showDropDown();
                            }
                        });
                    } else {
                                android.util.Log.d(TAG, "Sunucu araması boş sonuç döndü, yerel sonuçlar korunuyor");
                            }
                        } else {
                            android.util.Log.w(TAG, "Sunucu araması başarısız, yerel sonuçlar korunuyor: " + response.code());
                    }
                }

                @Override
                public void onFailure(Call<List<Customer>> call, Throwable t) {
                        android.util.Log.w(TAG, "Sunucu araması başarısız (3s timeout), yerel sonuçlar korunuyor: " + t.getMessage());
                        // Sunucu arası başarısız olsa da yerel sonuçlar zaten gösteriliyor
                }
            });
        } else {
            android.util.Log.d(TAG, "İnternet bağlantısı yok, sadece yerel arama yapıldı");
        }
    }
    
    private void searchOfflineCustomers(String query) {
        android.util.Log.d(TAG, "Yerel veritabanından müşteri aranıyor: " + query);
        new Thread(() -> {
            DatabaseHelper dbHelper = new DatabaseHelper(this);
            List<Customer> offlineCustomers = dbHelper.searchCachedMusteriler(query);
            
            handler.post(() -> {
                android.util.Log.d(TAG, "Yerel arama sonucu: " + offlineCustomers.size() + " müşteri bulundu");
                
                if (!offlineCustomers.isEmpty()) {
                    currentCustomers.clear();
                    currentCustomers.addAll(offlineCustomers);
                    customerAdapter.notifyDataSetChanged();
                    
                    if (autoCompleteTextView.hasFocus()) {
                        autoCompleteTextView.showDropDown();
                    }
                } else {
                    // Yerel aramada sonuç bulunamadı
                    currentCustomers.clear();
                    customerAdapter.notifyDataSetChanged();
                    autoCompleteTextView.dismissDropDown();
                }
            });
        }).start();
    }
    
    // Tüm müşteri listesini çek ve önbelleğe al
    private void fetchAndCacheAllCustomers() {
        // İnternet bağlantısı kontrolü
        if (!NetworkUtils.isNetworkAvailable(this)) {
            android.util.Log.d(TAG, "İnternet bağlantısı yok, müşteri listesi güncellenemedi");
            return;
        }
        
        // Progress bar'ı göster
        runOnUiThread(() -> {
            binding.progressBar.setVisibility(View.VISIBLE);
            binding.progressText.setVisibility(View.VISIBLE);
            binding.progressText.setText("Müşteri listesi getiriliyor...");
            binding.progressBar.setMax(100);
            binding.progressBar.setProgress(0);
        });
        
        android.util.Log.d(TAG, "Tüm müşteri listesi getiriliyor ve önbelleğe alınıyor (3s timeout ile)");
        ApiClient.getInstance().getQuickApiService().getCustomers("getall")
            .enqueue(new Callback<List<Customer>>() {
                @Override
                public void onResponse(Call<List<Customer>> call, Response<List<Customer>> response) {
                    if (response.isSuccessful() && response.body() != null) {
                        List<Customer> customers = response.body();
                        android.util.Log.d(TAG, customers.size() + " müşteri alındı, önbelleğe kaydediliyor");
                        
                        // Progress bar'ı güncelle - indirme tamamlandı
                        runOnUiThread(() -> {
                            binding.progressBar.setProgress(50);
                            binding.progressText.setText("Müşteri listesi kaydediliyor...");
                        });
                        
                        // Arka planda önbelleğe kaydet
                        new Thread(() -> {
                            DatabaseHelper dbHelper = new DatabaseHelper(BarcodeUploadActivity.this);
                            
                            // Müşterileri parça parça kaydet (progress göstermek için)
                            int totalCustomers = customers.size();
                            for (int i = 0; i < totalCustomers; i++) {
                                final int currentIndex = i;
                                
                                // Her 50 müşteride bir progress güncelle
                                if (i % 50 == 0 || i == totalCustomers - 1) {
                                    runOnUiThread(() -> {
                                        int progress = 50 + (int)((float)(currentIndex + 1) / totalCustomers * 50);
                                        binding.progressBar.setProgress(progress);
                                        binding.progressText.setText(String.format("Kaydediliyor: %d/%d", currentIndex + 1, totalCustomers));
                                    });
                                }
                                
                                try {
                                    Thread.sleep(1); // Kısa bekleme - progress görmek için
                                } catch (InterruptedException e) {
                                    break;
                                }
                            }
                            
                            // Toplu kaydetme
                            dbHelper.cacheMusteriler(customers);
                            
                            // Başarılı güncelleme sonrası zamanı kaydet
                            SharedPreferences prefs = AppConstants.Prefs.getPrefs(BarcodeUploadActivity.this);
                            prefs.edit().putLong(AppConstants.Prefs.LAST_CUSTOMER_CACHE_UPDATE, System.currentTimeMillis()).apply();
                            android.util.Log.d(TAG, "Müşteri listesi başarıyla güncellendi ve zaman kaydedildi");
                            
                            // Progress bar'ı gizle
                            runOnUiThread(() -> {
                                binding.progressBar.setProgress(100);
                                binding.progressText.setText("Tamamlandı!");
                                
                                // 1 saniye sonra gizle
                                handler.postDelayed(() -> {
                                    binding.progressBar.setVisibility(View.GONE);
                                    binding.progressText.setVisibility(View.GONE);
                                }, AppConstants.Timing.SHORT_DELAY);
                            });
                        }).start();
                    } else {
                        android.util.Log.e(TAG, "Müşteri listesi alınamadı: " + response.code());
                        // Progress bar'ı gizle
                        runOnUiThread(() -> {
                            binding.progressBar.setVisibility(View.GONE);
                            binding.progressText.setVisibility(View.GONE);
                        });
                    }
                }

                @Override
                public void onFailure(Call<List<Customer>> call, Throwable t) {
                    android.util.Log.e(TAG, "Müşteri listesi alma hatası (3s timeout): " + t.getMessage());
                    // Progress bar'ı gizle
                    runOnUiThread(() -> {
                        binding.progressBar.setVisibility(View.GONE);
                        binding.progressText.setVisibility(View.GONE);
                    });
                }
            });
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        if (item.getItemId() == android.R.id.home) {
            onBackPressed();
            return true;
        } else if (item.getItemId() == R.id.action_debug_db) {
            showMusterilerDebugDialog();
            return true;
        }
        return super.onOptionsItemSelected(item);
    }
    
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // XML menüsünü inflate et
        getMenuInflater().inflate(R.menu.menu_barcode_upload, menu);
        return true;
    }
    
    // Müşteri tablosunu kontrol etmek için debug dialog göster
    private void showMusterilerDebugDialog() {
        new Thread(() -> {
            DatabaseHelper dbHelper = new DatabaseHelper(this);
            int count = dbHelper.getCachedMusteriCount();
            List<String> musteriler = new ArrayList<>();
            
            SQLiteDatabase db = dbHelper.getReadableDatabase();
            Cursor cursor = db.query(
                DatabaseHelper.TABLE_MUSTERILER,
                new String[]{DatabaseHelper.COLUMN_MUSTERI},
                null, null, null, null, 
                DatabaseHelper.COLUMN_MUSTERI + " ASC"
            );
            
            if (cursor.moveToFirst()) {
                do {
                    String musteriAdi = cursor.getString(0);
                    musteriler.add(musteriAdi);
                } while (cursor.moveToNext());
            }
            
            cursor.close();
            db.close();
            
            // UI thread'inde dialog göster
            runOnUiThread(() -> {
                AlertDialog.Builder builder = new AlertDialog.Builder(this);
                builder.setTitle("Müşteri Tablosu (" + count + " kayıt)");
                
                if (musteriler.isEmpty()) {
                    builder.setMessage("Müşteri tablosunda hiç kayıt yok.");
                } else {
                    builder.setItems(musteriler.toArray(new String[0]), null);
                }
                
                builder.setPositiveButton("Tamam", null);
                builder.show();
            });
        }).start();
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        // Ekran her görüntülendiğinde kayıtlı resimleri yenile
        refreshSavedImagesList();
        // Otomatik yenilemeyi başlat
        startAutoRefresh();
        
        // Cihaz yetkilendirmesini her açılışta kontrol et
        checkDeviceAuthorization();
        
        // Menüyü yenile
        invalidateOptionsMenu();
    }
    
    // Müşteri önbelleğini kontrol et ve gerekirse güncelle
    private void checkAndUpdateCustomerCache() {
        new Thread(() -> {
            // Veritabanındaki müşteri sayısını kontrol et
            DatabaseHelper dbHelper = new DatabaseHelper(this);
            int cachedCustomerCount = dbHelper.getCachedMusteriCount();
            android.util.Log.d(TAG, "Veritabanında " + cachedCustomerCount + " müşteri var");
            
            if (cachedCustomerCount == 0) {
                // Hiç müşteri yoksa ilk kez yükle
                android.util.Log.d(TAG, "Hiç müşteri yok, ilk kez yükleniyor...");
                handler.post(() -> fetchAndCacheAllCustomers());
            } else {
                // Belirli aralıklarla güncelle (örn: günde bir kez)
                // Burada basit bir kontrol yapabiliriz
                // Gerçek uygulamada son güncelleme zamanını kontrol edebilirsiniz
                
                // Son başarılı yükleme zamanını kontrol et
                SharedPreferences prefs = AppConstants.Prefs.getPrefs(this);
                long lastCacheUpdateTime = prefs.getLong(AppConstants.Prefs.LAST_CUSTOMER_CACHE_UPDATE, 0);
                long currentTime = System.currentTimeMillis();
                
                android.util.Log.d(TAG, "Son güncelleme: " + new java.util.Date(lastCacheUpdateTime));
                android.util.Log.d(TAG, "Şu anki zaman: " + new java.util.Date(currentTime));
                android.util.Log.d(TAG, "Geçen süre: " + ((currentTime - lastCacheUpdateTime) / 1000 / 60) + " dakika");
                
                // 6 saat geçmişse güncelle
                if (currentTime - lastCacheUpdateTime > AppConstants.App.CUSTOMER_CACHE_UPDATE_INTERVAL) {
                    android.util.Log.d(TAG, "6 saat geçti, müşteri listesi güncelleniyor...");
                    handler.post(() -> fetchAndCacheAllCustomers());
                } else {
                    long remainingTime = AppConstants.App.CUSTOMER_CACHE_UPDATE_INTERVAL - (currentTime - lastCacheUpdateTime);
                    long remainingHours = remainingTime / (60 * 60 * 1000);
                    long remainingMinutes = (remainingTime % (60 * 60 * 1000)) / (60 * 1000);
                    android.util.Log.d(TAG, "Müşteri listesi güncel. Sonraki güncelleme: " + remainingHours + " saat " + remainingMinutes + " dakika sonra");
                }
            }
        }).start();
    }

    @Override
    protected void onPause() {
        super.onPause();
        // Activity arka plana gittiğinde otomatik yenilemeyi durdur
        stopAutoRefresh();
    }
    
    private void checkRequiredPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ için yeni permissions
            String[] permissions = {
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.CAMERA
            };
            
            boolean needsPermission = false;
            for (String permission : permissions) {
                if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                    needsPermission = true;
                    break;
                }
            }
            
            if (needsPermission) {
                ActivityCompat.requestPermissions(this, permissions, STORAGE_PERMISSION_REQUEST);
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Android 6-12 için eski permissions
            String[] permissions = {
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
                Manifest.permission.CAMERA
            };
            
            boolean needsPermission = false;
            for (String permission : permissions) {
                if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                    needsPermission = true;
                    break;
                }
            }
            
            if (needsPermission) {
                ActivityCompat.requestPermissions(this, permissions, STORAGE_PERMISSION_REQUEST);
            }
        }
    }
    
    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        
        if (requestCode == STORAGE_PERMISSION_REQUEST) {
            boolean allGranted = true;
            for (int result : grantResults) {
                if (result != PackageManager.PERMISSION_GRANTED) {
                    allGranted = false;
                    break;
                }
            }
            
            if (!allGranted) {
                Toast.makeText(this, "Resim kaydetmek ve kamera kullanmak için gerekli izinler verilmelidir", Toast.LENGTH_LONG).show();
            }
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        // Otomatik yenilemeyi durdur
        stopAutoRefresh();
        // Uygulama kapatılırken geçici dosyaları temizle
        cleanupTempFiles();
    }

    // Eski yöntem ile kamera sonucunu işle
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == 123 && resultCode == RESULT_OK) {
            // Kameradan resim alındı, direk kaydet
            if (currentPhotoUri != null) {
                directSaveImage(currentPhotoUri);
            }
        }
    }


} 