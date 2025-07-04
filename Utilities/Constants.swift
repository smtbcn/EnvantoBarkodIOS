import Foundation
import AudioToolbox

struct Constants {
    
    struct Network {
        static let defaultBaseURL = "https://envanto.app/barkodindex.asp?barcode="
        static let timeoutInterval: TimeInterval = 30.0
        static let baseURL = "https://envanto.app/barkod_yukle_android"
        static let uploadTimeout: TimeInterval = 30.0
    }
    
    struct UserDefaults {
        static let baseURL = "base_url"
        static let deviceOwner = "device_owner"
        static let isFirstLaunch = "is_first_launch"
        static let wifiOnly = "upload_wifi_only"
        static let wifiOnlyUpload = "wifi_only_upload"
        static let batteryOptimizationInfoShown = "battery_optimization_info_shown"
        static let lastUpdateCheck = "last_update_check"
    }
    
    struct Camera {
        static let autoFocusInterval: TimeInterval = 3.0
        static let scanCooldown: TimeInterval = 2.0
        static let maxZoomFactor: CGFloat = 3.0
    }
    
    struct Animation {
        static let scannerLineDuration: TimeInterval = 2.0
        static let buttonAnimationDuration: TimeInterval = 0.2
        static let fadeAnimationDuration: TimeInterval = 0.3
    }
    
    struct UI {
        static let cornerRadius: CGFloat = 12.0
        static let shadowRadius: CGFloat = 4.0
        static let scannerFrameSize: CGFloat = 280.0
        static let buttonHeight: CGFloat = 52.0
    }
    
    struct Timing {
        static let shortDelay: TimeInterval = 0.5
        static let mediumDelay: TimeInterval = 1.0
        static let longDelay: TimeInterval = 2.0
        static let updateCheckInterval: TimeInterval = 24 * 60 * 60 // 24 saat
        
        // 🔋 PIL OPTİMİZASYONU: Upload servisi timing ayarları
        static let uploadCheckInterval: TimeInterval = 60.0 // 60 saniye (önceden 10 saniye)
        static let networkChangeDelay: TimeInterval = 5.0 // Network değişikliği sonrası bekleme
        static let backgroundUploadDelay: TimeInterval = 10.0 // Background upload gecikmesi
    }
    
    struct Sounds {
        static let beepSoundID: UInt32 = 1004
        static let vibrationSoundID: UInt32 = kSystemSoundID_Vibrate
    }
    
    // MARK: - Upload Lock (Global - Duplicate Upload Prevention)
    struct UploadLock {
        static var isUploadInProgress = false
        static let uploadLock = NSLock()
        
        static func lockUpload() -> Bool {
            uploadLock.lock()
            defer { uploadLock.unlock() }
            
            if isUploadInProgress {
                return false // Upload zaten devam ediyor
            }
            
            isUploadInProgress = true
            return true // Upload başlatılabilir
        }
        
        static func unlockUpload() {
            uploadLock.lock()
            defer { uploadLock.unlock() }
            isUploadInProgress = false
        }
    }
    
    // MARK: - File Storage
    struct Storage {
        static let appFolderName = "Envanto"
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let uploadCompleted = Notification.Name("uploadCompleted")
} 
