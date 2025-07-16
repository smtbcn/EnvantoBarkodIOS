import Foundation
import SwiftUI

// MARK: - LoginManager Callback Protocols
public protocol LoginCallback {
    func onLoginSuccess(user: User)
    func onLoginFailure(message: String, errorCode: String)
    func onShowLoading()
    func onHideLoading()
}

// MARK: - LoginManager
public class LoginManager: ObservableObject {
    public static let shared = LoginManager()
    
    // MARK: - Constants
    private let loginPrefsKey = "envanto_login_prefs"
    private let savedUsersPrefsKey = "envanto_saved_users"
    private let sessionDuration: TimeInterval = 24 * 60 * 60 // 24 saat
    
    // MARK: - UserDefaults Keys
    private let keyUserToken = "user_token"
    private let keyUserEmail = "user_email"
    private let keyUserName = "user_name"
    private let keyUserSurname = "user_surname"
    private let keyUserPermission = "user_permission"
    private let keyUserId = "user_id"
    private let keyLoginTime = "login_time"
    private let keyIsLoggedIn = "is_logged_in"
    private let keyRememberMe = "remember_me"
    
    private init() {}
    
    // MARK: - Login Method
    public static func login(email: String, password: String, callback: LoginCallback) {
        // Input validation
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            callback.onLoginFailure(message: "E-posta ve şifre alanları boş olamaz", errorCode: "EMPTY_FIELDS")
            return
        }
        
        callback.onShowLoading()
        
        print("LoginManager: Kullanıcı girişi başlatılıyor: \(email)")
        
        // API request parameters
        let parameters = [
            "action": "login",
            "email": email.trimmingCharacters(in: .whitespaces),
            "password": password
        ]
        
        // URL oluştur
        guard let baseUrl = UserDefaults.standard.string(forKey: Constants.UserDefaults.apiBaseURL),
              let url = URL(string: "\(baseUrl)/login_api.asp") else {
            callback.onHideLoading()
            callback.onLoginFailure(message: "API URL'i bulunamadı", errorCode: "INVALID_URL")
            return
        }
        
        // HTTP Request oluştur
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Parameters'ı encode et
        let bodyString = parameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        // API çağrısı
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                callback.onHideLoading()
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    print("LoginManager: Network error - \(error.localizedDescription)")
                    callback.onLoginFailure(message: "İnternet bağlantınızı kontrol edin ve tekrar deneyin. Hata: \(error.localizedDescription)", errorCode: "NETWORK_ERROR")
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    callback.onLoginFailure(message: "Sunucudan yanıt alınamadı", errorCode: "NO_DATA")
                }
                return
            }
            
            // Response'u parse et
            do {
                let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                
                DispatchQueue.main.async {
                    if loginResponse.success, let user = loginResponse.user {
                        // Giriş başarılı
                        print("LoginManager: Giriş başarılı: \(user.fullName)")
                        print("LoginManager: Kullanıcı yetkisi: \(user.permission)")
                        
                        // Kullanıcı oturumunu kaydet
                        LoginManager.saveUserSession(user: user)
                        
                        callback.onLoginSuccess(user: user)
                    } else {
                        // Giriş başarısız
                        print("LoginManager: Giriş başarısız: \(loginResponse.message)")
                        callback.onLoginFailure(message: loginResponse.message, errorCode: loginResponse.errorCode ?? "LOGIN_FAILED")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("LoginManager: JSON parse error - \(error.localizedDescription)")
                    callback.onLoginFailure(message: "Sunucu yanıtı işlenirken hata oluştu", errorCode: "PARSE_ERROR")
                }
            }
        }.resume()
    }
    
    // MARK: - Save User Session
    private static func saveUserSession(user: User) {
        let defaults = UserDefaults.standard
        
        defaults.set(true, forKey: shared.keyIsLoggedIn)
        defaults.set(user.token, forKey: shared.keyUserToken)
        defaults.set(user.email, forKey: shared.keyUserEmail)
        defaults.set(user.name, forKey: shared.keyUserName)
        defaults.set(user.surname, forKey: shared.keyUserSurname)
        defaults.set(user.permission, forKey: shared.keyUserPermission)
        defaults.set(user.userId, forKey: shared.keyUserId)
        defaults.set(Date().timeIntervalSince1970, forKey: shared.keyLoginTime)
        
        print("LoginManager: Kullanıcı oturumu kaydedildi")
    }
    
    // MARK: - Login Status Check
    public static func isLoggedIn() -> Bool {
        return UserDefaults.standard.bool(forKey: shared.keyIsLoggedIn)
    }
    
    // MARK: - Session Expiration Check
    public static func isSessionExpired() -> Bool {
        let loginTime = UserDefaults.standard.double(forKey: shared.keyLoginTime)
        let currentTime = Date().timeIntervalSince1970
        return (currentTime - loginTime) > shared.sessionDuration
    }
    
    // MARK: - Get Current User
    public static func getCurrentUser() -> User? {
        let defaults = UserDefaults.standard
        
        guard defaults.bool(forKey: shared.keyIsLoggedIn) else {
            return nil
        }
        
        let email = defaults.string(forKey: shared.keyUserEmail) ?? ""
        let name = defaults.string(forKey: shared.keyUserName) ?? ""
        let surname = defaults.string(forKey: shared.keyUserSurname) ?? ""
        let permission = defaults.integer(forKey: shared.keyUserPermission)
        let token = defaults.string(forKey: shared.keyUserToken) ?? ""
        let userId = defaults.integer(forKey: shared.keyUserId)
        let loginTime = defaults.double(forKey: shared.keyLoginTime)
        
        let lastLogin = loginTime > 0 ? DateFormatter().string(from: Date(timeIntervalSince1970: loginTime)) : nil
        
        return User(email: email, name: name, surname: surname, permission: permission, token: token, lastLogin: lastLogin, userId: userId)
    }
    
    // MARK: - Get User Token
    public static func getUserToken() -> String {
        return UserDefaults.standard.string(forKey: shared.keyUserToken) ?? ""
    }
    
    // MARK: - Logout
    public static func logout() {
        let defaults = UserDefaults.standard
        
        // Login ile ilgili tüm key'leri temizle
        defaults.removeObject(forKey: shared.keyIsLoggedIn)
        defaults.removeObject(forKey: shared.keyUserToken)
        defaults.removeObject(forKey: shared.keyUserEmail)
        defaults.removeObject(forKey: shared.keyUserName)
        defaults.removeObject(forKey: shared.keyUserSurname)
        defaults.removeObject(forKey: shared.keyUserPermission)
        defaults.removeObject(forKey: shared.keyUserId)
        defaults.removeObject(forKey: shared.keyLoginTime)
        
        print("LoginManager: Kullanıcı oturumu sonlandırıldı")
    }
    
    // MARK: - Saved Users Management
    public static func saveUserForRemembering(email: String, name: String, surname: String, password: String, userId: Int, permission: Int) {
        var savedUsers = getSavedUsers()
        
        // Aynı e-posta adresi varsa güncelle
        if let index = savedUsers.firstIndex(where: { $0.email == email }) {
            savedUsers[index] = SavedUser(email: email, name: name, surname: surname, password: password, userId: userId, permission: permission)
        } else {
            // Yeni kullanıcı ekle
            savedUsers.append(SavedUser(email: email, name: name, surname: surname, password: password, userId: userId, permission: permission))
        }
        
        // Maksimum 5 kullanıcı sakla (en son girenleri)
        if savedUsers.count > 5 {
            savedUsers.sort { $0.lastLoginTime > $1.lastLoginTime }
            savedUsers = Array(savedUsers.prefix(5))
        }
        
        // UserDefaults'a kaydet
        if let encoded = try? JSONEncoder().encode(savedUsers) {
            UserDefaults.standard.set(encoded, forKey: shared.savedUsersPrefsKey)
        }
        
        print("LoginManager: Kullanıcı hatırlanacaklar listesine eklendi: \(email)")
    }
    
    public static func getSavedUsers() -> [SavedUser] {
        guard let data = UserDefaults.standard.data(forKey: shared.savedUsersPrefsKey),
              let savedUsers = try? JSONDecoder().decode([SavedUser].self, from: data) else {
            return []
        }
        
        // Son giriş zamanına göre sırala
        return savedUsers.sorted { $0.lastLoginTime > $1.lastLoginTime }
    }
    
    public static func removeSavedUser(email: String) {
        var savedUsers = getSavedUsers()
        savedUsers.removeAll { $0.email == email }
        
        // Güncellenmiş listeyi kaydet
        if let encoded = try? JSONEncoder().encode(savedUsers) {
            UserDefaults.standard.set(encoded, forKey: shared.savedUsersPrefsKey)
        }
        
        print("LoginManager: Kayıtlı kullanıcı silindi: \(email)")
    }
    
    // MARK: - Auto Login with Saved User
    public static func loginWithSavedUser(savedUser: SavedUser, callback: LoginCallback) {
        login(email: savedUser.email, password: savedUser.password, callback: LoginAutoUpdateCallback(savedUser: savedUser, originalCallback: callback))
    }
}

// MARK: - Helper Callback for Auto Login
private class LoginAutoUpdateCallback: LoginCallback {
    private let savedUser: SavedUser
    private let originalCallback: LoginCallback
    
    init(savedUser: SavedUser, originalCallback: LoginCallback) {
        self.savedUser = savedUser
        self.originalCallback = originalCallback
    }
    
    func onLoginSuccess(user: User) {
        // Giriş başarılı olduğunda kullanıcıyı güncelle
        LoginManager.saveUserForRemembering(email: user.email, name: user.name, surname: user.surname, password: savedUser.password, userId: user.userId, permission: user.permission)
        originalCallback.onLoginSuccess(user: user)
    }
    
    func onLoginFailure(message: String, errorCode: String) {
        originalCallback.onLoginFailure(message: message, errorCode: errorCode)
    }
    
    func onShowLoading() {
        originalCallback.onShowLoading()
    }
    
    func onHideLoading() {
        originalCallback.onHideLoading()
    }
} 