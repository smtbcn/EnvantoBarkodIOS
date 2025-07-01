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

// MARK: - Network Error
enum NetworkError: Error {
    case invalidURL
    case serverError
    case noData
    case decodingError
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
    
    // MARK: - Hızlı cihaz yetki kontrolü (Android showPermissionRequiredDialog benzeri)
    @MainActor
    static func showDeviceAuthDialog(on presentingController: UIViewController? = nil, onAuth: @escaping (Bool) -> Void) {
        let deviceId = DeviceIdentifier.getUniqueDeviceId()
        
        // Önce hızlı yerel kontrol yap
        if checkLocalAuthorization(deviceId: deviceId) {
            onAuth(true)
            return
        }
        
        // Yerel yetki yok, kullanıcıya bilgi ver
        let alert = UIAlertController(
            title: "🔐 Cihaz Yetkilendirme Gerekli",
            message: """
            Bu özelliği kullanabilmek için cihazınızın yetkilendirilmesi gerekiyor.
            
            📱 Uygulama düzgün çalışabilmesi için cihaz yetkilendirmesi gereklidir.
            
            Cihaz Kimliği: \(deviceId)
            
            Bu kimliği sistem yöneticinize ileterek yetkilendirme talebinde bulunun.
            """,
            preferredStyle: .alert
        )
        
        // Cihaz ID'yi kopyala butonu
        alert.addAction(UIAlertAction(title: "📋 Cihaz Kimliği Kopyala", style: .default) { _ in
            UIPasteboard.general.string = deviceId
            showToast(message: "Cihaz kimliği panoya kopyalandı")
            onAuth(false)
        })
        
        // Yetkilendirmeyi kontrol et butonu
        alert.addAction(UIAlertAction(title: "🔄 Yetkilendirmeyi Kontrol Et", style: .default) { _ in
            // Tam yetkilendirme kontrolü yap
            let callback = SimpleDeviceAuthCallback { success in
                DispatchQueue.main.async {
                    if success {
                        showToast(message: "✅ Cihaz yetkilendirildi!")
                    } else {
                        showToast(message: "❌ Cihaz henüz yetkilendirilmemiş")
                    }
                    onAuth(success)
                }
            }
            checkDeviceAuthorization(callback: callback)
        })
        
        // İptal butonu
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel) { _ in
            onAuth(false)
        })
        
        // Dialog'u göster
        if let presenter = presentingController {
            presenter.present(alert, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
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
            
            print("🔐 Cihaz Kimliği: \(deviceId)")
            print("📱 Cihaz Bilgileri: \(DeviceIdentifier.getReadableDeviceInfo())")
            
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
            // API endpoint URL'i oluştur (Android'deki gibi usersperm.asp)
            guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
                  let url = URL(string: "\(baseURL)usersperm.asp") else {
                throw NetworkError.invalidURL
            }
            
            // Request oluştur
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 3.0 // 3 saniyelik timeout (Android'deki gibi)
            
            // Body parametreleri (Android ApiService ile aynı)
            let bodyString = "action=check&cihaz_bilgisi=\(deviceId)"
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
    
    // MARK: - Yetkilendirme hatası uyarısı (Android uyumlu)
    @MainActor
    private static func showAuthorizationErrorAlert(message: String, deviceId: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        // Android'deki gibi detaylı mesaj
        let detailedMessage = """
        \(message)
        
        Cihaz Kimliği: \(deviceId)
        
        Lütfen bu kimliği sistem yöneticisine iletin.
        """
        
        let alert = UIAlertController(
            title: "Cihaz Yetkilendirme Gerekli",
            message: detailedMessage,
            preferredStyle: .alert
        )
        
        // Cihaz ID'yi kopyala (Android'deki gibi)
        alert.addAction(UIAlertAction(title: "Cihaz Kimliği Kopyala", style: .default) { _ in
            UIPasteboard.general.string = deviceId
            
            // Android'deki gibi toast göster
            DispatchQueue.main.async {
                showToast(message: "Cihaz kimliği panoya kopyalandı")
            }
        })
        
        // Tamam (Android'deki gibi)
        alert.addAction(UIAlertAction(title: "Tamam", style: .cancel) { _ in
            // Ana menüye dön (Android'deki gibi finish() davranışı)
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

// MARK: - Simple Callback Implementation
class SimpleDeviceAuthCallback: DeviceAuthCallback {
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
        // Basit callback için loading gösterme yok
    }
    
    func onHideLoading() {
        // Basit callback için loading gizleme yok
    }
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