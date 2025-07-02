import SwiftUI
import AVFoundation

class MainViewModel: ObservableObject {
    @Published var hasRequiredPermissions = false
    @Published var deviceOwner = ""
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadDeviceOwner()
    }
    
    // MARK: - Kamera izinleri kontrolü
    func checkPermissions() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraStatus {
        case .authorized:
            hasRequiredPermissions = true
        case .notDetermined:
            requestCameraPermission()
        case .denied, .restricted:
            hasRequiredPermissions = false
        @unknown default:
            hasRequiredPermissions = false
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasRequiredPermissions = granted
            }
        }
    }
    
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func loadDeviceOwner() {
        // DeviceAuthManager'dan gelen cihaz sahibini al
        if let authOwner = userDefaults.string(forKey: "device_owner"), !authOwner.isEmpty {
            deviceOwner = authOwner
        } else {
            // Fallback: Constants'tan al
            deviceOwner = userDefaults.string(forKey: Constants.UserDefaults.deviceOwner) ?? ""
        }
    }
    
    func updateDeviceOwner(_ owner: String) {
        let oldOwner = deviceOwner
        deviceOwner = owner
        userDefaults.set(owner, forKey: Constants.UserDefaults.deviceOwner)
        
        // Veritabanındaki mevcut kayıtları güncelle (eski cihaz bilgisinden yeni cihaz sahibine)
        if !oldOwner.isEmpty && !owner.isEmpty && oldOwner != owner {
            let dbManager = DatabaseManager.getInstance()
            let updated = dbManager.updateYukleyenInfo(oldYukleyen: oldOwner, newYukleyen: owner)
            if updated {
                print("🔄 Veritabanında cihaz sahibi bilgisi güncellendi: \(oldOwner) → \(owner)")
            }
        }
    }
} 