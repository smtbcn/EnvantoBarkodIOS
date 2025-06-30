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
                    SQLiteManager.shared.saveCihazYetki(deviceId: deviceId, deviceOwner: authResponse.deviceOwner ?? "", isAuthorized: true)
                    
                    print("✅ Cihaz yetkili: \(authResponse.message)")
                    callback.onAuthSuccess()
                } else {
                    // Cihaz yetkili değil
                    UserDefaults.standard.set(false, forKey: "device_auth_checked")
                    
                    // Yerel veritabanına kaydet (başarısız)
                    SQLiteManager.shared.saveCihazYetki(deviceId: deviceId, deviceOwner: "", isAuthorized: false)
                    
                    print("❌ Cihaz yetkili değil: \(authResponse.message)")
                    
                    // Uyarı diyaloğu göster
                    showAuthorizationErrorAlert(message: authResponse.message, deviceId: deviceId)
                    callback.onAuthFailure()
                }
                
            case .failure(let error):
                // Sunucu hatası - yerel veritabanından kontrol et
                let isLocallyAuthorized = SQLiteManager.shared.isCihazOnaylanmis(deviceId)
                
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
            showToast(message: "Cihaz kimliği panoya kopyalandı")
            
            // Uygulamayı kapat (Android'deki gibi)
            exit(0)
        })
        
        // Kapat (Android'deki gibi)
        alert.addAction(UIAlertAction(title: "Kapat", style: .cancel) { _ in
            // Uygulamayı kapat (Android'deki gibi)
            exit(0)
        })
        
        rootViewController.present(alert, animated: true)
    }
    
    // MARK: - Toast mesajı göster (Android uyumlu)
    @MainActor
    private static func showToast(message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        let toastContainer = UIView()
        toastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toastContainer.layer.cornerRadius = 10
        toastContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        toastContainer.addSubview(messageLabel)
        window.addSubview(toastContainer)
        
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -16),
            messageLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -8),
            
            toastContainer.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            toastContainer.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -64)
        ])
        
        // Android'deki gibi 2 saniye göster
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.3, animations: {
                toastContainer.alpha = 0
            }) { _ in
                toastContainer.removeFromSuperview()
            }
        }
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