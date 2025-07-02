import SwiftUI

// MARK: - Bundle Extensions
extension Bundle {
    var appVersionLong: String {
        return "\(appVersion) (\(appBuild))"
    }
    
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var appBuild: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var appName: String {
        return infoDictionary?["CFBundleDisplayName"] as? String ?? "Envanto Barkod"
    }
}

// MARK: - View Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Color Extensions
extension Color {
    static let primaryBlue = Color("PrimaryBlue")
    static let primaryGreen = Color("PrimaryGreen")
    static let primaryOrange = Color("PrimaryOrange")
    static let primaryPurple = Color("PrimaryPurple")
    static let backgroundGray = Color("BackgroundGray")
    static let textSecondary = Color("TextSecondary")
    
    // Varsayılan renkler (Assets.xcassets yoksa)
    static let defaultPrimaryBlue = Color(red: 0.0, green: 0.5, blue: 1.0)
    static let defaultPrimaryGreen = Color(red: 0.0, green: 0.8, blue: 0.4)
    static let defaultPrimaryOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let defaultPrimaryPurple = Color(red: 0.6, green: 0.0, blue: 1.0)
}

// MARK: - String Extensions
extension String {
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    func trimmed() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isNotEmpty: Bool {
        return !self.isEmpty
    }
}

// MARK: - Date Extensions
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Custom Shapes
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - UIApplication Extensions
extension UIApplication {
    var keyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
} 
