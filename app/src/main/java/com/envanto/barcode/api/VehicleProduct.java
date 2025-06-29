package com.envanto.barcode.api;

public class VehicleProduct {
    private int id;
    private String musteri_adi;
    private String urun_adi;
    private int urun_adet;
    private String depo_aktaran;
    private String depo_aktaran_tarihi;
    private String mevcut_depo;
    private String prosap;
    private String teslim_eden;
    private int teslimatdurumu;
    private int sevk_durumu;
    private int urun_notu_durum;

    // Getter ve Setter metodları
    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getMusteri_adi() {
        return musteri_adi;
    }

    public void setMusteri_adi(String musteri_adi) {
        this.musteri_adi = musteri_adi;
    }

    public String getUrun_adi() {
        return urun_adi;
    }

    public void setUrun_adi(String urun_adi) {
        this.urun_adi = urun_adi;
    }

    public int getUrun_adet() {
        return urun_adet;
    }

    public void setUrun_adet(int urun_adet) {
        this.urun_adet = urun_adet;
    }

    public String getDepo_aktaran() {
        return depo_aktaran;
    }

    public void setDepo_aktaran(String depo_aktaran) {
        this.depo_aktaran = depo_aktaran;
    }

    public String getDepo_aktaran_tarihi() {
        return depo_aktaran_tarihi;
    }

    public void setDepo_aktaran_tarihi(String depo_aktaran_tarihi) {
        this.depo_aktaran_tarihi = depo_aktaran_tarihi;
    }

    public String getMevcut_depo() {
        return mevcut_depo;
    }

    public void setMevcut_depo(String mevcut_depo) {
        this.mevcut_depo = mevcut_depo;
    }

    public String getProsap() {
        return prosap;
    }

    public void setProsap(String prosap) {
        this.prosap = prosap;
    }

    public String getTeslim_eden() {
        return teslim_eden;
    }

    public void setTeslim_eden(String teslim_eden) {
        this.teslim_eden = teslim_eden;
    }

    public int getTeslimatdurumu() {
        return teslimatdurumu;
    }

    public void setTeslimatdurumu(int teslimatdurumu) {
        this.teslimatdurumu = teslimatdurumu;
    }

    public int getSevk_durumu() {
        return sevk_durumu;
    }

    public void setSevk_durumu(int sevk_durumu) {
        this.sevk_durumu = sevk_durumu;
    }

    public int getUrun_notu_durum() {
        return urun_notu_durum;
    }

    public void setUrun_notu_durum(int urun_notu_durum) {
        this.urun_notu_durum = urun_notu_durum;
    }
} 