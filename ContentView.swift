import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppStateManager()
    
    var body: some View {
        NavigationView {
            MainMenuView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $appState.showScanner) {
            NavigationView {
                ScannerView()
                    .environmentObject(appState)
            }
            .onDisappear {
                // Scanner kapandığında main thread'in serbest olduğundan emin ol
                print("📱 [ContentView] Scanner fullScreenCover kapandı")
                
                // Kısa bir gecikme ile UI'ın responsive olduğundan emin ol
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("✅ [ContentView] Main thread serbest")
                }
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
        print("🏠 [AppStateManager] Ana menüye dönülüyor")
        
        // UI güncellemesini main thread'de yap
        DispatchQueue.main.async {
            self.showScanner = false
            self.pendingURLScheme = false
            print("✅ [AppStateManager] Ana menü gösterildi")
        }
    }
}

#Preview {
    ContentView()
} 
