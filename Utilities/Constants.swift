import Foundation
import AudioToolbox

struct Constants {
    
    struct Network {
        static let defaultBaseURL = "https://envanto.app/barkodindex.asp?barcode="
        static let timeoutInterval: TimeInterval = 30.0
    }
    
    struct UserDefaults {
        static let baseURL = "base_url"
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
    
    struct Sounds {
        static let beepSoundID: UInt32 = 1004
        static let vibrationSoundID: UInt32 = kSystemSoundID_Vibrate
    }
} 