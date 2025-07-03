import SwiftUI
import UserNotifications

@main
struct EnvantoBarkodApp: App {
    
    init() {
        // Background upload manager'ı başlat
        _ = BackgroundUploadManager.shared
        
        // Notification izni iste
        requestNotificationPermission()
        
        // App başlarken upload kontrol et
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🚀 App başladı - İlk upload kontrol")
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
