package com.envanto.barcode.api;

import java.util.List;
import retrofit2.Call;
import retrofit2.http.GET;
import retrofit2.http.Query;
import retrofit2.http.Path;
import retrofit2.http.Multipart;
import retrofit2.http.POST;
import retrofit2.http.Part;
import retrofit2.http.Body;
import retrofit2.http.Field;
import retrofit2.http.FormUrlEncoded;
import okhttp3.MultipartBody;
import okhttp3.RequestBody;
import com.envanto.barcode.model.UpdateInfo;

public interface ApiService {
    @GET("customers.asp")
    Call<List<Customer>> searchCustomers(@Query("action") String action, @Query(value = "query", encoded = true) String query);

    @GET("customers.asp")
    Call<List<Customer>> getCustomers(@Query("action") String action);

    @Multipart
    @POST("upload.asp")
    Call<UploadResponse> uploadImageFile(
        @Part("action") RequestBody action,
        @Part("musteri_adi") RequestBody musteriAdi,
        @Part("yukleyen") RequestBody yukleyen,
        @Part MultipartBody.Part resim
    );
    
    @FormUrlEncoded
    @POST("upload.asp")
    Call<UploadResponse> saveImageRecord(
        @Field("action") String action,
        @Field("musteri_adi") String musteriAdi,
        @Field("resim_yolu") String resimYolu,
        @Field("yukleyen") String yukleyen,
        @Field("tarih") String tarih
    );
    
    /**
     * Cihaz yetkilendirme kontrolü
     * 
     * @param action "check" olarak gönderilmeli
     * @param deviceId Cihaz kimliği
     * @return Yetkilendirme durumu
     */
    @FormUrlEncoded
    @POST("usersperm.asp")
    Call<DeviceAuthResponse> checkDeviceAuth(
        @Field("action") String action,
        @Field("cihaz_bilgisi") String deviceId
    );
    
    @FormUrlEncoded
    @POST("usersperm.asp")
    Call<DeviceAuthResponse> updateDeviceOwner(
        @Field("action") String action,
        @Field("cihaz_bilgisi") String deviceId,
        @Field("cihaz_sahibi") String deviceOwner
    );

    /**
     * Araçtaki ürünleri getir
     * @param userId Kullanıcı ID'si (filtreleme için)
     * @return Araçtaki ürünlerin listesi
     */
    @GET("vehicle_products.asp")
    Call<List<VehicleProduct>> getVehicleProducts(@Query("user_id") int userId);

    /**
     * Seçili müşterilerin ürünlerini teslim et
     * @param selectedCustomers Virgülle ayrılmış müşteri isimleri
     * @param userId Kullanıcı ID'si
     * @param userName Kullanıcı adı
     * @return Teslim işlemi sonucu
     */
    @FormUrlEncoded
    @POST("vehicle_delivery.asp")
    Call<DeliveryResponse> deliverProducts(
        @Field("selected_customers") String selectedCustomers,
        @Field("user_id") int userId,
        @Field("user_name") String userName
    );

    /**
     * Ürünü depoya geri bırak
     * @param productId Ürün ID'si
     * @param userId Kullanıcı ID'si
     * @param userName Kullanıcı adı
     * @return Depoya geri bırakma işlemi sonucu
     */
    @FormUrlEncoded
    @POST("vehicle_return_to_depot.asp")
    Call<ReturnToDepotResponse> returnProductToDepot(
        @Field("product_id") int productId,
        @Field("user_id") int userId,
        @Field("user_name") String userName
    );

    /**
     * Kullanıcı girişi
     * @param action "login" olarak gönderilmeli
     * @param email Kullanıcı e-posta adresi
     * @param password Kullanıcı şifresi
     * @return Giriş sonucu ve kullanıcı bilgileri
     */
    @FormUrlEncoded
    @POST("login_api.asp")
    Call<LoginResponse> login(
        @Field("action") String action,
        @Field("email") String email,
        @Field("password") String password
    );

    /**
     * Uygulama güncelleme kontrolü
     * [UPDATE-API-ENDPOINT]
     * Sunucudan uygulama güncelleme bilgilerini alır
     * Dönen veri:
     * - version_code: Güncel versiyon kodu
     * - version_name: Güncel versiyon adı
     * - apk_file_path: APK dosya yolu (indirme için)
     * - is_active: Güncellemenin aktif olup olmadığı
     * - download_url: İndirme URL'i (eski sürümler için)
     * 
     * @param url Tam güncelleme kontrol URL'i
     * @param versionCode Şu anki uygulama versiyon kodu
     * @return Güncelleme bilgileri
     */
    @GET
    Call<UpdateInfo> checkForUpdate(@retrofit2.http.Url String url, @Query("version_code") int versionCode);
} 