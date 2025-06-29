package com.envanto.barcode;

/*
 * MÜŞTERİ RESİMLERİ AKTİVİTESİ
 * 
 * Bu aktivite BarcodeUploadActivity'nin birebir kopyasıdır.
 * Tek fark: Sunucuya yükleme işlevi YOK, sadece local kayıt.
 * 
 * Özellikler:
 * - Müşteri arama (AutoCompleteTextView)
 * - Seçilen müşteri kartı (selectedCustomerLayout)
 * - Resim yükleme butonları (galeri + kamera)
 * - Kayıtlı resimler listesi (RecyclerView)
 * - FastCamera Entegrasyonu: Hızlı resim çekme
 * - Galeri Seçimi: Çoklu resim seçme
 * - Image Handling: directSaveImage(), directSaveImages()
 * - Lifecycle Yönetimi: onResume, onPause, onDestroy
 * - Klasör Yolu: /musteriresimleri/ kullanıyor
 * - Database Tablosu: musteri_resimler kullanıyor
 * - Sunucuya Yükleme: YOK (tamamen local)
 */

import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.MenuItem;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.envanto.barcode.adapter.LocalCustomerImagesAdapter;
import com.envanto.barcode.api.ApiClient;
import com.envanto.barcode.api.Customer;
import com.envanto.barcode.databinding.ActivityCustomerImagesBinding;
import com.envanto.barcode.utils.AppConstants;
import com.envanto.barcode.utils.DeviceAuthManager;
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
import android.database.Cursor;
import android.text.TextUtils;
import android.widget.ImageButton;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import android.content.pm.PackageManager;
import android.Manifest;
import android.content.SharedPreferences;
import android.provider.MediaStore;
import android.database.sqlite.SQLiteDatabase;
import android.app.AlertDialog;
import android.view.Menu;
import android.widget.Button;
import android.widget.LinearLayout;
import android.provider.Settings;
import androidx.recyclerview.widget.LinearLayoutManager;
import java.util.HashMap;
import java.util.Map;
import com.envanto.barcode.utils.DeviceIdentifier;

public class CustomerImagesActivity extends AppCompatActivity {
    private static final String TAG = "CustomerImagesActivity";
    private static final int STORAGE_PERMISSION_REQUEST = 101;
    
    private ActivityCustomerImagesBinding binding;
    private CustomerAdapter customerAdapter;
    private Customer selectedCustomer;
    private Handler handler;
    private List<Customer> currentCustomers = new ArrayList<>();
    private MaterialAutoCompleteTextView autoCompleteTextView;
    private ActivityResultLauncher<Intent> imagePickerLauncher;
    private ActivityResultLauncher<Uri> cameraLauncher;  // Normal kamera launcher
    private Uri currentPhotoUri;
    private boolean isActivityActive = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityCustomerImagesBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        setSupportActionBar(binding.toolbar);
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setTitle("Müşteri Resimleri");
        }

        handler = new Handler(Looper.getMainLooper());
        
        // Başlangıçta içeriği gizle (cihaz yetki kontrolü tamamlanana kadar)
        binding.mainContent.setVisibility(View.GONE);
        
        // Cihaz yetkilendirme kontrolü
        checkDeviceAuthorization();
        
        // Storage permissions kontrolü
        checkRequiredPermissions();
        
        setupCustomerSearch();
        setupImageHandling();
        setupSavedImagesList();
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
    
    private void onDeviceAuthSuccess() {
        binding.mainContent.setVisibility(View.VISIBLE);
    }

    private void onDeviceAuthFailure() {
        binding.mainContent.setVisibility(View.GONE);
    }

    private void onDeviceAuthShowLoading() {
        // Sessizce yap
    }

    private void onDeviceAuthHideLoading() {
        // Sessizce yap
    }
    
    private void setupSavedImagesList() {
        binding.savedImagesRecyclerView.setLayoutManager(new LinearLayoutManager(this));
        // Adapter başlangıçta boş, müşteri seçildiğinde doldurulacak
        refreshSavedImagesList();
    }
    
    private void refreshSavedImagesList() {
        new Thread(() -> {
            Cursor cursor = null;
            try {
                DatabaseHelper dbHelper = new DatabaseHelper(this);
                cursor = dbHelper.getAllMusteriResimleri();
                final Cursor finalCursor = cursor;
                final int count = cursor != null ? cursor.getCount() : 0;
                
                runOnUiThread(() -> {
                    try {
                        if (finalCursor != null && count > 0) {
                            try {
                                RecyclerView.Adapter currentAdapter = binding.savedImagesRecyclerView.getAdapter();
                                if (currentAdapter instanceof LocalCustomerImagesAdapter) {
                                    LocalCustomerImagesAdapter existingAdapter = (LocalCustomerImagesAdapter) currentAdapter;
                                    existingAdapter.updateCursor(finalCursor);
                                } else {
                                    LocalCustomerImagesAdapter adapter = new LocalCustomerImagesAdapter(this, finalCursor, new LocalCustomerImagesAdapter.OnImageActionListener() {
                                        @Override
                                        public void onImageDelete(int id, String imagePath) {
                                            // Müşteri resmi silme işlemi
                                            try {
                                                DatabaseHelper dbHelper = new DatabaseHelper(CustomerImagesActivity.this);
                                                boolean deleted = dbHelper.deleteMusteriResimById(id);
                                                
                                                if (deleted) {
                                                    // Müşteri resmini sil (ImageStorageManager ile - musteriresimleri klasörü dahil)
                                                    boolean fileDeleted = ImageStorageManager.deleteMusteriResmi(CustomerImagesActivity.this, imagePath);
                                                    
                                                    // Listeyi yenile
                                                    refreshSavedImagesList();
                                                    
                                                    Toast.makeText(CustomerImagesActivity.this, "Resim silindi", Toast.LENGTH_SHORT).show();
                                                } else {
                                                    Toast.makeText(CustomerImagesActivity.this, "Resim silinemedi", Toast.LENGTH_SHORT).show();
                                                }
                                            } catch (Exception e) {
                                                android.util.Log.e(TAG, "Resim silme hatası: " + e.getMessage());
                                                Toast.makeText(CustomerImagesActivity.this, "Hata: " + e.getMessage(), Toast.LENGTH_SHORT).show();
                                            }
                                        }

                                        @Override
                                        public void onImageView(String imagePath) {
                                            // Resim görüntüleme (örneğin büyük bir dialog'da göster)
                                            try {
                                                Intent intent = new Intent(Intent.ACTION_VIEW);
                                                File file = new File(imagePath);
                                                
                                                if (file.exists()) {
                                                    Uri photoURI;
                                                    
                                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                                        photoURI = FileProvider.getUriForFile(
                                                            CustomerImagesActivity.this,
                                                            getApplicationContext().getPackageName() + ".provider",
                                                            file
                                                        );
                                                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                                    } else {
                                                        photoURI = Uri.fromFile(file);
                                                    }
                                                    
                                                    intent.setDataAndType(photoURI, "image/*");
                                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                                    startActivity(intent);
                                                } else {
                                                    Toast.makeText(CustomerImagesActivity.this, "Resim dosyası bulunamadı", Toast.LENGTH_SHORT).show();
                                                    // Eksik dosya varsa veritabanından da sil
                                                    refreshSavedImagesList();
                                                }
                                            } catch (Exception e) {
                                                android.util.Log.e(TAG, "Resim görüntüleme hatası: " + e.getMessage());
                                                Toast.makeText(CustomerImagesActivity.this, "Resim açılamadı", Toast.LENGTH_SHORT).show();
                                            }
                                        }

                                        @Override
                                        public void onCustomerDelete(String customerName) {
                                            // Müşteriye ait tüm resimleri sil
                                            deleteCustomerImages(customerName);
                                        }
                                        
                                        @Override
                                        public void onWhatsAppShare(String customerName, List<String> imagePaths) {
                                            android.util.Log.d(TAG, "WhatsApp paylaşım isteği: " + customerName + ", " + imagePaths.size() + " resim");
                                            shareToWhatsApp(customerName, imagePaths);
                                        }
                                    });
                                    
                                    binding.savedImagesRecyclerView.setAdapter(adapter);
                                }
                                
                                binding.savedImagesTitle.setText("Kayıtlı Müşteri Resimleri (" + count + ")");
                                
                            } catch (Exception adapterException) {
                                android.util.Log.e(TAG, "Adapter hatası: " + adapterException.getMessage());
                                binding.savedImagesTitle.setText("Kayıtlı Müşteri Resimleri (Hata)");
                                
                                if (finalCursor != null && !finalCursor.isClosed()) {
                                    finalCursor.close();
                                }
                            }
                            
                        } else {
                            binding.savedImagesTitle.setText("Kayıtlı Müşteri Resimleri (0)");
                            binding.savedImagesRecyclerView.setAdapter(null);
                            
                            if (finalCursor != null && !finalCursor.isClosed()) {
                                finalCursor.close();
                            }
                        }
                    } catch (Exception e) {
                        android.util.Log.e(TAG, "UI güncelleme hatası: " + e.getMessage());
                        binding.savedImagesTitle.setText("Kayıtlı Müşteri Resimleri (Hata)");
                        
                        if (finalCursor != null && !finalCursor.isClosed()) {
                            try {
                                finalCursor.close();
                            } catch (Exception closeException) {
                                android.util.Log.e(TAG, "Cursor kapatma hatası: " + closeException.getMessage());
                            }
                        }
                    }
                });
                
            } catch (Exception e) {
                android.util.Log.e(TAG, "Database hatası: " + e.getMessage());
                
                if (cursor != null && !cursor.isClosed()) {
                    try {
                        cursor.close();
                    } catch (Exception closeException) {
                        android.util.Log.e(TAG, "Cursor kapatma hatası: " + closeException.getMessage());
                    }
                }
                
                runOnUiThread(() -> {
                    binding.savedImagesTitle.setText("Kayıtlı Müşteri Resimleri (Hata)");
                });
            }
        }).start();
    }
    
    /**
     * Müşteriye ait tüm resimleri siler (BarcodeUploadActivity stabil versiyonu)
     */
    private void deleteCustomerImages(String customerName) {
        new MaterialAlertDialogBuilder(this)
            .setTitle("Müşteri Resimlerini Sil")
            .setMessage(customerName + " müşterisine ait TÜM yerel resimleri silmek istediğinizden emin misiniz?")
            .setPositiveButton("Sil", (dialog, which) -> {
                try {
                    DatabaseHelper dbHelper = new DatabaseHelper(this);
                    
                    // Müşteriye ait resim dosyalarını al
                    Cursor cursor = dbHelper.getMusteriResimleriByCustomer(customerName);
                    List<String> imagePaths = new ArrayList<>();
                    
                    if (cursor != null) {
                        while (cursor.moveToNext()) {
                            String imagePath = cursor.getString(cursor.getColumnIndex(DatabaseHelper.COLUMN_RESIM_YOLU));
                            imagePaths.add(imagePath);
                        }
                        cursor.close();
                    }
                    
                    // Veritabanından sil
                    boolean deleted = dbHelper.deleteMusteriResimleriByCustomer(customerName);
                    
                    if (deleted) {
                        // Müşteri resimlerini sil (ImageStorageManager ile)
                        int deletedFileCount = 0;
                        for (String imagePath : imagePaths) {
                            try {
                                boolean fileDeleted = ImageStorageManager.deleteMusteriResmi(this, imagePath);
                                if (fileDeleted) {
                                    deletedFileCount++;
                                }
                            } catch (Exception e) {
                                android.util.Log.e(TAG, "Dosya silme hatası: " + e.getMessage());
                            }
                        }
                        
                        // Müşteri klasörünü sil
                        String customerDirectory = getCustomerDirectory(customerName);
                        if (customerDirectory != null) {
                            File customerDir = new File(customerDirectory);
                            if (customerDir.exists()) {
                                boolean dirDeleted = deleteDirectory(customerDir);
                                if (dirDeleted) {
                                    deleteEmptyParentDirectories(customerDir.getParentFile());
                                }
                            }
                        }
                        
                        refreshSavedImagesList();
                        Toast.makeText(this, customerName + " müşteri resimleri silindi", Toast.LENGTH_SHORT).show();
                    } else {
                        Toast.makeText(this, "Resimler silinemedi", Toast.LENGTH_SHORT).show();
                    }
                } catch (Exception e) {
                    android.util.Log.e(TAG, "Müşteri resimleri silme hatası: " + e.getMessage());
                    Toast.makeText(this, "Hata: " + e.getMessage(), Toast.LENGTH_LONG).show();
                }
            })
            .setNegativeButton("İptal", null)
            .show();
    }
    
    private String getCustomerDirectory(String customerName) {
        try {
            File picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
            File envantoDir = new File(picturesDir, "envanto");
            File musteriresimleriDir = new File(envantoDir, "musteriresimleri");
            File customerDir = new File(musteriresimleriDir, customerName);
            return customerDir.getAbsolutePath();
        } catch (Exception e) {
            android.util.Log.e(TAG, "Müşteri klasör hatası: " + e.getMessage());
            return null;
        }
    }
    
    private void deleteEmptyParentDirectories(File directory) {
        if (directory == null || !directory.exists() || !directory.isDirectory()) {
            return;
        }
        
        File[] files = directory.listFiles();
        if (files == null || files.length == 0) {
            boolean deleted = directory.delete();
            if (deleted) {
                File parent = directory.getParentFile();
                if (parent != null && !parent.getName().equals("Pictures")) {
                    deleteEmptyParentDirectories(parent);
                }
            }
        }
    }
    
    /**
     * Klasör ve içeriğini siler (BarcodeUploadActivity stabil versiyonu)
     */
    private boolean deleteDirectory(File directory) {
        if (directory.exists()) {
            File[] files = directory.listFiles();
            if (files != null) {
                for (File file : files) {
                    if (file.isDirectory()) {
                        deleteDirectory(file);  // Recursive
                    } else {
                        file.delete();  // Dosyayı sil
                    }
                }
            }
        }
        return directory.delete();  // Klasörü sil
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
                } else {
                    // 2 karakterden az girildiyse dropdown'ı kapat ve listeyi temizle
                    currentCustomers.clear();
                    customerAdapter.notifyDataSetChanged();
                    autoCompleteTextView.dismissDropDown();
                }
                
                // Eğer müşteri seçili değilse, resim yükleme alanını gizle
                if (selectedCustomer == null) {
                    binding.imageUploadLayout.setVisibility(View.GONE);
                }
            }

            @Override
            public void afterTextChanged(Editable s) {}
        });

        autoCompleteTextView.setOnItemClickListener((parent, view, position, id) -> {
            try {
                if (position >= 0 && position < currentCustomers.size()) {
                    selectedCustomer = currentCustomers.get(position);
                    if (selectedCustomer != null) {
                        // Arama metnini müşteri adı ile doldur ve dropdown'ı kapat
                        autoCompleteTextView.setText(selectedCustomer.getName());
                        
                        // Dropdown'ı zorla kapat
                        forceCloseDropdown();
                        
                        // Kısa gecikme ile UI'ı güncelle (dropdown kapanması için)
                        handler.postDelayed(() -> {
                            // UI'ı güncelle
                            binding.customerSearchLayout.setVisibility(View.GONE);
                            binding.selectedCustomerLayout.setVisibility(View.VISIBLE);
                            binding.selectedCustomerName.setText(selectedCustomer.getName());
                            binding.imageUploadLayout.setVisibility(View.VISIBLE);
                        }, 100);
                    }
                }
            } catch (Exception e) {
                android.util.Log.e(TAG, "Müşteri seçim hatası: " + e.getMessage());
            }
        });

        binding.clearCustomerButton.setOnClickListener(v -> {
            try {
                selectedCustomer = null;
                binding.customerSearchLayout.setVisibility(View.VISIBLE);
                binding.selectedCustomerLayout.setVisibility(View.GONE);
                binding.imageUploadLayout.setVisibility(View.GONE);
                
                // Arama metnini temizle
                autoCompleteTextView.setText("");
                
                // Listeyi temizle
                currentCustomers.clear();
                customerAdapter.notifyDataSetChanged();
                
                // Dropdown'ı kapat
                forceCloseDropdown();
            } catch (Exception e) {
                android.util.Log.e(TAG, "Müşteri temizleme hatası: " + e.getMessage());
            }
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

        // Normal kamera için launcher
        cameraLauncher = registerForActivityResult(
            new ActivityResultContracts.TakePicture(),
            success -> {
                if (success && currentPhotoUri != null) {
                    // Çekilen resmi direk kaydet
                    directSaveImage(currentPhotoUri);
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

        // Kamera butonu - Normal telefon kamerası kullan
        binding.takePictureButton.setOnClickListener(v -> {
            if (selectedCustomer == null) {
                Toast.makeText(this, "Lütfen önce müşteri seçiniz", Toast.LENGTH_SHORT).show();
                return;
            }
            startCamera();
        });
    }

    private void startCamera() {
        try {
            if (selectedCustomer == null) {
                Toast.makeText(this, "Lütfen önce müşteri seçiniz", Toast.LENGTH_SHORT).show();
                return;
            }
            
            // Kamera izni kontrolü
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
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
                        }
                    })
                    .setNegativeButton("İptal", null)
                    .show();
                return;
            }
            
            try {
                File photoFile = createImageFile();
                if (photoFile != null) {
                    currentPhotoUri = FileProvider.getUriForFile(this, "com.envanto.barcode.provider", photoFile);
                    cameraLauncher.launch(currentPhotoUri);
                } else {
                    Toast.makeText(this, "Kamera başlatılamadı", Toast.LENGTH_SHORT).show();
                }
            } catch (Exception e) {
                android.util.Log.e(TAG, "Kamera hatası: " + e.getMessage());
                Toast.makeText(this, "Kamera başlatılamadı", Toast.LENGTH_SHORT).show();
            }
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "startCamera hatası: " + e.getMessage());
            Toast.makeText(this, "Kamera başlatılamadı", Toast.LENGTH_SHORT).show();
        }
    }

    /**
     * Tek resim dosyasını direk kaydet (müşteri resimleri için)
     */
    private void directSaveImage(Uri imageUri) {
        if (selectedCustomer == null) {
            Toast.makeText(this, "Müşteri seçilmemiş", Toast.LENGTH_SHORT).show();
            return;
        }

        new Thread(() -> {
            try {
                // Cihaz kimliğini al (BarcodeUploadActivity gibi)
                String deviceId = DeviceIdentifier.getUniqueDeviceId(this);
                
                // Veritabanından cihaz sahibi bilgisini çek
                DatabaseHelper dbHelper = new DatabaseHelper(this);
                String deviceOwner = dbHelper.getCihazSahibi(deviceId);
                
                // Eğer cihaz sahibi bilgisi yoksa, varsayılan değer olarak cihaz bilgisini kullan
                if (deviceOwner == null || deviceOwner.isEmpty()) {
                    deviceOwner = DeviceIdentifier.getReadableDeviceInfo(this);
                }

                // Resmi kopyala (müşteri resimleri için özel metod)
                String savedPath = ImageStorageManager.saveMusteriResmi(this, imageUri, selectedCustomer.getName(), false);
                boolean saved = savedPath != null;

                if (saved) {
                    // Veritabanına kaydet (müşteri resimleri tablosuna) - cihaz sahibi bilgisini kullan
                    long id = dbHelper.addMusteriResim(selectedCustomer.getName(), savedPath, deviceOwner);

                    runOnUiThread(() -> {
                        if (id > 0) {
                            Toast.makeText(this, "Resim kaydedildi", Toast.LENGTH_SHORT).show();
                            refreshSavedImagesList();
                            startCamera();
                        } else {
                            Toast.makeText(this, "Resim kaydedilemedi", Toast.LENGTH_SHORT).show();
                        }
                    });
                } else {
                    runOnUiThread(() -> {
                        Toast.makeText(this, "Resim kaydedilemedi", Toast.LENGTH_SHORT).show();
                    });
                }
            } catch (Exception e) {
                android.util.Log.e(TAG, "directSaveImage hatası: " + e.getMessage());
                runOnUiThread(() -> {
                    Toast.makeText(this, "Resim kaydedilemedi", Toast.LENGTH_SHORT).show();
                });
            }
        }).start();
    }

    /**
     * Çoklu resim dosyalarını direk kaydet (müşteri resimleri için)
     */
    private void directSaveImages(List<Uri> imageUris) {
        if (selectedCustomer == null) {
            Toast.makeText(this, "Müşteri seçilmemiş", Toast.LENGTH_SHORT).show();
            return;
        }

        if (imageUris.isEmpty()) {
            return;
        }

        // Progress göster
        binding.progressBar.setVisibility(View.VISIBLE);
        binding.progressText.setVisibility(View.VISIBLE);

        new Thread(() -> {
            try {
                // Cihaz kimliğini al (BarcodeUploadActivity gibi)
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
                
                for (int i = 0; i < totalImages; i++) {
                    Uri imageUri = imageUris.get(i);
                    
                    // Progress güncelle
                    int finalI = i;
                    runOnUiThread(() -> updateProgress(finalI + 1, totalImages));

                    try {
                        // Resmi kopyala (müşteri resimleri için özel metod)
                        String savedPath = ImageStorageManager.saveMusteriResmi(this, imageUri, selectedCustomer.getName(), true);
                        boolean saved = savedPath != null;

                        if (saved) {
                            // Veritabanına kaydet - cihaz sahibi bilgisini kullan
                            long id = dbHelper.addMusteriResim(selectedCustomer.getName(), savedPath, deviceOwner);
                            
                            if (id > 0) {
                                successCount++;
                            }
                        }
                        
                        // Kısa bekleme (sistem yükünü azaltmak için)
                        Thread.sleep(100);

                    } catch (Exception e) {
                        android.util.Log.e(TAG, "Resim kaydetme hatası: " + e.getMessage());
                    }
                }

                // Sonuç göster
                int finalSuccessCount = successCount;
                runOnUiThread(() -> {
                    binding.progressBar.setVisibility(View.GONE);
                    binding.progressText.setVisibility(View.GONE);
                    
                    if (finalSuccessCount > 0) {
                        Toast.makeText(this, finalSuccessCount + " resim kaydedildi", Toast.LENGTH_SHORT).show();
                    } else {
                        Toast.makeText(this, "Resimler kaydedilemedi", Toast.LENGTH_SHORT).show();
                    }
                    
                    refreshSavedImagesList();
                });

            } catch (Exception e) {
                android.util.Log.e(TAG, "directSaveImages hatası: " + e.getMessage());
                runOnUiThread(() -> {
                    binding.progressBar.setVisibility(View.GONE);
                    binding.progressText.setVisibility(View.GONE);
                    Toast.makeText(this, "Resimler kaydedilemedi", Toast.LENGTH_SHORT).show();
                });
            }
        }).start();
    }

    /**
     * Progress güncelle
     */
    private void updateProgress(int current, int total) {
        int progress = (int) ((current * 100.0) / total);
        binding.progressBar.setProgress(progress);
        binding.progressText.setText(current + "/" + total + " resim işleniyor...");
    }

    /**
     * Dropdown'ı zorla kapat
     */
    private void forceCloseDropdown() {
        try {
            // 1. Dropdown'ı kapat
            autoCompleteTextView.dismissDropDown();
            
            // 2. Odağı kaldır
            autoCompleteTextView.clearFocus();
            
            // 3. Listeyi temizle - güvenli şekilde
            if (currentCustomers != null) {
                currentCustomers.clear();
            }
            if (customerAdapter != null) {
                customerAdapter.notifyDataSetChanged();
            }
            
            // 4. Klavyeyi gizle
            try {
                InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
                if (imm != null && autoCompleteTextView != null) {
                    imm.hideSoftInputFromWindow(autoCompleteTextView.getWindowToken(), 0);
                }
            } catch (Exception e) {
                // Sessizce
            }
            
            // 5. Activity'nin odağını al
            View currentFocus = getCurrentFocus();
            if (currentFocus != null) {
                currentFocus.clearFocus();
            }
            
            // 6. Soft input modu güncelle
            try {
                getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN);
            } catch (Exception e) {
                // Sessizce
            }
            
            // 7. Handler ile gecikmeli temizlik (dropdown tamamen kapansın diye)
            if (handler != null) {
                handler.postDelayed(() -> {
                    try {
                        if (autoCompleteTextView != null) {
                            autoCompleteTextView.dismissDropDown();
                        }
                                            } catch (Exception e) {
                            // Sessizce
                        }
                }, 100);
            }
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Dropdown kapatma hatası: " + e.getMessage());
        }
    }

    /**
     * Müşteri arama adapter'ı
     */
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
                convertView = LayoutInflater.from(CustomerImagesActivity.this)
                    .inflate(android.R.layout.simple_dropdown_item_1line, parent, false);
            }

            TextView textView = (TextView) convertView;
            Customer customer = getItem(position);
            if (customer != null) {
                textView.setText(customer.getName());
                textView.setPadding(32, 32, 32, 32);
            }

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
        if (query.length() < 2) return;

        ApiClient.getInstance().getQuickApiService().searchCustomers("search", query).enqueue(new Callback<List<Customer>>() {
            @Override
            public void onResponse(Call<List<Customer>> call, Response<List<Customer>> response) {
                if (response.isSuccessful() && response.body() != null) {
                    List<Customer> customers = response.body();
                    
                    currentCustomers.clear();
                    currentCustomers.addAll(customers);
                    customerAdapter.notifyDataSetChanged();
                    
                    if (!customers.isEmpty()) {
                        autoCompleteTextView.showDropDown();
                    }
                } else {
                    searchOfflineCustomers(query);
                }
            }

            @Override
            public void onFailure(Call<List<Customer>> call, Throwable t) {
                searchOfflineCustomers(query);
            }
        });
    }

    private void searchOfflineCustomers(String query) {
        try {
            DatabaseHelper dbHelper = new DatabaseHelper(this);
            List<Customer> customers = dbHelper.searchCachedMusteriler(query);
            
            currentCustomers.clear();
            currentCustomers.addAll(customers);
            customerAdapter.notifyDataSetChanged();
            
            if (!customers.isEmpty()) {
                autoCompleteTextView.showDropDown();
            }
        } catch (Exception e) {
            android.util.Log.e(TAG, "Offline arama hatası: " + e.getMessage());
        }
    }

    private void fetchAndCacheAllCustomers() {
        ApiClient.getInstance().getQuickApiService().getCustomers("getall").enqueue(new Callback<List<Customer>>() {
            @Override
            public void onResponse(Call<List<Customer>> call, Response<List<Customer>> response) {
                if (response.isSuccessful() && response.body() != null) {
                    List<Customer> customers = response.body();
                    
                    try {
                        DatabaseHelper dbHelper = new DatabaseHelper(CustomerImagesActivity.this);
                        dbHelper.cacheMusteriler(customers);
                    } catch (Exception e) {
                        android.util.Log.e(TAG, "Önbellek hatası: " + e.getMessage());
                    }
                }
            }

            @Override
            public void onFailure(Call<List<Customer>> call, Throwable t) {
                android.util.Log.e(TAG, "API hatası: " + t.getMessage());
            }
        });
    }

    private void checkAndUpdateCustomerCache() {
        try {
            DatabaseHelper dbHelper = new DatabaseHelper(this);
            long lastUpdate = dbHelper.getLastMusteriUpdateTime();
            long currentTime = System.currentTimeMillis();
            
            if (currentTime - lastUpdate > AppConstants.App.CUSTOMER_CACHE_UPDATE_INTERVAL) {
                fetchAndCacheAllCustomers();
            }
        } catch (Exception e) {
            android.util.Log.e(TAG, "Önbellek kontrol hatası: " + e.getMessage());
        }
    }

    /**
     * İzin kontrolü
     */
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
    protected void onResume() {
        super.onResume();
        isActivityActive = true;
        
        // Müşteri önbelleğini kontrol et
        checkAndUpdateCustomerCache();
        
        // Her geri dönüşte listeyi yenile, böylece paylaşım durumu güncellenir
        refreshSavedImagesList();
    }

    @Override
    protected void onPause() {
        super.onPause();
        isActivityActive = false;
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        isActivityActive = false;
        // Normal kamera geçici dosyalarını temizle
        cleanupTempFiles();
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

    /**
     * Normal kamera için geçici dosya oluşturur (BarcodeUploadActivity benzeri)
     * @return Oluşturulan dosya
     */
    private File createImageFile() throws IOException {
        try {
            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
            String imageFileName = "CAMERA_" + timeStamp;
            
            // Cache directory kullan (BarcodeUploadActivity benzeri)
            File cacheDir = getCacheDir();
            File tempImagesDir = new File(cacheDir, "temp_camera");
            
            // Dizin yoksa oluştur ve izinlerini kontrol et
            if (!tempImagesDir.exists()) {
                boolean created = tempImagesDir.mkdirs();
                if (!created) {
                    // Ana cache dizinini kullan
                    tempImagesDir = getCacheDir();
                }
            }
            
            // Dizin yazılabilir mi kontrol et
            if (!tempImagesDir.canWrite()) {
                // Ana cache dizinini kullan
                tempImagesDir = getCacheDir();
            }
            
            File imageFile = File.createTempFile(imageFileName, ".jpg", tempImagesDir);
            return imageFile;
            
        } catch (IOException e) {
            android.util.Log.e(TAG, "Dosya oluşturma hatası: " + e.getMessage());
            throw e;
        } catch (Exception e) {
            android.util.Log.e(TAG, "Dosya hatası: " + e.getMessage());
            throw new IOException("Resim dosyası oluşturulamadı");
        }
    }

    /**
     * Geçici dosyaları temizle (Normal kamera dosyaları)
     */
    private void cleanupTempFiles() {
        try {
            // Cache klasöründeki normal kamera geçici dosyalarını sil
            File cacheDir = getCacheDir();
            File tempCameraDir = new File(cacheDir, "temp_camera");
            
            if (tempCameraDir.exists()) {
                File[] files = tempCameraDir.listFiles();
                if (files != null) {
                    for (File file : files) {
                        try {
                            file.delete();
                        } catch (Exception e) {
                            android.util.Log.e(TAG, "Dosya silme hatası: " + e.getMessage());
                        }
                    }
                }
            }
            
            // Eski FastCamera dosyalarını da temizle (eğer varsa)
            File fastCameraDir = new File(cacheDir, "fast_camera");
            if (fastCameraDir.exists()) {
                File[] files = fastCameraDir.listFiles();
                if (files != null) {
                    for (File file : files) {
                        try {
                            file.delete();
                        } catch (Exception e) {
                            android.util.Log.e(TAG, "Eski dosya silme hatası: " + e.getMessage());
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Temizlik hatası: " + e.getMessage());
        }
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



    /**
     * Müşteri resimlerini paylaşım seçicisi ile paylaşır (WhatsApp Normal/Business seçimi için)
     */
    private void shareToWhatsApp(String customerName, List<String> imagePaths) {
        try {
            // Paylaşım metnini hazırla
            String shareText = createShareText(customerName, imagePaths.size());
            
            // Müşteri adını panoya kopyala
            copyTextToClipboard(shareText);

            // Resim sayısına göre paylaşım stratejisini belirle
            if (imagePaths.size() == 1) {
                shareWithSystemChooserSingleImage(shareText, imagePaths.get(0));
            } else if (imagePaths.size() > 1) {
                shareWithSystemChooserMultipleImages(shareText, imagePaths);
            }

        } catch (Exception e) {
            android.util.Log.e(TAG, "Paylaşım hatası: " + e.getMessage());
            Toast.makeText(this, "Paylaşım sırasında hata oluştu", Toast.LENGTH_SHORT).show();
        }
    }
    


    /**
     * Paylaşım metnini oluşturur
     */
    private String createShareText(String customerName, int imageCount) {
        String currentDate = new SimpleDateFormat("dd.MM.yyyy", Locale.getDefault()).format(new Date());
        
        StringBuilder text = new StringBuilder();
        text.append(customerName).append("\n");
        
        return text.toString();
    }

    /**
     * Tek resim paylaşımı (Sistem seçicisi ile)
     */
    private void shareWithSystemChooserSingleImage(String text, String imagePath) {
        try {
            File imageFile = new File(imagePath);
            if (!imageFile.exists()) {
                Toast.makeText(this, "Resim dosyası bulunamadı", Toast.LENGTH_SHORT).show();
                return;
            }

            // Dosya URI'sini oluştur
            Uri imageUri = FileProvider.getUriForFile(this, "com.envanto.barcode.provider", imageFile);

            // Sistem paylaşım Intent'i oluştur
            Intent shareIntent = new Intent(Intent.ACTION_SEND);
            shareIntent.setType("image/*");
            shareIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
            shareIntent.putExtra(Intent.EXTRA_SUBJECT, text); // Başlık olarak ekle
            shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

            // Sistem seçicisini oluştur
            Intent chooser = Intent.createChooser(shareIntent, "Resmi Paylaş");
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

            try {
                startActivity(chooser);
                markCustomerAsShared(extractCustomerFromImagePath(imagePath));
                
                // Listeyi yenile - buton durumunu güncelle
                refreshSavedImagesList();
                android.util.Log.d(TAG, "Liste yenilendi - buton durumu güncellenecek");
                
                // WhatsApp butonlarını zorla güncelle (biraz gecikmeli)
                handler.postDelayed(() -> {
                    try {
                        RecyclerView.Adapter adapter = binding.savedImagesRecyclerView.getAdapter();
                        if (adapter instanceof LocalCustomerImagesAdapter) {
                            ((LocalCustomerImagesAdapter) adapter).forceUpdateWhatsAppButtons();
                            android.util.Log.d(TAG, "Paylaşım butonları zorla güncellendi (gecikmeli)");
                        }
                    } catch (Exception e) {
                        android.util.Log.e(TAG, "Paylaşım buton güncelleme hatası: " + e.getMessage());
                    }
                }, 100); // 100ms gecikme
                
                Toast.makeText(this, "Müşteri adı panoya kopyalandı", Toast.LENGTH_SHORT).show();
                
            } catch (Exception e) {
                android.util.Log.e(TAG, "Paylaşım intent başlatma hatası: " + e.getMessage());
                Toast.makeText(this, "Paylaşım yapılamadı", Toast.LENGTH_SHORT).show();
            }

        } catch (Exception e) {
            android.util.Log.e(TAG, "Tek resim paylaşım hatası: " + e.getMessage());
            Toast.makeText(this, "Paylaşım sırasında hata oluştu", Toast.LENGTH_SHORT).show();
        }
    }

    /**
     * Çoklu resim paylaşımı (Sistem seçicisi ile)
     */
    private void shareWithSystemChooserMultipleImages(String text, List<String> imagePaths) {
        try {
            ArrayList<Uri> imageUris = new ArrayList<>();
            int validImageCount = 0;
            
            for (String imagePath : imagePaths) {
                File imageFile = new File(imagePath);
                if (imageFile.exists()) {
                    try {
                        Uri imageUri = FileProvider.getUriForFile(this, "com.envanto.barcode.provider", imageFile);
                        imageUris.add(imageUri);
                        validImageCount++;
                    } catch (Exception e) {
                        android.util.Log.w(TAG, "Resim URI oluşturulamadı: " + imagePath + " - " + e.getMessage());
                    }
                }
            }

            if (imageUris.isEmpty()) {
                Toast.makeText(this, "Paylaşılabilir resim bulunamadı", Toast.LENGTH_SHORT).show();
                return;
            }

            // Sistem paylaşım Intent'i oluştur
            Intent shareIntent = new Intent();
            shareIntent.setAction(Intent.ACTION_SEND_MULTIPLE);
            shareIntent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, imageUris);
            shareIntent.setType("image/*");
            shareIntent.putExtra(Intent.EXTRA_SUBJECT, text); // Başlık olarak ekle
            shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            
            // Sistem seçicisini oluştur
            Intent chooser = Intent.createChooser(shareIntent, validImageCount + " Resimi Paylaş");
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

            try {
                startActivity(chooser);
                markCustomerAsShared(extractCustomerFromImagePath(imagePaths.get(0)));
                
                // Listeyi yenile - buton durumunu güncelle
                refreshSavedImagesList();
                android.util.Log.d(TAG, "Liste yenilendi - buton durumu güncellenecek (çoklu resim)");
                
                // Paylaşım butonlarını zorla güncelle (biraz gecikmeli)
                handler.postDelayed(() -> {
                    try {
                        RecyclerView.Adapter adapter = binding.savedImagesRecyclerView.getAdapter();
                        if (adapter instanceof LocalCustomerImagesAdapter) {
                            ((LocalCustomerImagesAdapter) adapter).forceUpdateWhatsAppButtons();
                            android.util.Log.d(TAG, "Paylaşım butonları zorla güncellendi (çoklu resim - gecikmeli)");
                        }
                    } catch (Exception e) {
                        android.util.Log.e(TAG, "Paylaşım buton güncelleme hatası (çoklu resim): " + e.getMessage());
                    }
                }, 100); // 100ms gecikme
                
                Toast.makeText(this, "Müşteri adı panoya kopyalandı (" + validImageCount + " resim)", Toast.LENGTH_SHORT).show();
                
            } catch (Exception e) {
                android.util.Log.e(TAG, "Paylaşım intent başlatma hatası: " + e.getMessage());
                Toast.makeText(this, "Paylaşım yapılamadı", Toast.LENGTH_SHORT).show();
            }

        } catch (Exception e) {
            android.util.Log.e(TAG, "Çoklu resim paylaşım hatası: " + e.getMessage());
            Toast.makeText(this, "Paylaşım sırasında hata oluştu", Toast.LENGTH_SHORT).show();
        }
    }

    /**
     * Müşteriyi paylaşıldı olarak işaretler (5 dakika süreyle)
     */
    private void markCustomerAsShared(String customerName) {
        try {
            android.util.Log.d(TAG, "=== PAYLAŞIM ZAMANI KAYDETME ===");
            android.util.Log.d(TAG, "Ham müşteri adı: '" + customerName + "'");
            
            // Müşteri adını normalize et (boşlukları alt çizgi ile değiştir)
            String normalizedCustomerName = customerName.replace(" ", "_");
            android.util.Log.d(TAG, "Normalize edilmiş müşteri adı: '" + normalizedCustomerName + "'");
            
            // SharedPreferences'a paylaşım zamanını kaydet
            SharedPreferences prefs = getSharedPreferences("customer_images_prefs", MODE_PRIVATE);
            String key = "whatsapp_shared_time_" + normalizedCustomerName;
            long currentTime = System.currentTimeMillis();
            
            android.util.Log.d(TAG, "Key: " + key);
            android.util.Log.d(TAG, "Kaydedilecek zaman: " + currentTime);
            
            // commit() kullanarak senkronize kayıt yap
            boolean success = prefs.edit().putLong(key, currentTime).commit();
            
            android.util.Log.d(TAG, "Kayıt başarılı: " + success);
            
            // Kontrol için geri oku
            long savedTime = prefs.getLong(key, 0);
            android.util.Log.d(TAG, "Kontrol - kaydedilen zaman: " + savedTime);
            android.util.Log.d(TAG, "Zaman eşleşiyor: " + (currentTime == savedTime));

        } catch (Exception e) {
            android.util.Log.e(TAG, "Paylaşım zamanı kaydetme hatası: " + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * Müşterinin bugün paylaşılıp paylaşılmadığını kontrol eder
     */
    private boolean isCustomerSharedToday(String customerName) {
        try {
            SharedPreferences prefs = getSharedPreferences("customer_images_prefs", MODE_PRIVATE);
            String currentDate = new SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(new Date());
            return prefs.getBoolean("shared_" + customerName + "_" + currentDate, false);
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Resim yolundan müşteri adını çıkarır
     */
    private String extractCustomerFromImagePath(String imagePath) {
        try {
            File imageFile = new File(imagePath);
            File parentDir = imageFile.getParentFile();
            if (parentDir != null) {
                String customerName = parentDir.getName();
                android.util.Log.d(TAG, "Resim yolundan çıkarılan müşteri adı: '" + customerName + "'");
                android.util.Log.d(TAG, "Resim yolu: " + imagePath);
                return customerName;
            }
        } catch (Exception e) {
            android.util.Log.e(TAG, "Müşteri adı çıkarma hatası: " + e.getMessage());
        }
        return "";
    }

    private void copyTextToClipboard(String text) {
        android.content.ClipboardManager clipboard = (android.content.ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        android.content.ClipData clip = android.content.ClipData.newPlainText("Müşteri Raporu", text);
        if (clipboard != null) {
            clipboard.setPrimaryClip(clip);
            // Toast kaldırıldı - kullanıcı zaten WhatsApp'ta yapıştıracağını biliyor
        }
    }



    
} 