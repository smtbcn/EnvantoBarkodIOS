import SwiftUI
import UserNotifications

@main
struct EnvantoBarkodApp: App {
    
    init() {
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
                    print("📱 App foreground'a geçti - Upload kontrol ediliyor")
                    BackgroundUploadManager.shared.checkPendingUploadsImmediately()
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
