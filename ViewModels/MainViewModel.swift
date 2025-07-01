import SwiftUI
import AVFoundation

class MainViewModel: ObservableObject {
    @Published var hasRequiredPermissions = false
    @Published var deviceOwner = ""
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadDeviceOwner()
        
        // DEBUG: ImageStorageManager test
        #if DEBUG
        ImageStorageManager.testStorageSetup()
        #endif
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
        deviceOwner = owner
        userDefaults.set(owner, forKey: Constants.UserDefaults.deviceOwner)
    }
} 