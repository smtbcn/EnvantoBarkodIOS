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



// MARK: - DeviceAuthResponse Model
struct DeviceAuthResponse: Codable {
    let success: Bool
    let message: String
    let deviceOwner: String?
    
    private enum CodingKeys: String, CodingKey {
        case success
        case message
        case deviceOwner = "cihaz_sahibi"
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
            
            // ASP dosyası otomatik kayıt yapıyor, ayrı register işlemi gerekmiyor
            print("📝 Sunucu otomatik cihaz kaydı yapacak...")
            
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
                    
                    // Cihaz sahibini kaydet (hem UserDefaults hem MainViewModel için)
                    if let deviceOwner = authResponse.deviceOwner, !deviceOwner.isEmpty {
                        UserDefaults.standard.set(deviceOwner, forKey: "device_owner")
                        UserDefaults.standard.set(deviceOwner, forKey: Constants.UserDefaults.deviceOwner)
                        print("👤 Cihaz sahibi kaydedildi: \(deviceOwner)")
                    }
                    
                    // SQLite cihaz yetki tablosuna kaydet (Android mantığı)
                    let dbManager = DatabaseManager.getInstance()
                    let saved = dbManager.saveCihazYetki(
                        cihazBilgisi: deviceId, 
                        cihazSahibi: authResponse.deviceOwner ?? "", 
                        cihazOnay: 1
                    )
                    
                    if saved {
                        print("✅ Cihaz yetkisi SQLite'a kaydedildi")
                    }
                    
                    print("✅ Cihaz yetkili: \(authResponse.message)")
                    callback.onAuthSuccess()
                } else {
                    // Cihaz yetkili değil
                    UserDefaults.standard.set(false, forKey: "device_auth_checked")
                    
                    // SQLite cihaz yetki tablosuna kaydet (yetkisiz)
                    let dbManager = DatabaseManager.getInstance()
                    let saved = dbManager.saveCihazYetki(
                        cihazBilgisi: deviceId, 
                        cihazSahibi: authResponse.deviceOwner ?? "", 
                        cihazOnay: 0
                    )
                    
                    print("❌ Cihaz yetkili değil: \(authResponse.message)")
                    
                    // Uyarı diyaloğu göster
                    showAuthorizationErrorAlert(message: authResponse.message, deviceId: deviceId)
                    callback.onAuthFailure()
                }
                
            case .failure(let error):
                // Sunucu hatası - SQLite'dan kontrol et (Android mantığı)
                let dbManager = DatabaseManager.getInstance()
                let isLocallyAuthorized = dbManager.isCihazYetkili(cihazBilgisi: deviceId)
                
                if isLocallyAuthorized {
                    print("🔄 Sunucu hatası, SQLite'da yetkili cihaz")
                    
                    // Cihaz sahibi bilgisini SQLite'dan al
                    let deviceOwner = dbManager.getCihazSahibi(cihazBilgisi: deviceId)
                    if !deviceOwner.isEmpty {
                        UserDefaults.standard.set(deviceOwner, forKey: "device_owner")
                        UserDefaults.standard.set(deviceOwner, forKey: Constants.UserDefaults.deviceOwner)
                        print("👤 Cihaz sahibi SQLite'dan yüklendi: \(deviceOwner)")
                    }
                    
                    callback.onAuthSuccess()
                } else {
                    print("💥 Sunucu hatası ve SQLite'da yetki yok: \(error.localizedDescription)")
                    
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
            // API endpoint URL'i oluştur (Envanto sunucusu)
            let baseURL = "https://envanto.app/barkod_yukle_android"
            guard let url = URL(string: "\(baseURL)/usersperm.asp") else {
                throw NetworkError.invalidURL
            }
            
            // Request oluştur
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 3.0 // 3 saniyelik timeout (Android'deki gibi)
            
            // Cihaz bilgilerini al
            let deviceInfo = DeviceIdentifier.getReadableDeviceInfo()
            
            // Body parametreleri - ASP dosyasına uygun
            let bodyString = "action=check&cihaz_bilgisi=\(deviceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&cihaz_sahibi=\(deviceInfo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            request.httpBody = bodyString.data(using: .utf8)
            
            print("🔗 API URL: \(url)")
            print("📋 Parametreler: \(bodyString)")
            
            // API çağrısı yap
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // HTTP yanıt kontrolü
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NetworkError.serverError
            }
            
            // JSON string'i yazdır
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 Sunucu yanıtı: \(jsonString)")
            }
            
            // JSON decode et
            let authResponse = try JSONDecoder().decode(DeviceAuthResponse.self, from: data)
            return .success(authResponse)
            
        } catch {
            print("💥 API hatası: \(error.localizedDescription)")
            return .failure(error)
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

 