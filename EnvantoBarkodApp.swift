import SwiftUI
import UserNotifications

@main
struct EnvantoBarkodApp: App {
    
    init() {
        // İlk açılış kontrolü ve default ayarları kaydet
        setupDefaultSettings()
        
        // Background upload manager'ı başlat
        _ = BackgroundUploadManager.shared
        
        // Notification izni iste
        requestNotificationPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Uygulama arka plana geçtiğinde background task zamanla
                    BackgroundUploadManager.shared.scheduleBackgroundUpload()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Uygulama foreground'a geçtiğinde pending upload'ları kontrol et
        
                    BackgroundUploadManager.shared.checkPendingUploadsImmediately()
                }
        }
    }
    
    // MARK: - İlk açılış ve default ayarlar
    private func setupDefaultSettings() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: Constants.UserDefaults.isFirstLaunch)
        
        if isFirstLaunch {
            // İlk açılış - default ayarları kaydet
            UserDefaults.standard.set(true, forKey: Constants.UserDefaults.isFirstLaunch)
            UserDefaults.standard.set(true, forKey: Constants.UserDefaults.wifiOnly) // 🔥 DEFAULT: Sadece WiFi AÇIK
            UserDefaults.standard.set(Constants.Network.defaultBaseURL, forKey: Constants.UserDefaults.baseURL)
            
            // Ayarları hemen kaydet
            UserDefaults.standard.synchronize()
        }
    }
    
    private func requestNotificationPermission() {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
} 
