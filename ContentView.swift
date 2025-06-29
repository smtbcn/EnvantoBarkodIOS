import SwiftUI

struct ContentView: View {
    @State private var showScanner = false
    
    var body: some View {
        NavigationView {
            if showScanner {
                ScannerView()
                    .onDisappear {
                        showScanner = false
                    }
            } else {
                MainMenuView()
            }
        }
        .onOpenURL { url in
            // URL scheme: envantobarcode://
            if url.scheme == "envantobarcode" {
                showScanner = true
            }
        }
    }
}

#Preview {
    ContentView()
} 