import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var baseURL = ""
    @State private var deviceOwner = ""
    @State private var wifiOnlyUpload = false
    @State private var showingURLAlert = false
    @State private var showingResetAlert = false
    @State private var showingClearDatabaseAlert = false
    
    var body: some View {
        Form {
                // Genel Ayarlar
                Section(header: Text("Genel Ayarlar")) {
                    HStack {
                        Text("Cihaz Sahibi")
                        Spacer()
                        TextField("Cihaz sahibi adı", text: $deviceOwner)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 200)
                    }
                    
                    HStack {
                        Text("Base URL")
                        Spacer()
                        Button(action: {
                            showingURLAlert = true
                        }) {
                            Text(baseURL.isEmpty ? "Ayarla" : "Değiştir")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if !baseURL.isEmpty {
                        Text(baseURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                // Yükleme Ayarları
                Section(header: Text("Yükleme Ayarları")) {
                    Toggle("Sadece WiFi ile yükle", isOn: $wifiOnlyUpload)
                }
                
                // Uygulama Bilgileri
                Section(header: Text("Uygulama Bilgileri")) {
                    HStack {
                        Text("Versiyon")
                        Spacer()
                        Text(Bundle.main.appVersionLong)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Uygulama Adı")
                        Spacer()
                        Text(Bundle.main.appName)
                            .foregroundColor(.secondary)
                    }
                }
                

                
                // Tehlikeli İşlemler
                Section(header: Text("Tehlikeli İşlemler")) {
                    Button(action: {
                        showingClearDatabaseAlert = true
                    }) {
                        HStack {
                            Image(systemName: "externaldrive.badge.minus")
                                .foregroundColor(.orange)
                            Text("Resim Veritabanını Temizle")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Tüm Ayarları Sıfırla")
                                .foregroundColor(.red)
                        }
                    }
                }
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Kaydet") {
                    saveSettings()
                }
            }
        }
        .alert("Base URL Ayarla", isPresented: $showingURLAlert) {
            TextField("https://örnek.com/api", text: $baseURL)
            Button("Kaydet") {
                if baseURL.isValidURL {
                    UserDefaults.standard.set(baseURL, forKey: Constants.UserDefaults.baseURL)
                }
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Barkod tarama sonuçlarının yönlendirileceği base URL'yi girin.")
        }
        .alert("Ayarları Sıfırla", isPresented: $showingResetAlert) {
            Button("Sıfırla", role: .destructive) {
                resetAllSettings()
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Tüm ayarlar varsayılan değerlere sıfırlanacak. Bu işlem geri alınamaz.")
        }
        .alert("Resim Veritabanını Temizle", isPresented: $showingClearDatabaseAlert) {
            Button("Temizle", role: .destructive) {
                clearDatabase()
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Barkod resim veritabanındaki tüm kayıtlar silinecek. Dosyalar korunur ancak yükleme geçmişi kaybolur. Bu işlem geri alınamaz.")
        }
        .onAppear {
            loadSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            // UserDefaults değiştiğinde ayarları yeniden yükle
            DispatchQueue.main.async {
                loadSettings()
            }
        }
    }
    
    private func loadSettings() {
        deviceOwner = viewModel.deviceOwner
        baseURL = UserDefaults.standard.string(forKey: Constants.UserDefaults.baseURL) ?? Constants.Network.defaultBaseURL
        
        // WiFi only ayarını yükle (Default: true)
        wifiOnlyUpload = UserDefaults.standard.object(forKey: Constants.UserDefaults.wifiOnly) as? Bool ?? true
    }
    
    private func saveSettings() {
        viewModel.updateDeviceOwner(deviceOwner)
        UserDefaults.standard.set(baseURL, forKey: Constants.UserDefaults.baseURL)
        
        // WiFi only ayarını kaydet (Android uyumlu key kullan)
        UserDefaults.standard.set(wifiOnlyUpload, forKey: Constants.UserDefaults.wifiOnly)
        
        // Upload servisini güncelle
        updateUploadService()
    }
    
    private func updateUploadService() {
        // Upload servisini yeni ayarlarla yeniden başlat
        UploadService.shared.startUploadService(wifiOnly: wifiOnlyUpload)
        
    }
    
    private func resetAllSettings() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        // Değerleri sıfırla
        deviceOwner = ""
        baseURL = Constants.Network.defaultBaseURL
        wifiOnlyUpload = true
        viewModel.updateDeviceOwner("")
    }
    

    
    private func clearDatabase() {
        // Database'deki tüm barkod resim kayıtlarını temizle
        let dbManager = DatabaseManager.getInstance()
        let success = dbManager.clearAllBarkodResimler()
        
        if success {
            UploadService.shared.stopUploadService()
        }
    }
}

#Preview {
    SettingsView(viewModel: MainViewModel())
} 
