import SwiftUI
import AVFoundation

class MainViewModel: ObservableObject {
    @Published var hasRequiredPermissions = false
    @Published var deviceOwner = ""
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadDeviceOwner()
        checkPermissions()
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
        // Constants'tan cihaz sahibini al
        deviceOwner = userDefaults.string(forKey: Constants.UserDefaults.deviceOwner) ?? ""
    }
    
    func updateDeviceOwner(_ owner: String) {
        deviceOwner = owner
        userDefaults.set(owner, forKey: Constants.UserDefaults.deviceOwner)
    }
} 