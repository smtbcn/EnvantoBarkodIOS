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
                
                // Upload İşlemleri
                Section(header: Text("Upload İşlemleri")) {
                    Button(action: {
                        manualUpload()
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(.green)
                            Text("Şimdi Yükle (Manuel)")
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button(action: {
                        testWiFiNotification()
                    }) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.orange)
                            Text("WiFi Notification Test")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Button(action: {
                        testScheduledReminder()
                    }) {
                        HStack {
                            Image(systemName: "clock.badge")
                                .foregroundColor(.purple)
                            Text("Scheduled Reminder Test")
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                // Database İşlemleri
                Section(header: Text("Database İşlemleri")) {
                    Button(action: {
                        testDatabase()
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.purple)
                            Text("Database Test Çalıştır")
                                .foregroundColor(.purple)
                        }
                    }
                    
                    Button(action: {
                        importExistingImages()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.blue)
                            Text("Mevcut Resimleri Database'e Aktar")
                                .foregroundColor(.blue)
                        }
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
        
        // WiFi only ayarını yükle (Android uyumlu key kullan)
        wifiOnlyUpload = UserDefaults.standard.bool(forKey: Constants.UserDefaults.wifiOnly)
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
        wifiOnlyUpload = false
        viewModel.updateDeviceOwner("")
    }
    
    private func testDatabase() {
        
        let dbManager = DatabaseManager.getInstance()
        dbManager.testDatabaseOperations()
    }
    
    private func importExistingImages() {
        
        let dbManager = DatabaseManager.getInstance()
        dbManager.importExistingImages()
        
        // Upload servisini yeniden başlat
        updateUploadService()
    }
    
    private func manualUpload() {
        print("📤 Manuel upload tetiklendi")
        
        // İki yöntemle de upload'u tetikle
        
        // 1. BackgroundUploadManager ile
        BackgroundUploadManager.shared.checkPendingUploadsImmediately()
        
        // 2. UploadService ile (eski method)
        UploadService.shared.startUploadService(wifiOnly: wifiOnlyUpload)
        
        // Kullanıcıya feedback ver
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func testWiFiNotification() {
        print("🔔 WiFi notification test")
        
        // Force notification test - BackgroundUploadManager'daki private metodu bypass et
        let content = UNMutableNotificationContent()
        content.title = "📶 WiFi Test Notification"
        content.body = "Bu bir test bildirimidir. WiFi bağlantısında bu notification gelecek."
        content.sound = UNNotificationSound.default
        content.badge = NSNumber(value: 5) // Test badge
        
        content.categoryIdentifier = "WIFI_UPLOAD_CATEGORY"
        content.userInfo = ["action": "open_app_for_upload", "pendingCount": 5]
        
        let request = UNNotificationRequest(
            identifier: "wifi_test_notification",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification hatası: \(error)")
            } else {
                print("✅ Test notification gönderildi")
            }
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func testScheduledReminder() {
        print("⏰ Scheduled reminder test")
        
        // 5 saniye sonra çalışacak test reminder
        let content = UNMutableNotificationContent()
        content.title = "⏰ Scheduled Reminder Test"
        content.body = "Bu bir test scheduled reminder'ıdır. Force-quit durumunda bu tür notification'lar çalışır."
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "UPLOAD_REMINDER_CATEGORY"
        content.userInfo = ["action": "check_uploads", "scheduled": true]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "test_scheduled_reminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test scheduled reminder hatası: \(error)")
            } else {
                print("✅ Test scheduled reminder zamanlandı (5 saniye sonra)")
            }
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
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
