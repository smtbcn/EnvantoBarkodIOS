import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppStateManager()
    
    var body: some View {
        NavigationView {
            MainMenuView()
        }
        .fullScreenCover(isPresented: $appState.showScanner) {
            NavigationView {
                ScannerView()
                    .environmentObject(appState)
            }
        }
        .onOpenURL { url in
            handleURLScheme(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Uygulama aktif olduğunda URL scheme kontrol et
            appState.handleAppBecomeActive()
        }
    }
    
    private func handleURLScheme(_ url: URL) {
        // URL scheme: envantobarcode://
        guard url.scheme == "envantobarcode" else { return }
        
        // Performanslı şekilde scanner'ı aç
        DispatchQueue.main.async {
            appState.openScannerFromURLScheme()
        }
    }
}

// MARK: - App State Manager
class AppStateManager: ObservableObject {
    @Published var showScanner = false
    private var pendingURLScheme = false
    
    func openScannerFromURLScheme() {
        // URL scheme'den geldiğini işaretle
        pendingURLScheme = true
        showScanner = true
    }
    
    func handleAppBecomeActive() {
        // Uygulama aktif olduğunda pending URL scheme varsa işle
        if pendingURLScheme {
            pendingURLScheme = false
            // Ekstra animasyon gecikmesi olmadan direkt aç
            showScanner = true
        }
    }
    
    func closeScannerToMainMenu() {
        showScanner = false
        pendingURLScheme = false
    }
}

#Preview {
    ContentView()
} 