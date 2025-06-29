package com.envanto.barcode.service;

import android.app.Activity;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.ProgressBar;
import android.widget.TextView;

import androidx.appcompat.app.AlertDialog;
import androidx.core.content.FileProvider;

import com.envanto.barcode.BuildConfig;
import com.envanto.barcode.R;
import com.envanto.barcode.api.ApiClient;
import com.envanto.barcode.api.ApiService;
import com.envanto.barcode.model.UpdateInfo;
import com.envanto.barcode.utils.AppConstants;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;

import java.io.File;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class UpdateManager {
    private static final String TAG = "UpdateManager";
    private final Context context;
    private long downloadId = -1;

    public UpdateManager(Context context) {
        this.context = context;
    }

    /**
     * [UPDATE-FUNCTION] Uygulama güncellemesi kontrolü
     * Sunucudan güncel versiyon bilgisini çeker ve mevcut versiyon ile karşılaştırır
     * @param showNoUpdateDialog Güncelleme yoksa dialog gösterilip gösterilmeyeceği
     */
    public void checkForUpdate(boolean showNoUpdateDialog) {
        try {
            ApiService apiService = ApiClient.getInstance().getApiService();
            int currentVersionCode = BuildConfig.VERSION_CODE;
            
            Log.d(TAG, "Güncelleme kontrolü yapılıyor. Mevcut versiyon: " + currentVersionCode);
            Log.d(TAG, "Kontrol URL: " + AppConstants.Api.UPDATE_CHECK_URL + "?version_code=" + currentVersionCode);
            
            Call<UpdateInfo> call = apiService.checkForUpdate(AppConstants.Api.UPDATE_CHECK_URL, currentVersionCode);
            
            call.enqueue(new Callback<UpdateInfo>() {
                @Override
                public void onResponse(Call<UpdateInfo> call, Response<UpdateInfo> response) {
                    try {
                        if (response.isSuccessful() && response.body() != null) {
                            UpdateInfo updateInfo = response.body();
                            Log.d(TAG, "Sunucu yanıtı alındı: " + updateInfo.toString());
                            
                            // API'den "durum" alanı geliyorsa güncelleme gerekmiyordur
                            if (updateInfo.getDurum() != null && updateInfo.getDurum().equals("guncel")) {
                                // Hiçbir dialog gösterilmeyecek
                                return;
                            } else if (updateInfo.getVersionCode() > 0 && updateInfo.isActive() && 
                                      updateInfo.getVersionCode() > BuildConfig.VERSION_CODE) {
                                showUpdateDialog(updateInfo);
                            } else if (showNoUpdateDialog) {
                                showNoUpdateDialog("En son sürümü kullanıyorsunuz.");
                            }
                        } else {
                            Log.e(TAG, "Güncelleme kontrolü başarısız: " + response.code() + " - " + response.message());
                            if (response.errorBody() != null) {
                                try {
                                    String errorBody = response.errorBody().string();
                                    Log.e(TAG, "Hata içeriği: " + errorBody);
                                } catch (Exception e) {
                                    Log.e(TAG, "Hata içeriği okunamadı", e);
                                }
                            }
                            
                            if (showNoUpdateDialog) {
                                showErrorDialog("Güncelleme kontrolü başarısız oldu. Sunucu yanıt kodu: " + response.code());
                            }
                        }
                    } catch (Exception e) {
                        Log.e(TAG, "Yanıt işlenirken hata oluştu", e);
                        if (showNoUpdateDialog) {
                            showErrorDialog("Güncelleme bilgileri işlenirken hata oluştu: " + e.getMessage());
                        }
                    }
                }

                @Override
                public void onFailure(Call<UpdateInfo> call, Throwable t) {
                    Log.e(TAG, "Güncelleme kontrolü başarısız oldu", t);
                    
                    // Daha detaylı hata logu
                    String errorMessage = t.getMessage();
                    if (errorMessage == null) {
                        errorMessage = "Bilinmeyen hata";
                    }
                    Log.e(TAG, "Hata detayı: " + errorMessage);
                    
                    // Hata tipleri için özel mesajlar
                    String userMessage;
                    if (errorMessage.contains("Unable to resolve host") || 
                        errorMessage.contains("Failed to connect")) {
                        userMessage = "Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.";
                    } else if (errorMessage.contains("timed out")) {
                        userMessage = "Sunucu yanıt vermedi (zaman aşımı). Daha sonra tekrar deneyin.";
                    } else if (errorMessage.contains("End of input")) {
                        userMessage = "Sunucu yanıtı eksik veya hatalı. Teknik destek ile iletişime geçin.";
                    } else {
                        userMessage = "Sunucuya bağlanılamadı: " + errorMessage;
                    }
                    
                    if (showNoUpdateDialog) {
                        showErrorDialog(userMessage);
                    }
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "Güncelleme kontrolü başlatılırken hata oluştu", e);
            if (showNoUpdateDialog) {
                showErrorDialog("Güncelleme kontrolü başlatılamadı: " + e.getMessage());
            }
        }
    }
    
    /**
     * [UPDATE-FUNCTION] Güncelleme diyaloğunu gösterir
     * @param updateInfo Güncelleme bilgileri
     */
    private void showUpdateDialog(UpdateInfo updateInfo) {
        if (!(context instanceof Activity) || ((Activity) context).isFinishing()) {
            return;
        }
        
        MaterialAlertDialogBuilder builder = new MaterialAlertDialogBuilder(context)
                .setTitle("Güncelleme Mevcut")
                .setMessage("Yeni bir güncelleme mevcut: " + updateInfo.getVersionName() + "\n\n" + 
                        (updateInfo.getReleaseNotes() != null ? updateInfo.getReleaseNotes() : ""))
                .setPositiveButton("Şimdi Güncelle", (dialog, which) -> {
                    // Güncelleme işlemi başlamadan önce kullanıcıya bilgi ver
                    dialog.dismiss(); // Önce mevcut diyaloğu kapat
                    
                    // Doğrudan indirme işlemini başlat
                    downloadAndInstallUpdate(updateInfo);
                })
                .setCancelable(false);
        
        AlertDialog dialog = builder.create();
        dialog.show();
    }
    
    /**
     * [UPDATE-FUNCTION] Güncelleme yok diyaloğunu gösterir
     * @param message Gösterilecek mesaj
     */
    private void showNoUpdateDialog(String message) {
        if (!(context instanceof Activity) || ((Activity) context).isFinishing()) {
            return;
        }
        
        new MaterialAlertDialogBuilder(context)
                .setTitle("Güncelleme Yok")
                .setMessage(message)
                .setPositiveButton("Tamam", (dialog, which) -> dialog.dismiss())
                .show();
    }
    
    /**
     * [UPDATE-FUNCTION] Hata diyaloğunu gösterir
     * @param message Gösterilecek hata mesajı
     */
    private void showErrorDialog(String message) {
        if (!(context instanceof Activity) || ((Activity) context).isFinishing()) {
            return;
        }
        
        new MaterialAlertDialogBuilder(context)
                .setTitle("Hata")
                .setMessage(message)
                .setPositiveButton("Tamam", (dialog, which) -> dialog.dismiss())
                .show();
    }
    
    /**
     * [UPDATE-FUNCTION] APK dosyasını indirir ve kurulumu başlatır
     * @param updateInfo Güncelleme bilgileri
     */
    private void downloadAndInstallUpdate(UpdateInfo updateInfo) {
        String fileName = "Envanto-Barcode-v." + updateInfo.getVersionName() + ".apk";
        String url;
        
        // Get APK file path from database
        if (updateInfo.getApkFilePath() != null && !updateInfo.getApkFilePath().isEmpty()) {
            url = AppConstants.Api.APK_DOWNLOAD_BASE_URL + updateInfo.getApkFilePath();
        } else if (updateInfo.getDownloadUrl() != null && !updateInfo.getDownloadUrl().isEmpty()) {
            url = updateInfo.getDownloadUrl();
        } else {
            showErrorDialog("İndirme URL'i alınamadı!");
            return;
        }
        
        url = url.replace(":443", "");

        // Clean up old files
        File appDownloadDir = new File(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "updates");
        if (!appDownloadDir.exists()) {
            appDownloadDir.mkdirs();
        }
        
        File appExistingFile = new File(appDownloadDir, fileName);
        if (appExistingFile.exists()) {
            appExistingFile.delete();
        }

        // Show progress dialog
        AlertDialog progressDialog = null;
        ProgressBar progressBar = null;
        TextView progressText = null;
        
        if (context instanceof Activity && !((Activity) context).isFinishing()) {
            View view = LayoutInflater.from(context).inflate(R.layout.dialog_download_progress, null);
            progressBar = view.findViewById(R.id.progressBar);
            progressText = view.findViewById(R.id.progressText);
            
            if (progressBar != null) {
                progressBar.setIndeterminate(false);
                progressBar.setMax(100);
                progressBar.setProgress(0);
            }
            
            if (progressText != null) {
                progressText.setText("İndirme başlatılıyor...");
            }
            
            MaterialAlertDialogBuilder builder = new MaterialAlertDialogBuilder(context)
                .setTitle("Güncelleme İndiriliyor")
                .setView(view)
                .setCancelable(false);
            
            progressDialog = builder.create();
            progressDialog.show();
        }

        // Start download
        DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
        request.setTitle("Envanto Barkod Güncelleme");
        request.setDescription("Güncelleme indiriliyor...");
        request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE);
        request.setDestinationInExternalFilesDir(context, Environment.DIRECTORY_DOWNLOADS + "/updates", fileName);
        
        DownloadManager downloadManager = (DownloadManager) context.getSystemService(Context.DOWNLOAD_SERVICE);
        downloadId = downloadManager.enqueue(request);
        
        final AlertDialog finalProgressDialog = progressDialog;
        final ProgressBar finalProgressBar = progressBar;
        final TextView finalProgressText = progressText;
        final File finalApkFile = new File(appDownloadDir, fileName);
        
        // Track download progress
        if (finalProgressBar != null && finalProgressText != null) {
            final Handler handler = new Handler();
            handler.post(new Runnable() {
                @Override
                public void run() {
                    DownloadManager.Query query = new DownloadManager.Query();
                    query.setFilterById(downloadId);
                    
                    try (Cursor cursor = downloadManager.query(query)) {
                        if (cursor != null && cursor.moveToFirst()) {
                            int status = cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_STATUS));
                            long bytesDownloaded = cursor.getLong(cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR));
                            long bytesTotal = cursor.getLong(cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES));

                            switch (status) {
                                case DownloadManager.STATUS_RUNNING:
                                    if (bytesTotal > 0) {
                                        int progress = (int) ((bytesDownloaded * 100) / bytesTotal);
                                        finalProgressBar.setProgress(progress);
                                        finalProgressText.setText(String.format("%d%% (%s/%s)", 
                                            progress,
                                            formatFileSize(bytesDownloaded),
                                            formatFileSize(bytesTotal)));
                                    }
                                    handler.postDelayed(this, AppConstants.Timing.LOADING_DIALOG_DELAY);
                                    break;

                                case DownloadManager.STATUS_SUCCESSFUL:
                                    if (finalProgressDialog != null && finalProgressDialog.isShowing()) {
                                        finalProgressDialog.dismiss();
                                    }
                                    showInstallDialog(finalApkFile);
                                    break;

                                case DownloadManager.STATUS_FAILED:
                                    if (finalProgressDialog != null && finalProgressDialog.isShowing()) {
                                        finalProgressDialog.dismiss();
                                    }
                                    int reason = cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_REASON));
                                    showErrorDialog("İndirme başarısız oldu: " + reason);
                                    break;

                                case DownloadManager.STATUS_PAUSED:
                                    finalProgressText.setText("İndirme duraklatıldı...");
                                    handler.postDelayed(this, AppConstants.Timing.LOADING_DIALOG_DELAY);
                                    break;

                                case DownloadManager.STATUS_PENDING:
                                    finalProgressText.setText("İndirme sıraya alındı...");
                                    handler.postDelayed(this, AppConstants.Timing.LOADING_DIALOG_DELAY);
                                    break;
                            }
                        }
                    } catch (Exception e) {
                        Log.e(TAG, "İndirme durumu alınamadı", e);
                        handler.postDelayed(this, AppConstants.Timing.LOADING_DIALOG_DELAY);
                    }
                }
            });
        }

        // Register broadcast receiver for completion
        BroadcastReceiver onComplete = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1);
                if (downloadId == id) {
                    if (finalProgressDialog != null && finalProgressDialog.isShowing()) {
                        finalProgressDialog.dismiss();
                    }
                    showInstallDialog(finalApkFile);
                    try {
                        context.unregisterReceiver(this);
                    } catch (Exception e) {
                        Log.e(TAG, "BroadcastReceiver kaldırılamadı", e);
                    }
                }
            }
        };
        
        try {
            context.registerReceiver(onComplete, new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE));
        } catch (Exception e) {
            Log.e(TAG, "BroadcastReceiver kaydedilemedi", e);
        }
    }
    
    /**
     * Kurulum diyaloğunu göster
     * @param file APK dosyası
     */
    private void showInstallDialog(File file) {
        if (!(context instanceof Activity) || ((Activity) context).isFinishing()) {
            return;
        }
        
        if (!file.exists()) {
            showErrorDialog("İndirilen APK dosyası bulunamadı!");
            return;
        }
        
        Log.d(TAG, "Kurulum diyaloğu gösteriliyor, APK yolu: " + file.getAbsolutePath());
        
        // İndirme tamamlandı, direkt kurulum diyaloğunu göster
        ((Activity) context).runOnUiThread(() -> {
            // Kurulum dialogunu göster
            AlertDialog dialog = new MaterialAlertDialogBuilder(context)
                .setTitle("Kurulum Hazır")
                .setMessage("Güncelleme indirildi. Kurulumu başlatmak için aşağıdaki butona tıklayın.")
                .setPositiveButton("Şimdi Kur", (dialogInterface, which) -> {
                    installAPK(file);
                })
                .setCancelable(false)
                .create();
            
            dialog.show();
            
            // Pozitif butonun tıklama işlemini özelleştir (diyaloğu kapatma)
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
                // Diyaloğu kapatma, sadece kurulumu başlat
                installAPK(file);
            });
        });
    }
    
    /**
     * Dosya boyutunu formatlar
     * @param size Dosya boyutu (byte)
     * @return Formatlanmış boyut (KB, MB)
     */
    private String formatFileSize(long size) {
        if (size <= 0) return "0 B";
        
        final String[] units = new String[] { "B", "KB", "MB", "GB", "TB" };
        int digitGroups = (int) (Math.log10(size) / Math.log10(1024));
        
        return String.format("%.1f %s", size / Math.pow(1024, digitGroups), units[digitGroups]);
    }
    
    /**
     * [UPDATE-FUNCTION] APK dosyasını kurar
     * @param file APK dosyası
     */
    private void installAPK(File file) {
        if (!file.exists()) {
            showErrorDialog("APK dosyası bulunamadı!");
            return;
        }
        
        Log.d(TAG, "APK kurulumu başlatılıyor: " + file.getAbsolutePath());
        
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW);
            Uri apkUri;
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                apkUri = FileProvider.getUriForFile(context, context.getPackageName() + ".provider", file);
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            } else {
                apkUri = Uri.fromFile(file);
            }
            
            intent.setDataAndType(apkUri, "application/vnd.android.package-archive");
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            
            Log.d(TAG, "APK kurulum intent'i başlatıldı");
            
            // Bilinmeyen kaynaklar izni gerekiyorsa bilgi ver
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !context.getPackageManager().canRequestPackageInstalls()) {
                Log.d(TAG, "Bilinmeyen kaynaklardan yükleme izni gerekiyor");
                
                // Kullanıcıya bilgi ver
                if (context instanceof Activity && !((Activity) context).isFinishing()) {
                    ((Activity) context).runOnUiThread(() -> {
                        new MaterialAlertDialogBuilder(context)
                            .setTitle("İzin Gerekli")
                            .setMessage("Bu kaynaktan uygulama yüklemek için izin vermeniz gerekiyor. İzin verdikten sonra tekrar 'Şimdi Kur' butonuna tıklayın.")
                            .setPositiveButton("Tamam", null)
                            .setCancelable(false)
                            .show();
                    });
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "APK dosyası açılamadı", e);
            showErrorDialog("APK dosyası açılamadı: " + e.getMessage());
        }
    }
} 