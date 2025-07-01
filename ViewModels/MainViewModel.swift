import SwiftUI
import AVFoundation

class MainViewModel: ObservableObject, DeviceAuthCallback {
    @Published var hasRequiredPermissions = false
    @Published var deviceOwner = ""
    @Published var isLoading = false
    @Published var isDeviceAuthorized = false
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadDeviceOwner()
        checkDeviceAuthorization()
    }
    
    // MARK: - Cihaz yetkilendirme kontrolü (Android template ile aynı)
    func checkDeviceAuthorization() {
        DeviceAuthManager.checkDeviceAuthorization(callback: self)
    }
    
    // MARK: - Sessiz cihaz yetkilendirme kontrolü (Main ve Scanner için)
    func checkDeviceAuthorizationSilently() {
        let silentCallback = SilentDeviceAuthCallback { [weak self] isAuthorized in
            DispatchQueue.main.async {
                self?.isDeviceAuthorized = isAuthorized
                if isAuthorized {
                    self?.loadDeviceOwner()
                    self?.checkPermissions()
                }
            }
        }
        DeviceAuthManager.checkDeviceAuthorization(callback: silentCallback)
    }
    
    // MARK: - DeviceAuthCallback implementasyonu
    func onAuthSuccess() {
        DispatchQueue.main.async {
            self.isDeviceAuthorized = true
            self.loadDeviceOwner() // Güncel cihaz sahibini yükle
            self.checkPermissions() // İzinleri kontrol et
        }
    }
    
    func onAuthFailure() {
        DispatchQueue.main.async {
            self.isDeviceAuthorized = false
            // Activity kapanacak veya ana menüde kalacak
        }
    }
    
    func onShowLoading() {
        DispatchQueue.main.async {
            self.isLoading = true
        }
    }
    
    func onHideLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
        }
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