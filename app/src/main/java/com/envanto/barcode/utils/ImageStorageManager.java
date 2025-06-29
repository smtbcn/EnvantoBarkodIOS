package com.envanto.barcode.utils;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.provider.OpenableColumns;
import androidx.annotation.RequiresApi;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class ImageStorageManager {
    private static final String TAG = "ImageStorageManager";
    private static final String ENVANTO_FOLDER = "Envanto";
    private static final String BARKOD_IMAGES_DIR = "barkod_images";

    // Ana Envanto klasörünü oluştur (tüm Android versiyonları için file path)
    public static File getStorageDir(Context context) {
        // Tüm versiyonlar için aynı path kullan (upload uyumluluğu için)
        return getLegacyStorageDir(context);
    }
    
    // Android 10+ için MediaStore yöntemi
    @RequiresApi(api = Build.VERSION_CODES.Q)
    private static File getMediaStoreDir(Context context) {
        // Pictures/Envanto klasörünü al
        File picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
        File envantoDir = new File(picturesDir, ENVANTO_FOLDER);
        
        if (!envantoDir.exists() && !envantoDir.mkdirs()) {
            return null;
        }
        return envantoDir;
    }
    
    // Android 9 ve altı için legacy yöntem
    private static File getLegacyStorageDir(Context context) {
        File picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
        File envantoDir = new File(picturesDir, ENVANTO_FOLDER);
        
        if (!envantoDir.exists() && !envantoDir.mkdirs()) {
            return null;
        }
        return envantoDir;
    }

    // Müşteri için özel dizin oluştur (Barkod yükleme için)
    public static File getMusteriDir(Context context, String musteriAdi) {
        File storageDir = getStorageDir(context);
        if (storageDir == null) return null;

        // Müşteri adından geçerli bir dizin adı oluştur
        String safeMusteriAdi = musteriAdi.replaceAll("[^a-zA-Z0-9.-]", "_");
        File musteriDir = new File(storageDir, safeMusteriAdi);
        
        if (!musteriDir.exists() && !musteriDir.mkdirs()) {
            return null;
        }
        return musteriDir;
    }

    // Müşteri resimleri için özel dizin oluştur
    public static File getMusteriResimleriDir(Context context, String musteriAdi) {
        File picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
        File appDir = new File(picturesDir, "envanto/musteriresimleri");
        
        // Müşteri adından geçerli bir dizin adı oluştur
        String safeMusteriAdi = musteriAdi.replaceAll("[^a-zA-Z0-9.-]", "_");
        File musteriDir = new File(appDir, safeMusteriAdi);
        
        if (!musteriDir.exists() && !musteriDir.mkdirs()) {
            return null;
        }
        return musteriDir;
    }

    // Uri'den resmi kopyala ve MediaStore'a kaydet (Barkod yükleme için)
    public static String saveImage(Context context, Uri sourceUri, String musteriAdi) {
        // Her durumda file path döndüren legacy method kullan (upload uyumluluğu için)
        return saveImageLegacy(context, sourceUri, musteriAdi, false);
    }
    
    // Uri'den resmi kopyala ve MediaStore'a kaydet (galeri kaynaklı belirtilen versiyon)
    public static String saveImage(Context context, Uri sourceUri, String musteriAdi, boolean isGallery) {
        // Her durumda file path döndüren legacy method kullan (upload uyumluluğu için)
        return saveImageLegacy(context, sourceUri, musteriAdi, isGallery);
    }

    // Müşteri resimleri için kaydetme metodu (public olarak erişilebilir)
    public static String saveMusteriResmi(Context context, Uri sourceUri, String musteriAdi, boolean isGallery) {
        return saveMusteriResmiLegacy(context, sourceUri, musteriAdi, isGallery);
    }
    
    // Android 10+ için MediaStore kullanarak kaydetme
    @RequiresApi(api = Build.VERSION_CODES.Q)
    private static String saveImageWithMediaStore(Context context, Uri sourceUri, String musteriAdi, boolean isGallery) {
        // Orijinal dosya adını al
        String originalFileName = getOriginalFileName(context, sourceUri, isGallery);
        if (originalFileName == null) {
            // Eğer orijinal ad alınamazsa, timestamp'li varsayılan ad kullan
            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
            if (isGallery) {
                originalFileName = "GALLERY_" + timeStamp + ".jpg";
            } else {
                originalFileName = "DEFAULT_" + timeStamp + ".jpg";
            }
        }
        
        // Müşteri klasörü yolu
        String relativePath = Environment.DIRECTORY_PICTURES + "/" + ENVANTO_FOLDER + "/" + 
                              musteriAdi.replaceAll("[^a-zA-Z0-9.-]", "_");
        
        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DISPLAY_NAME, originalFileName);
        values.put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg");
        values.put(MediaStore.Images.Media.RELATIVE_PATH, relativePath);
        values.put(MediaStore.Images.Media.IS_PENDING, 1);

        ContentResolver resolver = context.getContentResolver();
        Uri imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        
        if (imageUri == null) return null;

        try (InputStream in = resolver.openInputStream(sourceUri);
             OutputStream out = resolver.openOutputStream(imageUri)) {
            
            if (in == null || out == null) {
                throw new IOException("InputStream veya OutputStream null");
            }

            byte[] buffer = new byte[4096];
            int read;
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
            out.flush();
            
            // Pending durumunu kaldır
            values.clear();
            values.put(MediaStore.Images.Media.IS_PENDING, 0);
            resolver.update(imageUri, values, null, null);
            
            // MediaStore URI'sini string olarak döndür
            return imageUri.toString();

        } catch (IOException e) {
            // Hata durumunda oluşturulan entry'yi sil
            resolver.delete(imageUri, null, null);
            return null;
        }
    }
    
    // Android 9 ve altı için legacy kaydetme
    private static String saveImageLegacy(Context context, Uri sourceUri, String musteriAdi, boolean isGallery) {
        File musteriDir = getMusteriDir(context, musteriAdi);
        if (musteriDir == null) return null;

        // Orijinal dosya adını al
        String originalFileName = getOriginalFileName(context, sourceUri, isGallery);
        if (originalFileName == null) {
            // Eğer orijinal ad alınamazsa, timestamp'li varsayılan ad kullan
            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
            if (isGallery) {
                originalFileName = "GALLERY_" + timeStamp + ".jpg";
            } else {
                originalFileName = "DEFAULT_" + timeStamp + ".jpg";
            }
        }
        
        File destFile = new File(musteriDir, originalFileName);
        
        // Eğer aynı isimde dosya varsa, sonuna sayı ekle
        int counter = 1;
        while (destFile.exists()) {
            String nameWithoutExt = originalFileName.replaceFirst("[.][^.]+$", "");
            String extension = originalFileName.substring(originalFileName.lastIndexOf('.'));
            String newFileName = nameWithoutExt + "_" + counter + extension;
            destFile = new File(musteriDir, newFileName);
            counter++;
        }

        try (InputStream in = context.getContentResolver().openInputStream(sourceUri);
             OutputStream out = new FileOutputStream(destFile)) {
            
            if (in == null) {
                throw new IOException("InputStream null");
            }

            byte[] buffer = new byte[4096];
            int read;
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
            out.flush();
            
            // MediaStore'a bildirim gönder (Android 10+ için güvenli versiyon)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                // Sadece Android 9 ve altında MediaStore DATA kolonuna yaz
                ContentValues values = new ContentValues();
                values.put(MediaStore.Images.Media.DATA, destFile.getAbsolutePath());
                values.put(MediaStore.Images.Media.TITLE, destFile.getName());
                values.put(MediaStore.Images.Media.DISPLAY_NAME, destFile.getName());
                values.put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg");
                values.put(MediaStore.Images.Media.DATE_ADDED, System.currentTimeMillis() / 1000);
                values.put(MediaStore.Images.Media.DATE_TAKEN, System.currentTimeMillis());
                
                context.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
            } else {
                // Android 10+ için MediaScannerConnection kullan
                android.media.MediaScannerConnection.scanFile(
                    context,
                    new String[]{destFile.getAbsolutePath()},
                    new String[]{"image/jpeg"},
                    null
                );
            }
            
            return destFile.getAbsolutePath();

        } catch (IOException e) {
            android.util.Log.e(TAG, "Dosya kaydetme hatası: " + e.getMessage());
            return null;
        }
    }

    // Müşteri resimleri için özel kaydetme metodu
    private static String saveMusteriResmiLegacy(Context context, Uri sourceUri, String musteriAdi, boolean isGallery) {
        File musteriDir = getMusteriResimleriDir(context, musteriAdi);
        if (musteriDir == null) return null;

        // Orijinal dosya adını al veya varsayılan oluştur
        String originalFileName = getOriginalFileName(context, sourceUri, isGallery);
        if (originalFileName == null) {
            // Eğer orijinal ad alınamazsa, timestamp'li varsayılan ad kullan
            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
            if (isGallery) {
                originalFileName = "MUSTERI_GALLERY_" + timeStamp + ".jpg";
            } else {
                originalFileName = "MUSTERI_" + timeStamp + ".jpg";
            }
        } else {
            // Dosya adına MUSTERI_ prefix'i ekle
            String nameWithoutExt = originalFileName.replaceFirst("[.][^.]+$", "");
            String extension = originalFileName.contains(".") ? 
                originalFileName.substring(originalFileName.lastIndexOf('.')) : ".jpg";
            originalFileName = "MUSTERI_" + nameWithoutExt + extension;
        }
        
        File destFile = new File(musteriDir, originalFileName);
        
        // Eğer aynı isimde dosya varsa, sonuna sayı ekle
        int counter = 1;
        while (destFile.exists()) {
            String nameWithoutExt = originalFileName.replaceFirst("[.][^.]+$", "");
            String extension = originalFileName.contains(".") ? 
                originalFileName.substring(originalFileName.lastIndexOf('.')) : ".jpg";
            String newFileName = nameWithoutExt + "_" + counter + extension;
            destFile = new File(musteriDir, newFileName);
            counter++;
        }

        try (InputStream in = context.getContentResolver().openInputStream(sourceUri);
             OutputStream out = new FileOutputStream(destFile)) {
            
            if (in == null) {
                throw new IOException("InputStream null");
            }

            byte[] buffer = new byte[4096];
            int read;
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
            out.flush();
            
            // MediaStore'a bildirim gönder (Android 10+ için güvenli versiyon)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                // Sadece Android 9 ve altında MediaStore DATA kolonuna yaz
                ContentValues values = new ContentValues();
                values.put(MediaStore.Images.Media.DATA, destFile.getAbsolutePath());
                values.put(MediaStore.Images.Media.TITLE, destFile.getName());
                values.put(MediaStore.Images.Media.DISPLAY_NAME, destFile.getName());
                values.put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg");
                values.put(MediaStore.Images.Media.DATE_ADDED, System.currentTimeMillis() / 1000);
                values.put(MediaStore.Images.Media.DATE_TAKEN, System.currentTimeMillis());
                
                context.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
            } else {
                // Android 10+ için MediaScannerConnection kullan
                android.media.MediaScannerConnection.scanFile(
                    context,
                    new String[]{destFile.getAbsolutePath()},
                    new String[]{"image/jpeg"},
                    null
                );
            }
            
            return destFile.getAbsolutePath();

        } catch (IOException e) {
            android.util.Log.e(TAG, "Müşteri resmi kaydetme hatası: " + e.getMessage());
            return null;
        }
    }

    // Belirli bir resmi sil (Barkod resimleri için - MediaStore'dan da)
    public static boolean deleteImage(Context context, String imagePath) {
        if (imagePath == null) return false;
        
        try {
            if (imagePath.startsWith("content://")) {
                // MediaStore URI
                Uri uri = Uri.parse(imagePath);
                return context.getContentResolver().delete(uri, null, null) > 0;
            } else {
                // File path
                File file = new File(imagePath);
                boolean deleted = file.exists() && file.delete();
                
                // MediaStore'dan da sil
                if (deleted) {
                    context.getContentResolver().delete(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        MediaStore.Images.Media.DATA + "=?",
                        new String[]{imagePath}
                    );
                    // --- Barkod resimleri için klasör temizliği (Pictures/Envanto/{musteri}) ---
                    deleteEmptyParentDirectories(file.getParentFile());
                }
                return deleted;
            }
        } catch (Exception e) {
            return false;
        }
    }

    // Müşteri resmi sil (Müşteri resimleri için özel - musteriresimleri klasörü dahil)
    public static boolean deleteMusteriResmi(Context context, String imagePath) {
        if (imagePath == null) return false;
        
        try {
            if (imagePath.startsWith("content://")) {
                // MediaStore URI
                Uri uri = Uri.parse(imagePath);
                return context.getContentResolver().delete(uri, null, null) > 0;
            } else {
                // File path
                File file = new File(imagePath);
                boolean deleted = file.exists() && file.delete();
                
                // MediaStore'dan da sil
                if (deleted) {
                    context.getContentResolver().delete(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        MediaStore.Images.Media.DATA + "=?",
                        new String[]{imagePath}
                    );
                    // --- Müşteri resimleri için klasör temizliği (Pictures/envanto/musteriresimleri/{musteri}) ---
                    deleteMusteriResimleriEmptyDirectories(file.getParentFile());
                }
                return deleted;
            }
        } catch (Exception e) {
            return false;
        }
    }

    // Barkod müşteri resimlerini sil (Pictures/Envanto/{musteri}/)
    public static boolean deleteMusteriResimleri(Context context, String musteriAdi) {
        File musteriDir = getMusteriDir(context, musteriAdi);
        if (musteriDir == null || !musteriDir.exists()) return false;

        boolean success = true;
        File[] files = musteriDir.listFiles();
        if (files != null) {
            for (File file : files) {
                if (!deleteImage(context, file.getAbsolutePath())) {
                    success = false;
                }
            }
        }
        
        // Boş klasörü de sil
        if (success && !musteriDir.delete()) {
            success = false;
        }
        
        return success;
    }

    // Müşteri resimleri klasöründeki tüm resimleri sil (Pictures/envanto/musteriresimleri/{musteri}/)
    public static boolean deleteAllMusteriResimleri(Context context, String musteriAdi) {
        File musteriDir = getMusteriResimleriDir(context, musteriAdi);
        if (musteriDir == null || !musteriDir.exists()) return false;

        boolean success = true;
        File[] files = musteriDir.listFiles();
        if (files != null) {
            for (File file : files) {
                if (!deleteMusteriResmi(context, file.getAbsolutePath())) {
                    success = false;
                }
            }
        }
        
        // Boş klasörü de sil
        if (success && !musteriDir.delete()) {
            success = false;
        }
        
        return success;
    }
    
    /**
     * Boş parent klasörleri yukarı doğru temizler (Barkod resimleri için)
     * Yol: Pictures/Envanto/{musteri} → Envanto → Pictures (dur)
     */
    private static void deleteEmptyParentDirectories(File directory) {
        if (directory == null || !directory.exists() || !directory.isDirectory()) {
            return;
        }
        
        // Klasör boş mu kontrol et
        File[] files = directory.listFiles();
        if (files == null || files.length == 0) {
            // Klasör boş, sil
            boolean deleted = directory.delete();
            android.util.Log.d(TAG, "Boş barkod klasör silindi: " + directory.getAbsolutePath() + " - " + deleted);
            
            if (deleted) {
                // Recursive olarak parent'ı da kontrol et (ama Pictures'a kadar gitme)
                File parent = directory.getParentFile();
                if (parent != null && !parent.getName().equals("Pictures")) {
                    deleteEmptyParentDirectories(parent);
                }
            }
        } else {
            android.util.Log.d(TAG, "Barkod parent klasör boş değil, korunuyor: " + directory.getAbsolutePath() + " (" + files.length + " öğe)");
        }
    }

    /**
     * Müşteri resimleri için boş parent klasörleri yukarı doğru temizler 
     * Yol: Pictures/envanto/musteriresimleri/{musteri} → musteriresimleri → envanto → Pictures (dur)
     */
    private static void deleteMusteriResimleriEmptyDirectories(File directory) {
        if (directory == null || !directory.exists() || !directory.isDirectory()) {
            return;
        }
        
        // Klasör boş mu kontrol et
        File[] files = directory.listFiles();
        if (files == null || files.length == 0) {
            // Klasör boş, sil
            boolean deleted = directory.delete();
            android.util.Log.d(TAG, "Boş müşteri resimleri klasörü silindi: " + directory.getAbsolutePath() + " - " + deleted);
            
            if (deleted) {
                // Recursive olarak parent'ı da kontrol et (ama Pictures'a kadar gitme)
                File parent = directory.getParentFile();
                if (parent != null && !parent.getName().equals("Pictures")) {
                    deleteMusteriResimleriEmptyDirectories(parent);
                }
            }
        } else {
            android.util.Log.d(TAG, "Müşteri resimleri parent klasör boş değil, korunuyor: " + directory.getAbsolutePath() + " (" + files.length + " öğe)");
        }
    }
    
    // File path'den Uri oluştur (Android 10+ uyumluluğu için)
    public static Uri getUriFromPath(Context context, String path) {
        if (path.startsWith("content://")) {
            return Uri.parse(path);
        }
        
        // File path'i MediaStore URI'sine çevir
        String[] projection = {MediaStore.Images.Media._ID};
        String selection = MediaStore.Images.Media.DATA + "=?";
        String[] selectionArgs = {path};
        
        try (android.database.Cursor cursor = context.getContentResolver().query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection, selection, selectionArgs, null)) {
            
            if (cursor != null && cursor.moveToFirst()) {
                int idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID);
                long id = cursor.getLong(idColumn);
                return Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, String.valueOf(id));
            }
        } catch (Exception e) {
            // Hata durumunda file URI döndür
        }
        
        return Uri.fromFile(new File(path));
    }

    // Orijinal dosya adını Uri'den alma metodu
    private static String getOriginalFileName(Context context, Uri uri) {
        String fileName = null;
        
        if (uri.getScheme().equals("content")) {
            // ContentResolver kullanarak dosya adını al
            try (android.database.Cursor cursor = context.getContentResolver().query(
                    uri, null, null, null, null)) {
                
                if (cursor != null && cursor.moveToFirst()) {
                    // Önce DISPLAY_NAME'e bak
                    int displayNameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME);
                    if (displayNameIndex != -1) {
                        fileName = cursor.getString(displayNameIndex);
                    }
                    
                    // Eğer DISPLAY_NAME yoksa, DATA kolonuna bak
                    if (fileName == null) {
                        int dataIndex = cursor.getColumnIndex(MediaStore.Images.Media.DATA);
                        if (dataIndex != -1) {
                            String path = cursor.getString(dataIndex);
                            if (path != null) {
                                fileName = new File(path).getName();
                            }
                        }
                    }
                }
            } catch (Exception e) {
                // Hata durumunda null dön
            }
        } else if (uri.getScheme().equals("file")) {
            // File URI için doğrudan dosya adını al
            fileName = new File(uri.getPath()).getName();
        }
        
        // Dosya adının güvenli olduğundan emin ol
        if (fileName != null) {
            fileName = fileName.replaceAll("[^a-zA-Z0-9.-]", "_");
            
            // Eğer dosya uzantısı yoksa .jpg ekle
            if (!fileName.toLowerCase().endsWith(".jpg") && 
                !fileName.toLowerCase().endsWith(".jpeg") && 
                !fileName.toLowerCase().endsWith(".png")) {
                fileName += ".jpg";
            }
        }
        
        return fileName;
    }
    
    // Orijinal dosya adını Uri'den alma metodu - Galeri kaynaklı resimler için
    private static String getOriginalFileName(Context context, Uri uri, boolean isGallery) {
        // Eğer galeri kaynaklı ise ve dosya adı oluşturulacaksa prefix ekle
        String fileName = getOriginalFileName(context, uri);
        
        // Daha önce oluşturulmuş dosya adı yoksa, yeni bir ad oluştur
        if (fileName == null) {
            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
            if (isGallery) {
                fileName = "GALLERY_" + timeStamp + ".jpg";
            } else {
                fileName = "DEFAULT_" + timeStamp + ".jpg";
            }
        } else if (isGallery) {
            // Eğer dosya adı zaten varsa ve galeri kaynaklıysa, prefix ekle (eğer yoksa)
            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
            if (!fileName.startsWith("GALLERY_")) {
                fileName = "GALLERY_" + timeStamp + ".jpg";
            }
        }
        
        return fileName;
    }
} 