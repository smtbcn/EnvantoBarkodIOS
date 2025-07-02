import Foundation
import AudioToolbox

struct Constants {
    
    struct Network {
        static let defaultBaseURL = "https://envanto.app/barkodindex.asp?barcode="
        static let timeoutInterval: TimeInterval = 30.0
    }
    
    struct UserDefaults {
        static let baseURL = "base_url"
        static let deviceOwner = "device_owner"
        static let isFirstLaunch = "is_first_launch"
        static let wifiOnly = "wifi_only" // Android uyumlu key
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
    }
    
    struct Sounds {
        static let beepSoundID: UInt32 = 1004
        static let vibrationSoundID: UInt32 = kSystemSoundID_Vibrate
    }
} 