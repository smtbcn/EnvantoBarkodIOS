package com.envanto.barcode.database;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import com.envanto.barcode.api.Customer;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import com.envanto.barcode.utils.AppConstants;

public class DatabaseHelper extends SQLiteOpenHelper {
    private static final String TAG = "DatabaseHelper";
    private static final String DATABASE_NAME = "BarkodDB";
    private static final int DATABASE_VERSION = 5;

    // Tablo ve kolon isimleri
    public static final String TABLE_BARKOD_RESIMLER = "barkod_resimler";
    public static final String COLUMN_ID = "id";
    public static final String COLUMN_MUSTERI_ADI = "musteri_adi";
    public static final String COLUMN_RESIM_YOLU = "resim_yolu";
    public static final String COLUMN_TARIH = "tarih";
    public static final String COLUMN_YUKLEYEN = "yukleyen";
    public static final String COLUMN_YUKLENDI = "yuklendi";
    
    // Müşteri Resimleri tablosu (barkod_resimler'in birebir kopyası)
    public static final String TABLE_MUSTERI_RESIMLER = "musteri_resimler";
    // Kolonlar aynı, sadece tablo adı farklı
    
    // Müşteriler tablosu
    public static final String TABLE_MUSTERILER = "musteriler";
    public static final String COLUMN_MUSTERI_ID = "id";
    public static final String COLUMN_MUSTERI = "musteri_adi";
    public static final String COLUMN_SON_GUNCELLEME = "son_guncelleme";
    
    // Cihaz yetkilendirme tablosu
    public static final String TABLE_CIHAZ_YETKI = "cihaz_yetki";
    public static final String COLUMN_CIHAZ_ID = "id";
    public static final String COLUMN_CIHAZ_BILGISI = "cihaz_bilgisi";
    public static final String COLUMN_CIHAZ_SAHIBI = "cihaz_sahibi";
    public static final String COLUMN_CIHAZ_ONAY = "cihaz_onay";
    public static final String COLUMN_CIHAZ_SON_KONTROL = "son_kontrol";

    // Tablo oluşturma SQL ifadesi
    private static final String CREATE_TABLE_BARKOD_RESIMLER = 
        "CREATE TABLE " + TABLE_BARKOD_RESIMLER + "(" +
        COLUMN_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " +
        COLUMN_MUSTERI_ADI + " TEXT NOT NULL, " +
        COLUMN_RESIM_YOLU + " TEXT NOT NULL, " +
        COLUMN_TARIH + " DATETIME DEFAULT CURRENT_TIMESTAMP, " +
        COLUMN_YUKLEYEN + " TEXT, " +
        COLUMN_YUKLENDI + " INTEGER DEFAULT 0" +
        ")";
        
    // Müşteri Resimleri tablosu oluşturma SQL ifadesi (barkod_resimler'in birebir kopyası)
    private static final String CREATE_TABLE_MUSTERI_RESIMLER = 
        "CREATE TABLE " + TABLE_MUSTERI_RESIMLER + "(" +
        COLUMN_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " +
        COLUMN_MUSTERI_ADI + " TEXT NOT NULL, " +
        COLUMN_RESIM_YOLU + " TEXT NOT NULL, " +
        COLUMN_TARIH + " DATETIME DEFAULT CURRENT_TIMESTAMP, " +
        COLUMN_YUKLEYEN + " TEXT, " +
        COLUMN_YUKLENDI + " INTEGER DEFAULT 0" + // Bu alan kullanılmayacak ama yapı uyumluluğu için var
        ")";
        
    // Müşteriler tablosu oluşturma SQL ifadesi
    private static final String CREATE_TABLE_MUSTERILER = 
        "CREATE TABLE " + TABLE_MUSTERILER + "(" +
        COLUMN_MUSTERI_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " +
        COLUMN_MUSTERI + " TEXT NOT NULL UNIQUE, " +
        COLUMN_SON_GUNCELLEME + " DATETIME DEFAULT CURRENT_TIMESTAMP" +
        ")";
        
    // Cihaz yetkilendirme tablosu oluşturma SQL ifadesi
    private static final String CREATE_TABLE_CIHAZ_YETKI =
        "CREATE TABLE " + TABLE_CIHAZ_YETKI + "(" +
        COLUMN_CIHAZ_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " +
        COLUMN_CIHAZ_BILGISI + " TEXT NOT NULL UNIQUE, " +
        COLUMN_CIHAZ_SAHIBI + " TEXT, " +
        COLUMN_CIHAZ_ONAY + " INTEGER DEFAULT 0, " +
        COLUMN_CIHAZ_SON_KONTROL + " DATETIME DEFAULT CURRENT_TIMESTAMP" +
        ")";

    public DatabaseHelper(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL(CREATE_TABLE_BARKOD_RESIMLER);
        db.execSQL(CREATE_TABLE_MUSTERI_RESIMLER);
        db.execSQL(CREATE_TABLE_MUSTERILER);
        db.execSQL(CREATE_TABLE_CIHAZ_YETKI);
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        if (oldVersion < 2) {
            // Yuklendi kolonunu eski sürümden yeni sürüme geçişte ekle
            db.execSQL("ALTER TABLE " + TABLE_BARKOD_RESIMLER + 
                      " ADD COLUMN " + COLUMN_YUKLENDI + " INTEGER DEFAULT 0");
        }
        
        if (oldVersion < 3) {
            // Müşteriler tablosunu ekle
            db.execSQL(CREATE_TABLE_MUSTERILER);
        }
        
        if (oldVersion < 4) {
            // Cihaz yetkilendirme tablosunu ekle
            db.execSQL(CREATE_TABLE_CIHAZ_YETKI);
        }
        
        if (oldVersion < 5) {
            // Müşteri resimleri tablosunu ekle
            db.execSQL(CREATE_TABLE_MUSTERI_RESIMLER);
        }
    }

    // Bekleyen tüm yüklemeleri getir
    public Cursor getAllPendingUploads() {
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            return db.query(
                TABLE_BARKOD_RESIMLER,
                new String[]{COLUMN_ID, COLUMN_MUSTERI_ADI, COLUMN_RESIM_YOLU, COLUMN_YUKLEYEN, COLUMN_TARIH, COLUMN_YUKLENDI},
                null, null, null, null,
                COLUMN_TARIH + " DESC" // En yeni kayıttan başla
            );
        } catch (Exception e) {
            return null;
        }
    }
    
    // Henüz yüklenmemiş tüm kayıtları getir
    public Cursor getNotUploadedRecords() {
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            return db.query(
                TABLE_BARKOD_RESIMLER,
                new String[]{COLUMN_ID, COLUMN_MUSTERI_ADI, COLUMN_RESIM_YOLU, COLUMN_YUKLEYEN, COLUMN_TARIH, COLUMN_YUKLENDI},
                COLUMN_YUKLENDI + "=?",
                new String[]{"0"},
                null, null,
                COLUMN_TARIH + " ASC" // En eski kayıttan başla
            );
        } catch (Exception e) {
            return null;
        }
    }

    // Resim kaydı ekleme metodu
    public long addBarkodResim(String musteriAdi, String resimYolu, String yukleyen) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            ContentValues values = new ContentValues();
            
            // UTF-8 encoding sağla
            String encodedMusteriAdi = musteriAdi;
            String encodedYukleyen = yukleyen;
            
            try {
                encodedMusteriAdi = new String(musteriAdi.getBytes(java.nio.charset.StandardCharsets.UTF_8), java.nio.charset.StandardCharsets.UTF_8);
                encodedYukleyen = new String(yukleyen.getBytes(java.nio.charset.StandardCharsets.UTF_8), java.nio.charset.StandardCharsets.UTF_8);
                
                android.util.Log.d(TAG, "Original müşteri adı: " + musteriAdi + " -> Encoded: " + encodedMusteriAdi);
                android.util.Log.d(TAG, "Original yükleyen: " + yukleyen + " -> Encoded: " + encodedYukleyen);
            } catch (Exception e) {
                android.util.Log.w(TAG, "UTF-8 encoding hatası, orijinal değerler kullanılıyor: " + e.getMessage());
            }
            
            values.put(COLUMN_MUSTERI_ADI, encodedMusteriAdi);
            values.put(COLUMN_RESIM_YOLU, resimYolu);
            values.put(COLUMN_YUKLEYEN, encodedYukleyen);
            values.put(COLUMN_YUKLENDI, 0);

            long id = db.insert(TABLE_BARKOD_RESIMLER, null, values);
            db.close();
            return id;
        } catch (Exception e) {
            android.util.Log.e(TAG, "addBarkodResim error: " + e.getMessage());
            return -1;
        }
    }
    
    // Yükleme durumunu güncelleme metodu
    public boolean updateUploadStatus(String resimYolu, boolean yuklendi) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            ContentValues values = new ContentValues();
            values.put(COLUMN_YUKLENDI, yuklendi ? 1 : 0);
            
            int result = db.update(TABLE_BARKOD_RESIMLER,
                    values,
                    COLUMN_RESIM_YOLU + "=?",
                    new String[]{resimYolu});
            db.close();
            return result > 0;
        } catch (Exception e) {
            return false;
        }
    }

    // Müşteriye ait resimleri getirme metodu
    public Cursor getMusteriResimleri(String musteriAdi) {
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            return db.query(TABLE_BARKOD_RESIMLER,
                    new String[]{COLUMN_ID, COLUMN_RESIM_YOLU, COLUMN_TARIH, COLUMN_YUKLEYEN, COLUMN_YUKLENDI},
                    COLUMN_MUSTERI_ADI + "=?",
                    new String[]{musteriAdi},
                    null, null,
                    COLUMN_TARIH + " DESC");
        } catch (Exception e) {
            return null;
        }
    }

    // Belirli bir resim kaydını silme metodu
    public boolean deleteResim(String resimYolu) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            int result = db.delete(TABLE_BARKOD_RESIMLER,
                    COLUMN_RESIM_YOLU + "=?",
                    new String[]{resimYolu});
            db.close();
            return result > 0;
        } catch (Exception e) {
            return false;
        }
    }

    // Müşteriye ait tüm resimleri silme metodu
    public boolean deleteMusteriResimleri(String musteriAdi) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            int result = db.delete(TABLE_BARKOD_RESIMLER,
                    COLUMN_MUSTERI_ADI + "=?",
                    new String[]{musteriAdi});
            db.close();
            return result > 0;
        } catch (Exception e) {
            return false;
        }
    }

    // Kayıp dosyaları temizle
    public void cleanupMissingFiles() {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            // Sadece yüklenmemiş kayıtları kontrol et
            Cursor cursor = getNotUploadedRecords();
            
            if (cursor != null && cursor.moveToFirst()) {
                do {
                    int resimYoluIndex = cursor.getColumnIndex(COLUMN_RESIM_YOLU);
                    if (resimYoluIndex >= 0) {
                        String resimYolu = cursor.getString(resimYoluIndex);
                        
                        if (resimYolu != null) {
                            File file = new File(resimYolu);
                            if (!file.exists()) {
                                // Dosya yoksa kaydı sil
                                deleteResim(resimYolu);
                                android.util.Log.d(TAG, "Kayıp dosya temizlendi: " + resimYolu);
                            }
                        }
                    }
                } while (cursor.moveToNext());
                cursor.close();
            }
        } catch (Exception e) {
            android.util.Log.e(TAG, "Kayıp dosya temizleme hatası: " + e.getMessage());
        }
    }
    
    // Müşteri listesini önbelleğe al
    public void cacheMusteriler(List<Customer> musteriler) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            
            // İşlem başlat
            db.beginTransaction();
            
            try {
                // Önce tabloyu temizle
                db.delete(TABLE_MUSTERILER, null, null);
                
                // Yeni müşterileri ekle
                for (Customer customer : musteriler) {
                    ContentValues values = new ContentValues();
                    values.put(COLUMN_MUSTERI, customer.getName());
                    db.insert(TABLE_MUSTERILER, null, values);
                }
                
                // İşlemi tamamla
                db.setTransactionSuccessful();
                android.util.Log.d(TAG, musteriler.size() + " müşteri önbelleğe alındı");
            } finally {
                db.endTransaction();
            }
        } catch (Exception e) {
            android.util.Log.e(TAG, "Müşteri önbelleğe alma hatası: " + e.getMessage());
        }
    }
    
    // Önbellekten müşteri ara
    public List<Customer> searchCachedMusteriler(String query) {
        List<Customer> results = new ArrayList<>();
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            
            // LIKE sorgusu için % karakterleri ekle
            String searchPattern = "%" + query + "%";
            
            Cursor cursor = db.query(
                TABLE_MUSTERILER,
                new String[]{COLUMN_MUSTERI},
                COLUMN_MUSTERI + " LIKE ?",
                new String[]{searchPattern},
                null, null,
                COLUMN_MUSTERI + " ASC",
                "50" // En fazla 50 sonuç döndür
            );
            
            if (cursor != null && cursor.moveToFirst()) {
                do {
                    Customer customer = new Customer();
                    customer.setName(cursor.getString(0));
                    results.add(customer);
                } while (cursor.moveToNext());
                
                cursor.close();
            }
            
            android.util.Log.d(TAG, "Önbellekten " + results.size() + " müşteri bulundu");
            return results;
        } catch (Exception e) {
            android.util.Log.e(TAG, "Önbellekten müşteri arama hatası: " + e.getMessage());
            return results;
        }
    }
    
    // Önbellekteki müşteri sayısını döndür
    public int getCachedMusteriCount() {
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            Cursor cursor = db.rawQuery("SELECT COUNT(*) FROM " + TABLE_MUSTERILER, null);
            
            int count = 0;
            if (cursor != null && cursor.moveToFirst()) {
                count = cursor.getInt(0);
                cursor.close();
            }
            
            return count;
        } catch (Exception e) {
            android.util.Log.e(TAG, "Müşteri sayısı alma hatası: " + e.getMessage());
            return 0;
        }
    }
    
    // Son güncelleme zamanını al
    public long getLastMusteriUpdateTime() {
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            Cursor cursor = db.rawQuery(
                "SELECT MAX(" + COLUMN_SON_GUNCELLEME + ") FROM " + TABLE_MUSTERILER, 
                null
            );
            
            long timestamp = 0;
            if (cursor != null && cursor.moveToFirst() && !cursor.isNull(0)) {
                timestamp = cursor.getLong(0);
                cursor.close();
            }
            
            return timestamp;
        } catch (Exception e) {
            android.util.Log.e(TAG, "Son güncelleme zamanı alma hatası: " + e.getMessage());
            return 0;
        }
    }
    
    // Sunucuya yüklenmiş kayıtları getir
    public Cursor getUploadedCustomers() {
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            
            // Yüklenmiş kayıtları müşteri adına göre grupla
            String query = "SELECT " + 
                           COLUMN_MUSTERI_ADI + ", " + 
                           "COUNT(*) as resim_adedi, " +
                           "MAX(" + COLUMN_TARIH + ") as " + COLUMN_TARIH + ", " +
                           "MAX(" + COLUMN_YUKLEYEN + ") as " + COLUMN_YUKLEYEN + " " +
                           "FROM " + TABLE_BARKOD_RESIMLER + " " +
                           "GROUP BY " + COLUMN_MUSTERI_ADI + " " +
                           "ORDER BY COUNT(*) DESC";
            
            return db.rawQuery(query, null);
        } catch (Exception e) {
            android.util.Log.e(TAG, "Müşteri gruplarını alma hatası: " + e.getMessage());
            return null;
        }
    }
    
    // Müşteriye ait resim sayısını getir
    public int getCustomerImageCount(String musteriAdi) {
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            Cursor cursor = db.rawQuery(
                "SELECT COUNT(*) FROM " + TABLE_BARKOD_RESIMLER + 
                " WHERE " + COLUMN_MUSTERI_ADI + "=?",
                new String[]{musteriAdi}
            );
            
            int count = 0;
            if (cursor != null && cursor.moveToFirst()) {
                count = cursor.getInt(0);
                cursor.close();
            }
            
            return count;
        } catch (Exception e) {
            android.util.Log.e(TAG, "Müşteri resim sayısı alma hatası: " + e.getMessage());
            return 0;
        }
    }
    
    // Resim silme metodu
    public boolean deleteImage(int id) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            int result = db.delete(TABLE_BARKOD_RESIMLER,
                    COLUMN_ID + "=?",
                    new String[]{String.valueOf(id)});
            db.close();
            return result > 0;
        } catch (Exception e) {
            android.util.Log.e(TAG, "deleteImage error: " + e.getMessage());
            return false;
        }
    }
    
    // 1 saat önce yüklenmiş kayıtları temizle
    public void cleanupOldUploadedRecords() {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            
            // Şu anki zamanı al
            long currentTime = System.currentTimeMillis();
            
            // Belirlenen süre önceki zamanı hesapla
            long retentionTime = AppConstants.Database.UPLOADED_RECORDS_RETENTION_TIME;
            long cutoffTime = currentTime - retentionTime;
            
            // Tarih formatını SQLite datetime formatına çevir
            String cutoffTimeStr = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                .format(new Date(cutoffTime));
            
            // Belirlenen süreden önce yüklenmiş kayıtları sil
            int result = db.delete(
                TABLE_BARKOD_RESIMLER,
                COLUMN_YUKLENDI + "=? AND " + COLUMN_TARIH + " <= ?",
                new String[]{"1", cutoffTimeStr}
            );
            
            db.close();
            
            if (result > 0) {
                android.util.Log.d(TAG, result + " adet eski yüklenmiş kayıt temizlendi");
            }
        } catch (Exception e) {
            android.util.Log.e(TAG, "Eski kayıt temizleme hatası: " + e.getMessage());
        }
    }

    // Cihaz yetkilendirme bilgilerini kaydet
    public boolean saveCihazYetki(String cihazBilgisi, String cihazSahibi, int cihazOnay) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            ContentValues values = new ContentValues();
            
            values.put(COLUMN_CIHAZ_BILGISI, cihazBilgisi);
            values.put(COLUMN_CIHAZ_SAHIBI, cihazSahibi);
            values.put(COLUMN_CIHAZ_ONAY, cihazOnay);
            values.put(COLUMN_CIHAZ_SON_KONTROL, getCurrentTimestamp());
            
            // Önce var mı kontrol et
            Cursor cursor = db.query(
                TABLE_CIHAZ_YETKI,
                new String[]{COLUMN_CIHAZ_ID},
                COLUMN_CIHAZ_BILGISI + "=?",
                new String[]{cihazBilgisi},
                null, null, null
            );
            
            long result;
            if (cursor != null && cursor.moveToFirst()) {
                // Varsa güncelle
                result = db.update(
                    TABLE_CIHAZ_YETKI,
                    values,
                    COLUMN_CIHAZ_BILGISI + "=?",
                    new String[]{cihazBilgisi}
                );
            } else {
                // Yoksa ekle
                result = db.insert(TABLE_CIHAZ_YETKI, null, values);
            }
            
            if (cursor != null) {
                cursor.close();
            }
            db.close();
            return result != -1;
        } catch (Exception e) {
            android.util.Log.e(TAG, "saveCihazYetki error: " + e.getMessage());
            return false;
        }
    }
    
    // Cihaz yetkilendirme bilgilerini getir
    public Cursor getCihazYetki(String cihazBilgisi) {
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            return db.query(
                TABLE_CIHAZ_YETKI,
                null,
                COLUMN_CIHAZ_BILGISI + "=?",
                new String[]{cihazBilgisi},
                null, null, null
            );
        } catch (Exception e) {
            android.util.Log.e(TAG, "getCihazYetki error: " + e.getMessage());
            return null;
        }
    }
    
    // Cihaz onay durumunu kontrol et
    public boolean isCihazOnaylanmis(String cihazBilgisi) {
        Cursor cursor = getCihazYetki(cihazBilgisi);
        if (cursor != null && cursor.moveToFirst()) {
            int onayIndex = cursor.getColumnIndex(COLUMN_CIHAZ_ONAY);
            boolean onaylandi = onayIndex >= 0 && cursor.getInt(onayIndex) == 1;
            cursor.close();
            return onaylandi;
        }
        return false;
    }
    
    // Cihaz sahibini getir
    public String getCihazSahibi(String cihazBilgisi) {
        Cursor cursor = getCihazYetki(cihazBilgisi);
        if (cursor != null && cursor.moveToFirst()) {
            int sahibiIndex = cursor.getColumnIndex(COLUMN_CIHAZ_SAHIBI);
            String sahibi = sahibiIndex >= 0 ? cursor.getString(sahibiIndex) : "";
            cursor.close();
            return sahibi;
        }
        return "";
    }
    
    // Şu anki zaman damgasını al
    private String getCurrentTimestamp() {
        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
        return dateFormat.format(new Date());
    }
    
    /**
     * Tüm bekleyen yüklemeleri temizler (güvenlik amacıyla)
     * Hem veritabanı kayıtlarını hem de cihazda bulunan resim dosyalarını siler
     */
    public boolean clearAllPendingUploads() {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            
            // Önce silinecek dosyaların yollarını al
            Cursor cursor = db.query(
                TABLE_BARKOD_RESIMLER,
                new String[]{COLUMN_RESIM_YOLU, COLUMN_MUSTERI_ADI},
                COLUMN_YUKLENDI + "=?",
                new String[]{"0"},
                null, null, null
            );
            
            java.util.List<String> imagePaths = new java.util.ArrayList<>();
            java.util.Set<String> customerNames = new java.util.HashSet<>();
            
            if (cursor != null && cursor.moveToFirst()) {
                do {
                    int pathIndex = cursor.getColumnIndex(COLUMN_RESIM_YOLU);
                    int customerIndex = cursor.getColumnIndex(COLUMN_MUSTERI_ADI);
                    
                    if (pathIndex >= 0) {
                        String imagePath = cursor.getString(pathIndex);
                        if (imagePath != null && !imagePath.isEmpty()) {
                            imagePaths.add(imagePath);
                        }
                    }
                    
                    if (customerIndex >= 0) {
                        String customerName = cursor.getString(customerIndex);
                        if (customerName != null && !customerName.isEmpty()) {
                            customerNames.add(customerName);
                        }
                    }
                } while (cursor.moveToNext());
                cursor.close();
            }
            
            android.util.Log.d(TAG, "Güvenlik temizliği: " + imagePaths.size() + " resim dosyası silinecek");
            android.util.Log.d(TAG, "Güvenlik temizliği: " + customerNames.size() + " müşteri klasörü kontrol edilecek");
            
            // Resim dosyalarını sil
            int deletedFiles = 0;
            for (String imagePath : imagePaths) {
                try {
                    java.io.File imageFile = new java.io.File(imagePath);
                    if (imageFile.exists() && imageFile.delete()) {
                        deletedFiles++;
                        android.util.Log.d(TAG, "Resim dosyası silindi: " + imagePath);
                    }
                } catch (Exception e) {
                    android.util.Log.w(TAG, "Resim dosyası silinemedi: " + imagePath + " - " + e.getMessage());
                }
            }
            
            // Müşteri klasörlerini kontrol et ve boşsa sil
            int deletedFolders = 0;
            for (String customerName : customerNames) {
                try {
                    // Müşteri klasörünün yolunu oluştur
                    java.io.File appDir = new java.io.File(android.os.Environment.getExternalStorageDirectory(), "Android/data/com.envanto.barcode/files/Pictures");
                    java.io.File customerDir = new java.io.File(appDir, customerName);
                    
                    if (customerDir.exists()) {
                        // Klasörde başka dosya var mı kontrol et
                        String[] files = customerDir.list();
                        if (files == null || files.length == 0) {
                            // Klasör boşsa sil
                            if (customerDir.delete()) {
                                deletedFolders++;
                                android.util.Log.d(TAG, "Boş müşteri klasörü silindi: " + customerName);
                            }
                        } else {
                            android.util.Log.d(TAG, "Müşteri klasörü boş değil, korunuyor: " + customerName + " (" + files.length + " dosya)");
                        }
                    }
                } catch (Exception e) {
                    android.util.Log.w(TAG, "Müşteri klasörü kontrol edilemedi: " + customerName + " - " + e.getMessage());
                }
            }
            
            // Veritabanından kayıtları sil
            int deletedRows = db.delete(TABLE_BARKOD_RESIMLER, COLUMN_YUKLENDI + "=?", new String[]{"0"});
            db.close();
            
            android.util.Log.d(TAG, "Güvenlik temizliği tamamlandı:");
            android.util.Log.d(TAG, "- " + deletedRows + " veritabanı kaydı silindi");
            android.util.Log.d(TAG, "- " + deletedFiles + " resim dosyası silindi");
            android.util.Log.d(TAG, "- " + deletedFolders + " boş klasör silindi");
            
            return deletedRows > 0;
        } catch (Exception e) {
            android.util.Log.e(TAG, "clearAllPendingUploads error: " + e.getMessage());
            return false;
        }
    }
    
    /**
     * Belirtilen cihaz kimliği için yetkilendirme kaydını temizler
     */
    public boolean clearDeviceAuth(String cihazBilgisi) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            int deletedRows = db.delete(TABLE_CIHAZ_YETKI, COLUMN_CIHAZ_BILGISI + "=?", new String[]{cihazBilgisi});
            db.close();
            
            android.util.Log.d(TAG, "Cihaz yetkilendirmesi temizlendi: " + cihazBilgisi + " (" + deletedRows + " kayıt)");
            return deletedRows > 0;
        } catch (Exception e) {
            android.util.Log.e(TAG, "clearDeviceAuth error: " + e.getMessage());
            return false;
        }
    }

    // ======================== MÜŞTERİ RESİMLERİ İŞLEMLERİ ========================
    
    // Müşteri resmi kaydı ekleme metodu (barkod resmine benzer ama local kayıt)
    public long addMusteriResim(String musteriAdi, String resimYolu, String yukleyen) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            ContentValues values = new ContentValues();
            
            // UTF-8 encoding sağla
            String encodedMusteriAdi = musteriAdi;
            String encodedYukleyen = yukleyen;
            
            try {
                encodedMusteriAdi = new String(musteriAdi.getBytes(java.nio.charset.StandardCharsets.UTF_8), java.nio.charset.StandardCharsets.UTF_8);
                encodedYukleyen = new String(yukleyen.getBytes(java.nio.charset.StandardCharsets.UTF_8), java.nio.charset.StandardCharsets.UTF_8);
                
                android.util.Log.d(TAG, "Müşteri resmi - Original müşteri adı: " + musteriAdi + " -> Encoded: " + encodedMusteriAdi);
            } catch (Exception e) {
                android.util.Log.w(TAG, "UTF-8 encoding hatası, orijinal değerler kullanılıyor: " + e.getMessage());
            }
            
            values.put(COLUMN_MUSTERI_ADI, encodedMusteriAdi);
            values.put(COLUMN_RESIM_YOLU, resimYolu);
            values.put(COLUMN_YUKLEYEN, encodedYukleyen);
            values.put(COLUMN_YUKLENDI, 1); // Müşteri resimleri için her zaman 1 (sunucuya gönderilmez)

            long id = db.insert(TABLE_MUSTERI_RESIMLER, null, values);
            db.close();
            return id;
        } catch (Exception e) {
            android.util.Log.e(TAG, "addMusteriResim error: " + e.getMessage());
            return -1;
        }
    }

    // Müşteriye ait resimleri getirme metodu
    public Cursor getMusteriResimleriByCustomer(String musteriAdi) {
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            return db.query(TABLE_MUSTERI_RESIMLER,
                    new String[]{COLUMN_ID, COLUMN_RESIM_YOLU, COLUMN_TARIH, COLUMN_YUKLEYEN, COLUMN_YUKLENDI},
                    COLUMN_MUSTERI_ADI + "=?",
                    new String[]{musteriAdi},
                    null, null,
                    COLUMN_TARIH + " DESC");
        } catch (Exception e) {
            return null;
        }
    }
    
    // Tüm müşteri resimlerini getir
    public Cursor getAllMusteriResimleri() {
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            return db.query(
                TABLE_MUSTERI_RESIMLER,
                new String[]{COLUMN_ID, COLUMN_MUSTERI_ADI, COLUMN_RESIM_YOLU, COLUMN_YUKLEYEN, COLUMN_TARIH, COLUMN_YUKLENDI},
                null, null, null, null,
                COLUMN_TARIH + " DESC" // En yeni kayıttan başla
            );
        } catch (Exception e) {
            return null;
        }
    }

    // Müşteri resmi silme metodu
    public boolean deleteMusteriResim(String resimYolu) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            int result = db.delete(TABLE_MUSTERI_RESIMLER,
                    COLUMN_RESIM_YOLU + "=?",
                    new String[]{resimYolu});
            db.close();
            return result > 0;
        } catch (Exception e) {
            return false;
        }
    }

    // Müşteriye ait tüm resimleri silme metodu
    public boolean deleteMusteriResimleriByCustomer(String musteriAdi) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            int result = db.delete(TABLE_MUSTERI_RESIMLER,
                    COLUMN_MUSTERI_ADI + "=?",
                    new String[]{musteriAdi});
            db.close();
            return result > 0;
        } catch (Exception e) {
            return false;
        }
    }
    
    // Müşteri resimlerinde eksik dosyaları temizle
    public void cleanupMissingMusteriFiles() {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            Cursor cursor = getAllMusteriResimleri();
            
            if (cursor != null) {
                int deletedCount = 0;
                while (cursor.moveToNext()) {
                    String resimYolu = cursor.getString(cursor.getColumnIndex(COLUMN_RESIM_YOLU));
                    File file = new File(resimYolu);
                    
                    if (!file.exists()) {
                        deleteMusteriResim(resimYolu);
                        deletedCount++;
                    }
                }
                cursor.close();
                android.util.Log.d(TAG, "Müşteri resimleri temizlik: " + deletedCount + " eksik dosya kayıt silindi");
            }
        } catch (Exception e) {
            android.util.Log.e(TAG, "Müşteri resimleri temizlik hatası: " + e.getMessage());
        }
    }
    
    // Müşteri resmi ID'sine göre silme
    public boolean deleteMusteriResimById(int id) {
        try {
            SQLiteDatabase db = this.getWritableDatabase();
            int result = db.delete(TABLE_MUSTERI_RESIMLER,
                    COLUMN_ID + "=?",
                    new String[]{String.valueOf(id)});
            db.close();
            return result > 0;
        } catch (Exception e) {
            return false;
        }
    }

    // Müşterinin resim sayısını getir
    public int getMusteriResimCount(String musteriAdi) {
        try {
            SQLiteDatabase db = this.getReadableDatabase();
            Cursor cursor = db.rawQuery(
                "SELECT COUNT(*) FROM " + TABLE_MUSTERI_RESIMLER + " WHERE " + COLUMN_MUSTERI_ADI + "=?",
                new String[]{musteriAdi}
            );
            
            int count = 0;
            if (cursor != null) {
                if (cursor.moveToFirst()) {
                    count = cursor.getInt(0);
                }
                cursor.close();
            }
            return count;
        } catch (Exception e) {
            android.util.Log.e(TAG, "getMusteriResimCount error: " + e.getMessage());
            return 0;
        }
    }

    // ======================== MÜŞTERİ RESİMLERİ İŞLEMLERİ BİTİŞ ========================
} 