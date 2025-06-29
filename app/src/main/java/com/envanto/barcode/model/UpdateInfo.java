package com.envanto.barcode.model;

import com.google.gson.annotations.SerializedName;

/**
 * Uygulama güncelleme bilgilerini temsil eden model sınıfı.
 * Sunucudan gelen güncelleme bilgilerini tutar.
 * [UPDATE-MODEL]
 */
public class UpdateInfo {
    /**
     * Uygulamanın versiyon kodu (numara)
     * Mevcut versiyon ile karşılaştırılarak güncelleme olup olmadığı belirlenir
     */
    @SerializedName("version_code")
    private int versionCode;
    
    /**
     * Uygulamanın versiyon adı (görsel temsil için)
     * Örnek: 1.0.5
     */
    @SerializedName("version_name")
    private String versionName;
    
    /**
     * APK dosya yolu (sadece dosya adı veya yolu)
     * Bu, sunucudaki temel URL ile birleştirilerek indirme linki oluşturulur
     * Örnek: "Envanto-Barcode-v.1.0.5.apk"
     */
    @SerializedName("apk_file_path")
    private String apkFilePath;
    
    @SerializedName("release_date")
    private String releaseDate;
    
    /**
     * Güncellemenin aktif olup olmadığı
     * Bu alan true ise güncelleme indirilebilir
     */
    @SerializedName("is_active")
    private boolean isActive;
    
    @SerializedName("release_notes")
    private String releaseNotes;
    
    /**
     * Tam indirme URL'i
     * Not: Gelecekte sadece apk_file_path kullanılacak, eski sürümlerle uyumluluk için korunuyor
     */
    @SerializedName("download_url")
    private String downloadUrl;
    
    // "güncel" durumu için alanlar
    @SerializedName("durum")
    private String durum;
    
    @SerializedName("mesaj")
    private String mesaj;
    
    // "hata" durumu için
    @SerializedName("hata")
    private String hata;
    
    // Getters and Setters
    public int getVersionCode() {
        return versionCode;
    }
    
    public String getVersionName() {
        return versionName;
    }
    
    public String getApkFilePath() {
        return apkFilePath;
    }
    
    public String getReleaseDate() {
        return releaseDate;
    }
    
    public boolean isActive() {
        return isActive;
    }
    
    public String getReleaseNotes() {
        return releaseNotes;
    }
    
    public String getDownloadUrl() {
        return downloadUrl;
    }
    
    public String getDurum() {
        return durum;
    }
    
    public String getMesaj() {
        return mesaj;
    }
    
    public String getHata() {
        return hata;
    }
    
    public boolean hasError() {
        return hata != null && !hata.isEmpty();
    }
    
    @Override
    public String toString() {
        return "UpdateInfo{" +
                "versionCode=" + versionCode +
                ", versionName='" + versionName + '\'' +
                ", isActive=" + isActive +
                ", apkFilePath='" + apkFilePath + '\'' +
                ", downloadUrl='" + downloadUrl + '\'' +
                ", durum='" + durum + '\'' +
                ", mesaj='" + mesaj + '\'' +
                ", hata='" + hata + '\'' +
                '}';
    }
} 