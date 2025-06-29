package com.envanto.barcode.utils;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Log;

import androidx.appcompat.app.AppCompatActivity;

import com.envanto.barcode.api.ApiClient;
import com.envanto.barcode.api.LoginResponse;
import com.envanto.barcode.utils.AppConstants;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

/**
 * Kullanıcı girişi için ortak utility sınıfı
 * DeviceAuthManager benzeri modüler yapı
 */
public class LoginManager {
    private static final String TAG = "LoginManager";
    private static final String PREF_NAME = "envanto_login_prefs";
    private static final String SAVED_USERS_PREF = "envanto_saved_users";
    private static final String KEY_USER_TOKEN = "user_token";
    private static final String KEY_USER_EMAIL = "user_email";
    private static final String KEY_USER_NAME = "user_name";
    private static final String KEY_USER_SURNAME = "user_surname";
    private static final String KEY_USER_PERMISSION = "user_permission";
    private static final String KEY_USER_ID = "user_id";
    private static final String KEY_LOGIN_TIME = "login_time";
    private static final String KEY_IS_LOGGED_IN = "is_logged_in";
    private static final String KEY_REMEMBER_ME = "remember_me";
    
    /**
     * Kayıtlı kullanıcı bilgileri için model sınıfı
     */
    public static class SavedUser {
        private String email;
        private String name;
        private String surname;
        private String password; // Encrypted olarak saklanacak
        private int userId;
        private int permission;
        private long lastLoginTime;
        
        public SavedUser() {}
        
        public SavedUser(String email, String name, String surname, String password, int userId, int permission) {
            this.email = email;
            this.name = name;
            this.surname = surname;
            this.password = password;
            this.userId = userId;
            this.permission = permission;
            this.lastLoginTime = System.currentTimeMillis();
        }
        
        // Getters and Setters
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        
        public String getSurname() { return surname; }
        public void setSurname(String surname) { this.surname = surname; }
        
        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
        
        public long getLastLoginTime() { return lastLoginTime; }
        public void setLastLoginTime(long lastLoginTime) { this.lastLoginTime = lastLoginTime; }
        
        public int getUserId() { return userId; }
        public void setUserId(int userId) { this.userId = userId; }
        
        public int getPermission() { return permission; }
        public void setPermission(int permission) { this.permission = permission; }
        
        public String getFullName() {
            if (name != null && surname != null) {
                return name + " " + surname;
            }
            return email; // Fallback
        }
    }
    
    /**
     * Kullanıcı girişi durumları için callback interface
     */
    public interface LoginCallback {
        void onLoginSuccess(LoginResponse.User user);
        void onLoginFailure(String message, String errorCode);
        void onShowLoading();
        void onHideLoading();
    }
    
    /**
     * Kullanıcı girişi yapar
     * 
     * @param activity Context olarak kullanılacak AppCompatActivity
     * @param email Kullanıcı e-posta adresi
     * @param password Kullanıcı şifresi
     * @param callback Giriş durumları için callback
     */
    public static void login(AppCompatActivity activity, String email, String password, LoginCallback callback) {
        try {
            // Yükleme ekranını göster
            callback.onShowLoading();
            
            // Input validation
            if (TextUtils.isEmpty(email) || TextUtils.isEmpty(password)) {
                callback.onHideLoading();
                callback.onLoginFailure("E-posta ve şifre alanları boş olamaz", "EMPTY_FIELDS");
                return;
            }
            
            Log.d(TAG, "Kullanıcı girişi başlatılıyor: " + email);
            
            // API çağrısı
            Log.d(TAG, "API çağrısı başlatılıyor - Email: " + email);
            ApiClient.getInstance().getApiService().login("login", email, password)
                .enqueue(new Callback<LoginResponse>() {
                    @Override
                    public void onResponse(Call<LoginResponse> call, Response<LoginResponse> response) {
                        // Kısa bir süre bekle
                        new Handler(Looper.getMainLooper()).postDelayed(() -> {
                            callback.onHideLoading();
                        }, AppConstants.Timing.LOADING_DIALOG_DELAY);
                        
                        if (response.isSuccessful() && response.body() != null) {
                            LoginResponse loginResponse = response.body();
                            
                            if (loginResponse.isSuccess()) {
                                // Giriş başarılı
                                LoginResponse.User user = loginResponse.getUser();
                                
                                // Kullanıcı bilgilerini kaydet
                                saveUserSession(activity, user);
                                
                                Log.d(TAG, "Giriş başarılı: " + user.getFullName());
                                Log.d(TAG, "Kullanıcı yetkisi: " + user.getPermission());
                                
                                // Başarı callback'i çağır
                                callback.onLoginSuccess(user);
                            } else {
                                // Giriş başarısız
                                Log.w(TAG, "Giriş başarısız: " + loginResponse.getMessage());
                                callback.onLoginFailure(loginResponse.getMessage(), loginResponse.getErrorCode());
                            }
                        } else {
                            // Sunucu hatası
                            String errorMsg = "Hata kodu: " + response.code();
                            try {
                                if (response.errorBody() != null) {
                                    errorMsg += " - " + response.errorBody().string();
                                }
                            } catch (Exception e) {
                                errorMsg += " - Hata detayı okunamadı";
                            }
                            Log.e(TAG, "Sunucu yanıt hatası: " + errorMsg);
                            callback.onLoginFailure("Sunucu ile iletişim kurulamadı. Hata: " + response.code(), "SERVER_ERROR");
                        }
                    }
                    
                    @Override
                    public void onFailure(Call<LoginResponse> call, Throwable t) {
                        callback.onHideLoading();
                        
                        // Ağ hatası
                        Log.e(TAG, "Giriş isteği başarısız: " + t.getClass().getSimpleName() + " - " + t.getMessage());
                        Log.e(TAG, "URL: " + call.request().url());
                        callback.onLoginFailure("İnternet bağlantınızı kontrol edin ve tekrar deneyin. Hata: " + t.getMessage(), "NETWORK_ERROR");
                    }
                });
                
        } catch (Exception e) {
            Log.e(TAG, "LoginManager genel hatası: " + e.getMessage());
            callback.onHideLoading();
            callback.onLoginFailure("Beklenmeyen bir hata oluştu.", "UNKNOWN_ERROR");
        }
    }
    
    /**
     * Kullanıcı oturumunu kaydeder
     */
    private static void saveUserSession(Context context, LoginResponse.User user) {
        SharedPreferences prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        
        editor.putBoolean(KEY_IS_LOGGED_IN, true);
        editor.putString(KEY_USER_TOKEN, user.getToken());
        editor.putString(KEY_USER_EMAIL, user.getEmail());
        editor.putString(KEY_USER_NAME, user.getName());
        editor.putString(KEY_USER_SURNAME, user.getSurname());
        editor.putInt(KEY_USER_PERMISSION, user.getPermission());
        editor.putInt(KEY_USER_ID, user.getUserId());
        editor.putLong(KEY_LOGIN_TIME, System.currentTimeMillis());
        
        editor.apply();
        
        Log.d(TAG, "Kullanıcı oturumu kaydedildi");
    }
    
    /**
     * Kullanıcıyı "Beni Hatırla" listesine ekler
     */
    public static void saveUserForRemembering(Context context, String email, String name, String surname, String password, int userId, int permission) {
        List<SavedUser> savedUsers = getSavedUsers(context);
        
        // Aynı e-posta adresi varsa güncelle
        boolean found = false;
        for (SavedUser user : savedUsers) {
            if (user.getEmail().equals(email)) {
                user.setName(name);
                user.setSurname(surname);
                user.setPassword(password);
                user.setUserId(userId);
                user.setPermission(permission);
                user.setLastLoginTime(System.currentTimeMillis());
                found = true;
                break;
            }
        }
        
        // Yeni kullanıcı ekle
        if (!found) {
            savedUsers.add(new SavedUser(email, name, surname, password, userId, permission));
        }
        
        // Maksimum 5 kullanıcı sakla (en son girenleri)
        if (savedUsers.size() > 5) {
            savedUsers.sort((u1, u2) -> Long.compare(u2.getLastLoginTime(), u1.getLastLoginTime()));
            savedUsers = savedUsers.subList(0, 5);
        }
        
        // SharedPreferences'a kaydet
        SharedPreferences prefs = context.getSharedPreferences(SAVED_USERS_PREF, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        
        Gson gson = new Gson();
        String json = gson.toJson(savedUsers);
        editor.putString("saved_users_list", json);
        editor.apply();
        
        Log.d(TAG, "Kullanıcı hatırlanacaklar listesine eklendi: " + email);
    }
    
    /**
     * Kayıtlı kullanıcıları getirir
     */
    public static List<SavedUser> getSavedUsers(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(SAVED_USERS_PREF, Context.MODE_PRIVATE);
        String json = prefs.getString("saved_users_list", "");
        
        if (json.isEmpty()) {
            return new ArrayList<>();
        }
        
        try {
            Gson gson = new Gson();
            Type listType = new TypeToken<List<SavedUser>>(){}.getType();
            List<SavedUser> savedUsers = gson.fromJson(json, listType);
            
            // Null kontrolü
            if (savedUsers == null) {
                return new ArrayList<>();
            }
            
            // Son giriş zamanına göre sırala
            savedUsers.sort((u1, u2) -> Long.compare(u2.getLastLoginTime(), u1.getLastLoginTime()));
            
            return savedUsers;
        } catch (Exception e) {
            Log.e(TAG, "Kayıtlı kullanıcılar yüklenirken hata: " + e.getMessage());
            return new ArrayList<>();
        }
    }
    
    /**
     * Kayıtlı kullanıcıyı siler
     */
    public static void removeSavedUser(Context context, String email) {
        List<SavedUser> savedUsers = getSavedUsers(context);
        savedUsers.removeIf(user -> user.getEmail().equals(email));
        
        // Güncellenmiş listeyi kaydet
        SharedPreferences prefs = context.getSharedPreferences(SAVED_USERS_PREF, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        
        Gson gson = new Gson();
        String json = gson.toJson(savedUsers);
        editor.putString("saved_users_list", json);
        editor.apply();
        
        Log.d(TAG, "Kayıtlı kullanıcı silindi: " + email);
    }
    
    /**
     * Kayıtlı kullanıcı ile otomatik giriş yapar
     */
    public static void loginWithSavedUser(AppCompatActivity activity, SavedUser savedUser, LoginCallback callback) {
        login(activity, savedUser.getEmail(), savedUser.getPassword(), new LoginCallback() {
            @Override
            public void onLoginSuccess(LoginResponse.User user) {
                // Giriş başarılı olduğunda kullanıcıyı güncelle
                saveUserForRemembering(activity, user.getEmail(), user.getName(), user.getSurname(), 
                        savedUser.getPassword(), user.getUserId(), user.getPermission());
                callback.onLoginSuccess(user);
            }
            
            @Override
            public void onLoginFailure(String message, String errorCode) {
                callback.onLoginFailure(message, errorCode);
            }
            
            @Override
            public void onShowLoading() {
                callback.onShowLoading();
            }
            
            @Override
            public void onHideLoading() {
                callback.onHideLoading();
            }
        });
    }
    
    /**
     * Kullanıcının giriş yapıp yapmadığını kontrol eder
     */
    public static boolean isLoggedIn(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        return prefs.getBoolean(KEY_IS_LOGGED_IN, false);
    }
    
    /**
     * Kullanıcı oturumunu sonlandırır
     */
    public static void logout(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.clear();
        editor.apply();
        
        Log.d(TAG, "Kullanıcı oturumu sonlandırıldı");
    }
    
    /**
     * Giriş yapmış kullanıcının bilgilerini döndürür
     */
    public static LoginResponse.User getCurrentUser(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        
        if (!prefs.getBoolean(KEY_IS_LOGGED_IN, false)) {
            return null;
        }
        
        // User nesnesini manuel olarak oluştur
        LoginResponse.User user = new LoginResponse.User();
        
        // Reflection kullanarak private field'lara değer ata
        try {
            java.lang.reflect.Field emailField = LoginResponse.User.class.getDeclaredField("email");
            emailField.setAccessible(true);
            emailField.set(user, prefs.getString(KEY_USER_EMAIL, ""));
            
            java.lang.reflect.Field nameField = LoginResponse.User.class.getDeclaredField("name");
            nameField.setAccessible(true);
            nameField.set(user, prefs.getString(KEY_USER_NAME, ""));
            
            java.lang.reflect.Field surnameField = LoginResponse.User.class.getDeclaredField("surname");
            surnameField.setAccessible(true);
            surnameField.set(user, prefs.getString(KEY_USER_SURNAME, ""));
            
            java.lang.reflect.Field permissionField = LoginResponse.User.class.getDeclaredField("permission");
            permissionField.setAccessible(true);
            permissionField.set(user, prefs.getInt(KEY_USER_PERMISSION, 0));
            
            java.lang.reflect.Field userIdField = LoginResponse.User.class.getDeclaredField("user_id");
            userIdField.setAccessible(true);
            userIdField.set(user, prefs.getInt(KEY_USER_ID, 0));
            
            java.lang.reflect.Field tokenField = LoginResponse.User.class.getDeclaredField("token");
            tokenField.setAccessible(true);
            tokenField.set(user, prefs.getString(KEY_USER_TOKEN, ""));
            
            java.lang.reflect.Field lastLoginField = LoginResponse.User.class.getDeclaredField("last_login");
            lastLoginField.setAccessible(true);
            long loginTime = prefs.getLong(KEY_LOGIN_TIME, 0);
            lastLoginField.set(user, loginTime > 0 ? new java.util.Date(loginTime).toString() : "");
            
        } catch (Exception e) {
            Log.e(TAG, "getCurrentUser reflection hatası: " + e.getMessage());
            return null;
        }
        
        return user;
    }
    
    /**
     * Kullanıcı token'ını döndürür
     */
    public static String getUserToken(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        return prefs.getString(KEY_USER_TOKEN, "");
    }
    
    /**
     * Oturum süresinin dolup dolmadığını kontrol eder (24 saat)
     */
    public static boolean isSessionExpired(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        long loginTime = prefs.getLong(KEY_LOGIN_TIME, 0);
        long currentTime = System.currentTimeMillis();
        long sessionDuration = AppConstants.App.SESSION_DURATION;
        
        return (currentTime - loginTime) > sessionDuration;
    }
} 