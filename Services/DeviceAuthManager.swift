import Foundation
import SwiftUI
import UIKit

// MARK: - DeviceAuthCallback Protocol
protocol DeviceAuthCallback {
    func onAuthSuccess()
    func onAuthFailure()
    func onShowLoading()
    func onHideLoading()
}

// MARK: - SilentDeviceAuthCallback (UI'ı etkilemeden sessiz kontrol)
class SilentDeviceAuthCallback: DeviceAuthCallback {
    private let completion: (Bool) -> Void
    
    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }
    
    func onAuthSuccess() {
        completion(true)
    }
    
    func onAuthFailure() {
        completion(false)
    }
    
    func onShowLoading() {
        // Sessiz modda loading gösterme
    }
    
    func onHideLoading() {
        // Sessiz modda loading gizleme
    }
}

// MARK: - DeviceAuthResponse Model
struct DeviceAuthResponse: Codable {
    let success: Bool
    let message: String
    let deviceOwner: String?
    
    private enum CodingKeys: String, CodingKey {
        case success
        case message
        case deviceOwner = "device_owner"
    }
}

// MARK: - DeviceAuthManager
class DeviceAuthManager {
    static let shared = DeviceAuthManager()
    private init() {}
    
    // MARK: - Ana cihaz yetkilendirme kontrol metodu
    static func checkDeviceAuthorization(callback: DeviceAuthCallback) {
        Task {
            await performDeviceAuth(callback: callback)
        }
    }
    
    @MainActor
    private static func performDeviceAuth(callback: DeviceAuthCallback) async {
        do {
            // Yükleme başlat
            callback.onShowLoading()
            
            // Cihaz kimliğini al
            let deviceId = DeviceIdentifier.getUniqueDeviceId()
            let deviceInfo = DeviceIdentifier.getReadableDeviceInfo()
            
            print("🔐 Cihaz Kimliği: \(deviceId)")
            print("📱 Cihaz Bilgileri: \(deviceInfo)")
            
            // İlk kayıt kontrolü (Android mantığı)
            let isFirstRun = !UserDefaults.standard.bool(forKey: "device_registered_to_server")
            
            if isFirstRun {
                print("🆕 İlk çalıştırma tespit edildi, cihaz sunucuya kaydediliyor...")
                let registerResult = await registerDeviceToServer(deviceId: deviceId, deviceInfo: deviceInfo)
                
                // Kayıt işleminin sonucuna bakılmaksızın, flag'i set et
                UserDefaults.standard.set(true, forKey: "device_registered_to_server")
                
                switch registerResult {
                case .success(let response):
                    print("📝 Kayıt sonucu: \(response.message)")
                case .failure(let error):
                    print("⚠️ Kayıt hatası (devam ediliyor): \(error.localizedDescription)")
                }
                
                // Kısa bekleme süresi
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 saniye
            }
            
            // Sunucudan cihaz yetkilendirme kontrolü
            let result = await checkServerAuthorization(deviceId: deviceId)
            
            // Kısa bir bekleme süresi (Android'deki LOADING_DIALOG_DELAY gibi)
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 saniye
            
            // Yükleme gizle
            callback.onHideLoading()
            
            switch result {
            case .success(let authResponse):
                if authResponse.success {
                    // Cihaz yetkili
                    UserDefaults.standard.set(true, forKey: "device_auth_checked")
                    
                    // Cihaz sahibini kaydet
                    if let deviceOwner = authResponse.deviceOwner {
                        UserDefaults.standard.set(deviceOwner, forKey: "device_owner")
                    }
                    
                    // Yerel veritabanına kaydet (başarılı)
                    saveLocalDeviceAuth(deviceId: deviceId, deviceOwner: authResponse.deviceOwner ?? "", isAuthorized: true)
                    
                    print("✅ Cihaz yetkili: \(authResponse.message)")
                    callback.onAuthSuccess()
                } else {
                    // Cihaz yetkili değil
                    UserDefaults.standard.set(false, forKey: "device_auth_checked")
                    
                    // Yerel veritabanına kaydet (başarısız)
                    saveLocalDeviceAuth(deviceId: deviceId, deviceOwner: "", isAuthorized: false)
                    
                    print("❌ Cihaz yetkili değil: \(authResponse.message)")
                    
                    // Uyarı diyaloğu göster
                    showAuthorizationErrorAlert(message: authResponse.message, deviceId: deviceId)
                    callback.onAuthFailure()
                }
                
            case .failure(let error):
                // Sunucu hatası - yerel veritabanından kontrol et
                let isLocallyAuthorized = checkLocalAuthorization(deviceId: deviceId)
                
                if isLocallyAuthorized {
                    print("🔄 Sunucu hatası, yerel veritabanında onaylı")
                    callback.onAuthSuccess()
                } else {
                    print("💥 Sunucu hatası ve yerel yetki yok: \(error.localizedDescription)")
                    
                    let errorMessage = "Sunucu ile iletişim kurulamadı. Lütfen internet bağlantınızı kontrol edin ve cihazınızın yetkilendirildiğinden emin olun."
                    showAuthorizationErrorAlert(message: errorMessage, deviceId: deviceId)
                    callback.onAuthFailure()
                }
            }
            
        } catch {
            callback.onHideLoading()
            print("💥 DeviceAuthManager genel hatası: \(error.localizedDescription)")
            callback.onAuthFailure()
        }
    }
    
    // MARK: - Sunucu yetkilendirme kontrolü
    private static func checkServerAuthorization(deviceId: String) async -> Result<DeviceAuthResponse, Error> {
        do {
            // API endpoint URL'i oluştur
            guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
                  let url = URL(string: "\(baseURL)/check_device_auth.php") else {
                throw NetworkError.invalidURL
            }
            
            // Request oluştur
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 3.0 // 3 saniyelik timeout (Android'deki gibi)
            
            // Body parametreleri
            let bodyString = "action=check&device_id=\(deviceId)"
            request.httpBody = bodyString.data(using: .utf8)
            
            // API çağrısı yap
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // HTTP yanıt kontrolü
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NetworkError.serverError
            }
            
            // JSON decode et
            let authResponse = try JSONDecoder().decode(DeviceAuthResponse.self, from: data)
            return .success(authResponse)
            
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Cihaz ID'sini sunucuya kaydet (Android mantığı)
    static func registerDeviceToServer(deviceId: String, deviceInfo: String) async -> Result<DeviceAuthResponse, Error> {
        do {
            // API endpoint URL'i oluştur
            guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
                  let url = URL(string: "\(baseURL)/check_device_auth.php") else {
                throw NetworkError.invalidURL
            }
            
            // Request oluştur
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 5.0 // 5 saniyelik timeout (kayıt için biraz daha uzun)
            
            // Body parametreleri - Android'deki gibi
            let bodyString = "action=register&device_id=\(deviceId)&device_info=\(deviceInfo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            request.httpBody = bodyString.data(using: .utf8)
            
            print("📝 Cihaz kayıt işlemi başlatılıyor...")
            print("🔗 URL: \(url)")
            print("📋 Parametreler: \(bodyString)")
            
            // API çağrısı yap
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // HTTP yanıt kontrolü
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NetworkError.serverError
            }
            
            // JSON decode et
            let authResponse = try JSONDecoder().decode(DeviceAuthResponse.self, from: data)
            
            if authResponse.success {
                print("✅ Cihaz sunucuya başarıyla kaydedildi: \(authResponse.message)")
            } else {
                print("⚠️ Cihaz kayıt yanıtı: \(authResponse.message)")
            }
            
            return .success(authResponse)
            
        } catch {
            print("💥 Cihaz kayıt hatası: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    // MARK: - Yerel yetkilendirme kontrolü
    private static func checkLocalAuthorization(deviceId: String) -> Bool {
        // UserDefaults'tan yerel yetki durumunu kontrol et
        // TODO: Gerçek uygulamada Core Data veya SQLite kullanılabilir
        let key = "local_device_auth_\(deviceId)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    // MARK: - Yerel yetkilendirme kaydet
    private static func saveLocalDeviceAuth(deviceId: String, deviceOwner: String, isAuthorized: Bool) {
        // UserDefaults'a yerel yetki durumunu kaydet
        // TODO: Gerçek uygulamada Core Data veya SQLite kullanılabilir
        let key = "local_device_auth_\(deviceId)"
        UserDefaults.standard.set(isAuthorized, forKey: key)
        
        if !deviceOwner.isEmpty {
            UserDefaults.standard.set(deviceOwner, forKey: "device_owner")
        }
    }
    
    // MARK: - Yetkilendirme hatası uyarısı
    @MainActor
    private static func showAuthorizationErrorAlert(message: String, deviceId: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "Yetkilendirme Hatası",
            message: message,
            preferredStyle: .alert
        )
        
        // Cihaz ID kopyala
        alert.addAction(UIAlertAction(title: "Cihaz ID Kopyala", style: .default) { _ in
            UIPasteboard.general.string = deviceId
            
            // Toast benzeri bildirim göster
            DispatchQueue.main.async {
                showToast(message: "Cihaz kimliği kopyalandı")
            }
        })
        
        // Kapat
        alert.addAction(UIAlertAction(title: "Kapat", style: .cancel) { _ in
            // Ana menüye dön veya uygulamayı kapat
            if let navigationController = rootViewController as? UINavigationController {
                navigationController.popToRootViewController(animated: true)
            }
        })
        
        rootViewController.present(alert, animated: true)
    }
    
    // MARK: - Toast göster
    @MainActor
    private static func showToast(message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 12.0)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        
        let toastWidth: CGFloat = 250
        let toastHeight: CGFloat = 35
        
        toastLabel.frame = CGRect(
            x: (window.frame.size.width - toastWidth) / 2,
            y: window.frame.size.height - 100,
            width: toastWidth,
            height: toastHeight
        )
        
        window.addSubview(toastLabel)
        
        UIView.animate(withDuration: 2.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: { _ in
            toastLabel.removeFromSuperview()
        })
    }
}

// MARK: - NetworkError
enum NetworkError: Error {
    case invalidURL
    case serverError
    case decodingError
}

// MARK: - DeviceIdentifier
class DeviceIdentifier {
    
    // MARK: - Benzersiz cihaz kimliği al
    static func getUniqueDeviceId() -> String {
        // iOS'da IDFV (Identifier for Vendor) kullan
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            return idfv
        }
        
        // Fallback: UserDefaults'tan kayıtlı UUID kullan veya yeni oluştur
        let key = "app_device_uuid"
        if let savedUUID = UserDefaults.standard.string(forKey: key) {
            return savedUUID
        }
        
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: key)
        return newUUID
    }
    
    // MARK: - Okunabilir cihaz bilgileri
    static func getReadableDeviceInfo() -> String {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = device.model
        let name = device.name
        
        return "\(name) - \(model) - iOS \(systemVersion)"
    }
} 