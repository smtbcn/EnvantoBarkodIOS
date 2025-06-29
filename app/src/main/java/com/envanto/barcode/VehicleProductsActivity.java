package com.envanto.barcode;

import android.os.Bundle;
import android.view.MenuItem;
import android.view.View;
import android.widget.CheckBox;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

import com.envanto.barcode.adapter.SavedUsersAdapter;
import com.envanto.barcode.adapter.VehicleProductsAdapter;
import com.envanto.barcode.api.ApiClient;
import com.envanto.barcode.api.ApiService;
import com.envanto.barcode.api.DeliveryResponse;
import com.envanto.barcode.api.LoginResponse;
import com.envanto.barcode.api.ReturnToDepotResponse;
import com.envanto.barcode.api.VehicleProduct;
import com.envanto.barcode.utils.DeviceAuthManager;
import com.envanto.barcode.utils.LoginManager;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.textfield.TextInputEditText;

import java.util.ArrayList;
import java.util.List;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class VehicleProductsActivity extends AppCompatActivity {

    private RecyclerView recyclerView;
    private SwipeRefreshLayout swipeRefreshLayout;
    private ProgressBar progressBar;
    private TextView emptyStateText;
    private TextView userNameText;
    private MaterialButton deliverSelectedButton;
    private VehicleProductsAdapter adapter;
    private ApiService apiService;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_vehicle_products);

        // Toolbar'ı ayarla
        Toolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setTitle(getString(R.string.vehicle_products));
        }

        initViews();
        setupRecyclerView();
        setupSwipeRefresh();
        
        // API servisi başlat
        apiService = ApiClient.getInstance().getApiService();
        
        // Cihaz yetkilendirme kontrolü
        checkDeviceAuthorization();
    }

    private void initViews() {
        recyclerView = findViewById(R.id.recyclerView);
        swipeRefreshLayout = findViewById(R.id.swipeRefreshLayout);
        progressBar = findViewById(R.id.progressBar);
        emptyStateText = findViewById(R.id.emptyStateText);
        userNameText = findViewById(R.id.userNameText);
        deliverSelectedButton = findViewById(R.id.deliverSelectedButton);
        
        // Seçilenleri teslim et butonu click listener
        deliverSelectedButton.setOnClickListener(v -> {
            deliverSelectedCustomers();
        });
    }

    private void setupRecyclerView() {
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        adapter = new VehicleProductsAdapter(new ArrayList<>());
        
        // Seçim değişikliği listener'ını ayarla
        adapter.setOnSelectionChangeListener(selectedCount -> {
            updateDeliverButton(selectedCount);
        });
        
        // Depoya geri bırakma listener'ını ayarla
        adapter.setOnReturnToDepotListener(product -> {
            returnProductToDepot(product);
        });
        
        recyclerView.setAdapter(adapter);
    }

    private void setupSwipeRefresh() {
        swipeRefreshLayout.setOnRefreshListener(this::loadVehicleProducts);
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
        // Cihaz yetkilendirme başarılı, şimdi kullanıcı girişi kontrol et
        checkUserLogin();
    }
    
    /**
     * Cihaz yetkilendirme başarısız olduğunda çalışır
     */
    private void onDeviceAuthFailure() {
        // Activity zaten kapanacak
    }
    
    /**
     * Cihaz yetkilendirme yükleme başladığında çalışır
     */
    private void onDeviceAuthShowLoading() {
        showLoading();
    }
    
    /**
     * Cihaz yetkilendirme yükleme bittiğinde çalışır
     */
    private void onDeviceAuthHideLoading() {
        hideLoading();
    }
    
    /**
     * Kullanıcı girişi kontrolü yapar
     */
    private void checkUserLogin() {
        // Her zaman login dialog'u göster (kullanıcı seçimi için)
        // Session varsa kayıtlı kullanıcı olarak gösterilecek
        showLoginDialog();
    }
    
    /**
     * Login dialog'unu gösterir
     */
    private void showLoginDialog() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        View dialogView = getLayoutInflater().inflate(R.layout.dialog_login, null);
        builder.setView(dialogView);
        
        AlertDialog dialog = builder.create();
        dialog.setCancelable(false); // Kullanıcı login yapmak zorunda
        
        // Dialog bileşenlerini bul
        TextInputEditText emailEditText = dialogView.findViewById(R.id.emailEditText);
        TextInputEditText passwordEditText = dialogView.findViewById(R.id.passwordEditText);
        CheckBox rememberMeCheckBox = dialogView.findViewById(R.id.rememberMeCheckBox);
        TextView savedUsersLabel = dialogView.findViewById(R.id.savedUsersLabel);
        RecyclerView savedUsersRecyclerView = dialogView.findViewById(R.id.savedUsersRecyclerView);
        ProgressBar loginProgressBar = dialogView.findViewById(R.id.loginProgressBar);
        MaterialButton loginButton = dialogView.findViewById(R.id.loginButton);
        MaterialButton cancelButton = dialogView.findViewById(R.id.cancelButton);
        
        // Mevcut session kontrolü - eğer geçerli session varsa bilgileri doldur
        if (LoginManager.isLoggedIn(this) && !LoginManager.isSessionExpired(this)) {
            LoginResponse.User currentUser = LoginManager.getCurrentUser(this);
            if (currentUser != null) {
                emailEditText.setText(currentUser.getEmail());
                // Şifreyi kayıtlı kullanıcılardan bul
                List<LoginManager.SavedUser> allSavedUsers = LoginManager.getSavedUsers(this);
                for (LoginManager.SavedUser savedUser : allSavedUsers) {
                    if (savedUser.getEmail().equals(currentUser.getEmail())) {
                        passwordEditText.setText(savedUser.getPassword());
                        break;
                    }
                }
                rememberMeCheckBox.setChecked(true);
            }
        }
        
        // Kayıtlı kullanıcıları yükle
        List<LoginManager.SavedUser> savedUsers = LoginManager.getSavedUsers(this);
        SavedUsersAdapter savedUsersAdapter = null;
        
        if (!savedUsers.isEmpty()) {
            savedUsersLabel.setVisibility(View.VISIBLE);
            savedUsersRecyclerView.setVisibility(View.VISIBLE);
            
            // Adapter setup
            savedUsersAdapter = new SavedUsersAdapter(savedUsers, new SavedUsersAdapter.OnSavedUserClickListener() {
                @Override
                public void onUserClick(LoginManager.SavedUser user) {
                    // Kayıtlı kullanıcı seçildi
                    emailEditText.setText(user.getEmail());
                    passwordEditText.setText(user.getPassword());
                    rememberMeCheckBox.setChecked(true);
                }
                
                @Override
                public void onUserDelete(LoginManager.SavedUser user) {
                    // Kullanıcıyı sil
                    new AlertDialog.Builder(VehicleProductsActivity.this)
                            .setTitle("Kullanıcıyı Sil")
                            .setMessage(user.getFullName() + " kullanıcısını kayıtlı listeden silmek istediğinizden emin misiniz?")
                            .setPositiveButton("Sil", (d, w) -> {
                                LoginManager.removeSavedUser(VehicleProductsActivity.this, user.getEmail());
                                List<LoginManager.SavedUser> updatedUsers = LoginManager.getSavedUsers(VehicleProductsActivity.this);
                                
                                // Adapter'ı güncelle (null kontrolü ile)
                                SavedUsersAdapter currentAdapter = (SavedUsersAdapter) savedUsersRecyclerView.getAdapter();
                                if (currentAdapter != null) {
                                    currentAdapter.updateUsers(updatedUsers);
                                }
                                
                                // Liste boşsa gizle
                                if (updatedUsers.isEmpty()) {
                                    savedUsersLabel.setVisibility(View.GONE);
                                    savedUsersRecyclerView.setVisibility(View.GONE);
                                }
                            })
                            .setNegativeButton("İptal", null)
                            .show();
                }
            });
            
            savedUsersRecyclerView.setLayoutManager(new LinearLayoutManager(this));
            savedUsersRecyclerView.setAdapter(savedUsersAdapter);
        }
        
        // Login butonu
        loginButton.setOnClickListener(v -> {
            String email = emailEditText.getText().toString().trim();
            String password = passwordEditText.getText().toString().trim();
            boolean rememberMe = rememberMeCheckBox.isChecked();
            
            if (email.isEmpty() || password.isEmpty()) {
                Toast.makeText(this, "E-posta ve şifre alanları boş olamaz", Toast.LENGTH_SHORT).show();
                return;
            }
            
            // Login işlemi
            LoginManager.login(this, email, password, new LoginManager.LoginCallback() {
                @Override
                public void onLoginSuccess(LoginResponse.User user) {
                    // Beni hatırla seçiliyse kaydet
                    if (rememberMe) {
                        LoginManager.saveUserForRemembering(VehicleProductsActivity.this, 
                                user.getEmail(), user.getName(), user.getSurname(), password, 
                                user.getUserId(), user.getPermission());
                    }
                    
                    // Kullanıcı adını güncelle
                    updateUserDisplay(user);
                    
                    dialog.dismiss();
                    loadVehicleProducts(); // Login başarılı, ürünleri yükle
                    Toast.makeText(VehicleProductsActivity.this, "Hoş geldiniz, " + user.getFullName(), Toast.LENGTH_SHORT).show();
                }
                
                @Override
                public void onLoginFailure(String message, String errorCode) {
                    Toast.makeText(VehicleProductsActivity.this, message, Toast.LENGTH_LONG).show();
                }
                
                @Override
                public void onShowLoading() {
                    loginProgressBar.setVisibility(View.VISIBLE);
                    loginButton.setEnabled(false);
                    cancelButton.setEnabled(false);
                }
                
                @Override
                public void onHideLoading() {
                    loginProgressBar.setVisibility(View.GONE);
                    loginButton.setEnabled(true);
                    cancelButton.setEnabled(true);
                }
            });
        });
        

        
        // İptal butonu
        cancelButton.setOnClickListener(v -> {
            // Uygulamayı kapat (login zorunlu)
            finish();
        });
        
        dialog.show();
    }

    private void loadVehicleProducts() {
        showLoading();
        
        // Kullanıcı ID'sini al
        int userId = 0;
        if (LoginManager.isLoggedIn(this)) {
            LoginResponse.User currentUser = LoginManager.getCurrentUser(this);
            if (currentUser != null) {
                userId = currentUser.getUserId();
                android.util.Log.d("VehicleProducts", "Kullanıcı ID: " + userId + " - " + currentUser.getFullName());
                android.util.Log.d("VehicleProducts", "Kullanıcı Email: " + currentUser.getEmail());
                android.util.Log.d("VehicleProducts", "Kullanıcı Permission: " + currentUser.getPermission());
            } else {
                android.util.Log.w("VehicleProducts", "CurrentUser null!");
            }
        } else {
            android.util.Log.w("VehicleProducts", "Kullanıcı giriş yapmamış!");
        }
        
        android.util.Log.d("VehicleProducts", "API'ye gönderilecek User ID: " + userId);
        
        Call<List<VehicleProduct>> call = apiService.getVehicleProducts(userId);
        call.enqueue(new Callback<List<VehicleProduct>>() {
            @Override
            public void onResponse(Call<List<VehicleProduct>> call, Response<List<VehicleProduct>> response) {
                hideLoading();
                
                if (response.isSuccessful() && response.body() != null) {
                    List<VehicleProduct> products = response.body();
                    
                    if (products.isEmpty()) {
                        showEmptyState();
                    } else {
                        hideEmptyState();
                        adapter.updateData(products);
                    }
                } else {
                    Toast.makeText(VehicleProductsActivity.this, 
                        "Veriler yüklenirken hata oluştu", Toast.LENGTH_SHORT).show();
                    showEmptyState();
                }
            }

            @Override
            public void onFailure(Call<List<VehicleProduct>> call, Throwable t) {
                hideLoading();
                Toast.makeText(VehicleProductsActivity.this, 
                    "Bağlantı hatası: " + t.getMessage(), Toast.LENGTH_SHORT).show();
                showEmptyState();
            }
        });
    }

    private void showLoading() {
        if (!swipeRefreshLayout.isRefreshing()) {
            progressBar.setVisibility(View.VISIBLE);
        }
        emptyStateText.setVisibility(View.GONE);
    }

    private void hideLoading() {
        progressBar.setVisibility(View.GONE);
        swipeRefreshLayout.setRefreshing(false);
    }

    private void showEmptyState() {
        emptyStateText.setVisibility(View.VISIBLE);
        recyclerView.setVisibility(View.GONE);
        deliverSelectedButton.setVisibility(View.GONE);
    }

    private void hideEmptyState() {
        emptyStateText.setVisibility(View.GONE);
        recyclerView.setVisibility(View.VISIBLE);
    }
    
    /**
     * Kullanıcı bilgilerini günceller
     */
    private void updateUserDisplay(LoginResponse.User user) {
        if (user != null && userNameText != null) {
            userNameText.setText(user.getFullName());
        }
    }
    
    /**
     * Seçili müşteri sayısına göre teslim et butonunu günceller
     */
    private void updateDeliverButton(int selectedCount) {
        if (deliverSelectedButton != null) {
            if (selectedCount > 0) {
                deliverSelectedButton.setVisibility(View.VISIBLE);
                deliverSelectedButton.setText("Seçilenleri Teslim Et (" + selectedCount + ")");
            } else {
                deliverSelectedButton.setVisibility(View.GONE);
            }
        }
    }
    
    /**
     * Seçili müşterilerin ürünlerini teslim eder
     */
    private void deliverSelectedCustomers() {
        if (adapter == null) return;
        
        // Seçili müşterileri al
        java.util.Set<String> selectedCustomers = adapter.getSelectedCustomers();
        if (selectedCustomers.isEmpty()) {
            Toast.makeText(this, "Lütfen teslim edilecek müşterileri seçin", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Kullanıcı bilgilerini al
        if (!LoginManager.isLoggedIn(this)) {
            Toast.makeText(this, "Kullanıcı girişi gerekli", Toast.LENGTH_SHORT).show();
            return;
        }
        
        LoginResponse.User currentUser = LoginManager.getCurrentUser(this);
        if (currentUser == null) {
            Toast.makeText(this, "Kullanıcı bilgileri alınamadı", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Onay dialog'u göster
        new AlertDialog.Builder(this)
                .setTitle("Teslim Onayı")
                .setMessage("Seçili " + selectedCustomers.size() + " müşterinin tüm ürünlerini teslim etmek istediğinizden emin misiniz?")
                .setPositiveButton("Evet, Teslim Et", (dialog, which) -> {
                    performDelivery(selectedCustomers, currentUser);
                })
                .setNegativeButton("İptal", null)
                .show();
    }
    
    /**
     * Teslim işlemini gerçekleştirir
     */
    private void performDelivery(java.util.Set<String> selectedCustomers, LoginResponse.User currentUser) {
        // Müşteri isimlerini virgülle ayırarak birleştir
        StringBuilder customersBuilder = new StringBuilder();
        for (String customer : selectedCustomers) {
            if (customersBuilder.length() > 0) {
                customersBuilder.append(",");
            }
            customersBuilder.append(customer);
        }
        String customersString = customersBuilder.toString();
        
        // Yükleme göster
        showLoading();
        deliverSelectedButton.setEnabled(false);
        
        // Debug: Gönderilen verileri logla
        android.util.Log.d("VehicleDelivery", "Customers: " + customersString);
        android.util.Log.d("VehicleDelivery", "UserId: " + currentUser.getUserId());
        android.util.Log.d("VehicleDelivery", "UserName: " + currentUser.getFullName());
        
        // API çağrısı
        apiService.deliverProducts(customersString, currentUser.getUserId(), currentUser.getFullName())
                .enqueue(new Callback<DeliveryResponse>() {
                    @Override
                    public void onResponse(Call<DeliveryResponse> call, Response<DeliveryResponse> response) {
                        hideLoading();
                        deliverSelectedButton.setEnabled(true);
                        
                        if (response.isSuccessful() && response.body() != null) {
                            DeliveryResponse deliveryResponse = response.body();
                            
                            if (deliveryResponse.isSuccess()) {
                                // Başarılı teslim
                                Toast.makeText(VehicleProductsActivity.this, 
                                        deliveryResponse.getMessage(), Toast.LENGTH_LONG).show();
                                
                                // Seçimleri temizle
                                adapter.clearSelections();
                                
                                // Listeyi yenile
                                loadVehicleProducts();
                            } else {
                                // Teslim başarısız
                                Toast.makeText(VehicleProductsActivity.this, 
                                        "Teslim işlemi başarısız: " + deliveryResponse.getMessage(), 
                                        Toast.LENGTH_LONG).show();
                            }
                        } else {
                            // Sunucu hatası
                            Toast.makeText(VehicleProductsActivity.this, 
                                    "Sunucu ile iletişim kurulamadı. Hata: " + response.code(), 
                                    Toast.LENGTH_LONG).show();
                        }
                    }
                    
                    @Override
                    public void onFailure(Call<DeliveryResponse> call, Throwable t) {
                        hideLoading();
                        deliverSelectedButton.setEnabled(true);
                        
                        Toast.makeText(VehicleProductsActivity.this, 
                                "İnternet bağlantınızı kontrol edin: " + t.getMessage(), 
                                Toast.LENGTH_LONG).show();
                    }
                });
    }
    
    /**
     * Ürünü depoya geri bırakır
     */
    private void returnProductToDepot(VehicleProduct product) {
        // Kullanıcı bilgilerini al
        if (!LoginManager.isLoggedIn(this)) {
            Toast.makeText(this, "Kullanıcı girişi gerekli", Toast.LENGTH_SHORT).show();
            return;
        }
        
        LoginResponse.User currentUser = LoginManager.getCurrentUser(this);
        if (currentUser == null) {
            Toast.makeText(this, "Kullanıcı bilgileri alınamadı", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Onay dialog'u göster
        new AlertDialog.Builder(this)
                .setTitle("Depoya Geri Bırak")
                .setMessage("\"" + product.getUrun_adi() + "\" ürününü depoya geri bırakmak istediğinizden emin misiniz?")
                .setPositiveButton("Evet, Geri Bırak", (dialog, which) -> {
                    performReturnToDepot(product, currentUser);
                })
                .setNegativeButton("İptal", null)
                .show();
    }
    
    /**
     * Depoya geri bırakma işlemini gerçekleştirir
     */
    private void performReturnToDepot(VehicleProduct product, LoginResponse.User currentUser) {
        // Yükleme göster
        showLoading();
        
        // Debug: Gönderilen verileri logla
        android.util.Log.d("ReturnToDepot", "ProductId: " + product.getId());
        android.util.Log.d("ReturnToDepot", "UserId: " + currentUser.getUserId());
        android.util.Log.d("ReturnToDepot", "UserName: " + currentUser.getFullName());
        
        // API çağrısı
        apiService.returnProductToDepot(product.getId(), currentUser.getUserId(), currentUser.getFullName())
                .enqueue(new Callback<ReturnToDepotResponse>() {
                    @Override
                    public void onResponse(Call<ReturnToDepotResponse> call, Response<ReturnToDepotResponse> response) {
                        hideLoading();
                        
                        // Debug: Response'u logla
                        android.util.Log.d("ReturnToDepot", "Response code: " + response.code());
                        if (response.errorBody() != null) {
                            try {
                                String errorBody = response.errorBody().string();
                                android.util.Log.d("ReturnToDepot", "Error body: " + errorBody);
                            } catch (Exception e) {
                                android.util.Log.d("ReturnToDepot", "Error reading error body: " + e.getMessage());
                            }
                        }
                        
                        if (response.isSuccessful() && response.body() != null) {
                            ReturnToDepotResponse returnResponse = response.body();
                            
                            if (returnResponse.isSuccess()) {
                                // Başarılı depoya geri bırakma
                                Toast.makeText(VehicleProductsActivity.this, 
                                        returnResponse.getMessage(), Toast.LENGTH_LONG).show();
                                
                                // Listeyi yenile
                                loadVehicleProducts();
                            } else {
                                // Depoya geri bırakma başarısız
                                Toast.makeText(VehicleProductsActivity.this, 
                                        "İşlem başarısız: " + returnResponse.getMessage(), 
                                        Toast.LENGTH_LONG).show();
                            }
                        } else {
                            // Sunucu hatası - daha detaylı hata mesajı
                            String errorMessage = "Sunucu hatası (Kod: " + response.code() + ")";
                            if (response.errorBody() != null) {
                                try {
                                    String errorBody = response.errorBody().string();
                                    if (!errorBody.isEmpty()) {
                                        errorMessage += "\nDetay: " + errorBody;
                                    }
                                } catch (Exception e) {
                                    errorMessage += "\nHata detayı okunamadı";
                                }
                            }
                            
                            Toast.makeText(VehicleProductsActivity.this, 
                                    errorMessage, Toast.LENGTH_LONG).show();
                        }
                    }
                    
                    @Override
                    public void onFailure(Call<ReturnToDepotResponse> call, Throwable t) {
                        hideLoading();
                        
                        // Debug: Hata detayını logla
                        android.util.Log.e("ReturnToDepot", "API call failed", t);
                        
                        String errorMessage = "İnternet bağlantınızı kontrol edin";
                        if (t.getMessage() != null) {
                            errorMessage += "\nDetay: " + t.getMessage();
                        }
                        
                        Toast.makeText(VehicleProductsActivity.this, 
                                errorMessage, Toast.LENGTH_LONG).show();
                    }
                });
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        if (item.getItemId() == android.R.id.home) {
            onBackPressed();
            return true;
        }
        return super.onOptionsItemSelected(item);
    }
} 