import SwiftUI
import UserNotifications

@main
struct EnvantoBarkodApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Background upload manager'ı başlat
        _ = BackgroundUploadManager.shared
        
        // Notification izni iste
        requestNotificationPermission()
        
        // App başlarken upload kontrol et
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🚀 App başladı - İlk upload kontrol")
            
            // Force-quit durumu için app launch check
            BackgroundUploadManager.shared.checkUploadsOnAppLaunch()
            
            // Normal upload check
            BackgroundUploadManager.shared.checkPendingUploadsImmediately()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Uygulama arka plana geçtiğinde background task zamanla
                    print("📱 App background'a geçti - Background upload zamanlanıyor")
                    BackgroundUploadManager.shared.scheduleBackgroundUpload()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Uygulama foreground'a geçtiğinde pending upload'ları kontrol et
                    print("📱 App foreground'a geçti - Upload kontrol ediliyor")
                    BackgroundUploadManager.shared.checkPendingUploadsImmediately()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // App aktif olduğunda da kontrol et (daha agresif)
                    print("📱 App aktif oldu - Agresif upload kontrol")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        BackgroundUploadManager.shared.checkPendingUploadsImmediately()
                    }
                }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification izni verildi")
            } else {
                print("❌ Notification izni reddedildi")
            }
        }
    }
}

// MARK: - AppDelegate for Notification Handling
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Notification delegate'i ayarla
        UNUserNotificationCenter.current().delegate = self
        
        // Notification kategorilerini kaydet
        setupNotificationCategories()
        
        return true
    }
    
    // MARK: - Notification Categories
    private func setupNotificationCategories() {
        let uploadAction = UNNotificationAction(
            identifier: "UPLOAD_ACTION",
            title: "Şimdi Yükle",
            options: [.foreground]
        )
        
        let checkAction = UNNotificationAction(
            identifier: "CHECK_ACTION",
            title: "Kontrol Et",
            options: [.foreground]
        )
        
        let wifiCategory = UNNotificationCategory(
            identifier: "WIFI_UPLOAD_CATEGORY",
            actions: [uploadAction],
            intentIdentifiers: [],
            options: []
        )
        
        let reminderCategory = UNNotificationCategory(
            identifier: "UPLOAD_REMINDER_CATEGORY",
            actions: [checkAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([wifiCategory, reminderCategory])
    }
    
    // MARK: - Notification Response Handling
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        if let action = userInfo["action"] as? String {
            switch action {
            case "open_app_for_upload":
                print("📱 Kullanıcı WiFi notification'ına tıkladı - Upload başlatılıyor")
                
                // Uygulama açıldığında upload'u başlat
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    BackgroundUploadManager.shared.checkPendingUploadsImmediately()
                }
                
            case "check_uploads":
                print("📱 Kullanıcı scheduled reminder'a tıkladı - Upload kontrol ediliyor")
                
                // Scheduled reminder'dan gelen tıklama
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    BackgroundUploadManager.shared.checkUploadsOnAppLaunch()
                }
                
            default:
                break
            }
        }
        
        // Badge'i temizle
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        completionHandler()
    }
    
    // MARK: - Foreground Notification Handling
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // App foreground'dayken de notification göster
        completionHandler([.alert, .sound, .badge])
    }
} 
