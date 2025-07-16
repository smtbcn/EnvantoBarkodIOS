import Foundation

// MARK: - LoginResponse
public struct LoginResponse: Codable {
    public let success: Bool
    public let message: String
    public let errorCode: String?
    public let user: User?
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case errorCode = "error_code"
        case user
    }
    
    public init(success: Bool, message: String, errorCode: String? = nil, user: User? = nil) {
        self.success = success
        self.message = message
        self.errorCode = errorCode
        self.user = user
    }
}

// MARK: - User
public struct User: Codable, Identifiable {
    public let id = UUID()
    public let email: String
    public let name: String
    public let surname: String
    public let permission: Int
    public let token: String
    public let lastLogin: String?
    public let userId: Int
    
    enum CodingKeys: String, CodingKey {
        case email, name, surname, permission, token
        case lastLogin = "last_login"
        case userId = "user_id"
    }
    
    public init(email: String, name: String, surname: String, permission: Int, token: String, lastLogin: String? = nil, userId: Int) {
        self.email = email
        self.name = name
        self.surname = surname
        self.permission = permission
        self.token = token
        self.lastLogin = lastLogin
        self.userId = userId
    }
    
    // Full name helper
    public var fullName: String {
        return "\(name) \(surname)".trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - SavedUser (Beni Hatırla özelliği için)
public struct SavedUser: Codable, Identifiable {
    public let id = UUID()
    public let email: String
    public let name: String
    public let surname: String
    public let password: String // Encrypted olarak saklanacak
    public let userId: Int
    public let permission: Int
    public let lastLoginTime: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case email, name, surname, password, userId, permission, lastLoginTime
    }
    
    public init(email: String, name: String, surname: String, password: String, userId: Int, permission: Int, lastLoginTime: TimeInterval = Date().timeIntervalSince1970) {
        self.email = email
        self.name = name
        self.surname = surname
        self.password = password
        self.userId = userId
        self.permission = permission
        self.lastLoginTime = lastLoginTime
    }
    
    public var fullName: String {
        return "\(name) \(surname)".trimmingCharacters(in: .whitespaces)
    }
} 