package com.envanto.barcode.api;

import okhttp3.OkHttpClient;
import okhttp3.logging.HttpLoggingInterceptor;
import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;
import android.util.Log;
import okhttp3.Interceptor;
import okhttp3.Request;
import okhttp3.Response;
import java.io.IOException;
import java.util.concurrent.TimeUnit;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.envanto.barcode.utils.AppConstants;

public class ApiClient {
    private static final String TAG = "ApiClient";
    private static final String BASE_URL = AppConstants.Api.BASE_URL;
    private static ApiClient instance;
    private final ApiService apiService;
    private final ApiService quickApiService; // Hızlı kontroller için

    private ApiClient() {
        // HTTP isteklerini loglama
        HttpLoggingInterceptor loggingInterceptor = new HttpLoggingInterceptor(message ->
            Log.d(TAG, "HTTP Log: " + message));
        loggingInterceptor.setLevel(HttpLoggingInterceptor.Level.BODY);

        // User-Agent interceptor
        Interceptor userAgentInterceptor = chain -> {
            Request originalRequest = chain.request();
            Request requestWithUserAgent = originalRequest.newBuilder()
                    .header("User-Agent", "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36")
                    .build();
            return chain.proceed(requestWithUserAgent);
        };
        
        // UTF-8 encoding interceptor - Türkçe karakter desteği için
        Interceptor utf8Interceptor = chain -> {
            Request originalRequest = chain.request();
            Request.Builder requestBuilder = originalRequest.newBuilder()
                    .header("Accept-Charset", "UTF-8");
            
            // Eğer Content-Type multipart/form-data değilse UTF-8 charset ekle
            String contentType = originalRequest.header("Content-Type");
            if (contentType != null && !contentType.contains("multipart/form-data")) {
                requestBuilder.header("Content-Type", contentType + "; charset=UTF-8");
            }
            // multipart/form-data için OkHttp'nin otomatik olarak ayarlamasına izin ver
            
            return chain.proceed(requestBuilder.build());
        };

        // Özel response interceptor
        Interceptor responseInterceptor = chain -> {
            Request request = chain.request();
            Log.d(TAG, "Request URL: " + request.url());
            Log.d(TAG, "Request Method: " + request.method());
            
            try {
                Response response = chain.proceed(request);
                
                // Response body'yi log'a yaz
                if (response.body() != null) {
                    String responseBody = response.peekBody(Long.MAX_VALUE).string();
                    Log.d(TAG, "Raw Server Response Body: " + responseBody);
                    Log.d(TAG, "Response Code: " + response.code());
                    Log.d(TAG, "Response Message: " + response.message());
                } else {
                    Log.w(TAG, "Response body is NULL");
                }

                return response;
            } catch (Exception e) {
                Log.e(TAG, "Response interceptor error: " + e.getMessage());
                throw e;
            }
        };

        OkHttpClient client = new OkHttpClient.Builder()
                .addInterceptor(loggingInterceptor)
                .addInterceptor(userAgentInterceptor)
                .addInterceptor(utf8Interceptor)
                .addInterceptor(responseInterceptor)
                .connectTimeout(30, TimeUnit.SECONDS)  // Normal işlemler için 30 saniye
                .writeTimeout(120, TimeUnit.SECONDS)   // Dosya yükleme için 2 dakika
                .readTimeout(60, TimeUnit.SECONDS)     // Okuma için 1 dakika
                .retryOnConnectionFailure(true)        // Bağlantı hatalarında yeniden dene
                .build();

        // UTF-8 desteği için Gson konfigürasyonu
        Gson gson = new GsonBuilder()
                .setLenient()
                .create();

        Retrofit retrofit = new Retrofit.Builder()
                .baseUrl(BASE_URL)
                .client(client)
                .addConverterFactory(GsonConverterFactory.create(gson))
                .build();

        apiService = retrofit.create(ApiService.class);
        
        // Hızlı kontroller için konfigüre edilmiş timeout'lu client
        OkHttpClient quickClient = new OkHttpClient.Builder()
                .addInterceptor(userAgentInterceptor)
                .addInterceptor(utf8Interceptor)
                .connectTimeout(AppConstants.Network.QUICK_API_TIMEOUT, TimeUnit.MILLISECONDS)
                .writeTimeout(AppConstants.Network.QUICK_API_TIMEOUT, TimeUnit.MILLISECONDS)
                .readTimeout(AppConstants.Network.QUICK_API_TIMEOUT, TimeUnit.MILLISECONDS)
                .retryOnConnectionFailure(false)       // Hızlı kontrol için retry yok
                .build();
                
        Retrofit quickRetrofit = new Retrofit.Builder()
                .baseUrl(BASE_URL)
                .client(quickClient)
                .addConverterFactory(GsonConverterFactory.create(gson))
                .build();
                
        quickApiService = quickRetrofit.create(ApiService.class);
    }

    public static synchronized ApiClient getInstance() {
        if (instance == null) {
            instance = new ApiClient();
        }
        return instance;
    }

    public ApiService getApiService() {
        return apiService;
    }
    
    // Hızlı kontroller için (3 saniyelik timeout)
    public ApiService getQuickApiService() {
        return quickApiService;
    }
    
    public static String getBaseUrl() {
        return BASE_URL;
    }
} 