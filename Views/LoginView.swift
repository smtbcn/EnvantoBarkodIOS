import SwiftUI

public struct LoginView: View {
    // MARK: - Properties
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var rememberMe: Bool = true
    @State private var isLoading: Bool = false
    @State private var savedUsers: [SavedUser] = []
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isPasswordVisible: Bool = false
    
    // Callbacks
    let onLoginSuccess: (User) -> Void
    let onCancel: () -> Void
    
    public init(onLoginSuccess: @escaping (User) -> Void, onCancel: @escaping () -> Void) {
        self.onLoginSuccess = onLoginSuccess
        self.onCancel = onCancel
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Kullanıcı Seçimi")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Mevcut kullanıcı ile devam edin veya farklı hesap ile giriş yapın")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Email Input
                VStack(alignment: .leading, spacing: 8) {
                    TextField("E-posta", text: $email)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(size: 16))
                }
                
                // Password Input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Group {
                            if isPasswordVisible {
                                TextField("Şifre", text: $password)
                            } else {
                                SecureField("Şifre", text: $password)
                            }
                        }
                        .font(.system(size: 16))
                        
                        Button(action: {
                            isPasswordVisible.toggle()
                        }) {
                            Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Remember Me Checkbox
                HStack {
                    Button(action: {
                        rememberMe.toggle()
                    }) {
                        Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                            .foregroundColor(rememberMe ? .accentColor : .secondary)
                            .font(.system(size: 18))
                    }
                    
                    Text("Beni hatırla")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                // Saved Users Section
                if !savedUsers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Kayıtlı Kullanıcılar:")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        LazyVStack(spacing: 4) {
                            ForEach(savedUsers) { user in
                                SavedUserCard(
                                    user: user,
                                    onUserSelect: { selectedUser in
                                        email = selectedUser.email
                                        password = selectedUser.password
                                        rememberMe = true
                                    },
                                    onUserDelete: { userToDelete in
                                        removeSavedUser(userToDelete)
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: min(CGFloat(savedUsers.count * 60 + 20), 300))
                }
                
                // Loading Indicator
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                        .tint(.accentColor)
                }
                
                // Login Button
                Button(action: performLogin) {
                    Text("Giriş Yap")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isLoading ? Color.secondary : Color.accentColor)
                        .cornerRadius(12)
                }
                .disabled(isLoading)
                
                // Cancel Button
                Button(action: onCancel) {
                    Text("İptal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                        )
                }
                .disabled(isLoading)
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
        .onAppear {
            loadInitialData()
        }
        .alert("Hata", isPresented: $showAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Private Methods
    private func loadInitialData() {
        savedUsers = LoginManager.getSavedUsers()
        
        // Mevcut session kontrolü - eğer geçerli session varsa bilgileri doldur
        if LoginManager.isLoggedIn() && !LoginManager.isSessionExpired() {
            if let currentUser = LoginManager.getCurrentUser() {
                email = currentUser.email
                // Şifreyi kayıtlı kullanıcılardan bul
                if let savedUser = savedUsers.first(where: { $0.email == currentUser.email }) {
                    password = savedUser.password
                }
                rememberMe = true
            }
        }
    }
    
    private func performLogin() {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            showError("E-posta ve şifre alanları boş olamaz")
            return
        }
        
        let loginCallback = LoginViewCallback(
            loginView: self,
            email: email,
            password: password,
            rememberMe: rememberMe
        )
        
        LoginManager.login(email: email, password: password, callback: loginCallback)
    }
    
    private func removeSavedUser(_ user: SavedUser) {
        LoginManager.removeSavedUser(email: user.email)
        savedUsers = LoginManager.getSavedUsers()
    }
    
    internal func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
    
    internal func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    internal func handleLoginSuccess(_ user: User) {
        // Beni hatırla seçiliyse kaydet
        if rememberMe {
            LoginManager.saveUserForRemembering(
                email: user.email,
                name: user.name,
                surname: user.surname,
                password: password,
                userId: user.userId,
                permission: user.permission
            )
        }
        
        onLoginSuccess(user)
    }
}

// MARK: - Saved User Card
private struct SavedUserCard: View {
    let user: SavedUser
    let onUserSelect: (SavedUser) -> Void
    let onUserDelete: (SavedUser) -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            // User Icon
            Image(systemName: "person.circle.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 32))
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(user.email)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Delete Button
            Button(action: {
                showingDeleteAlert = true
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 20))
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onUserSelect(user)
        }
        .alert("Kullanıcıyı Sil", isPresented: $showingDeleteAlert) {
            Button("Sil", role: .destructive) {
                onUserDelete(user)
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("\(user.fullName) kullanıcısını kayıtlı listeden silmek istediğinizden emin misiniz?")
        }
    }
}

// MARK: - Login Callback Implementation
private class LoginViewCallback: LoginCallback {
    private let loginView: LoginView
    private let email: String
    private let password: String
    private let rememberMe: Bool
    
    init(loginView: LoginView, email: String, password: String, rememberMe: Bool) {
        self.loginView = loginView
        self.email = email
        self.password = password
        self.rememberMe = rememberMe
    }
    
    func onLoginSuccess(user: User) {
        loginView.handleLoginSuccess(user)
    }
    
    func onLoginFailure(message: String, errorCode: String) {
        loginView.showError(message)
    }
    
    func onShowLoading() {
        loginView.setLoading(true)
    }
    
    func onHideLoading() {
        loginView.setLoading(false)
    }
}

#Preview {
    LoginView(
        onLoginSuccess: { user in
            print("Login success: \(user.fullName)")
        },
        onCancel: {
            print("Login cancelled")
        }
    )
} 