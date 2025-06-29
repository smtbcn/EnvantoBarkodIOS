import SwiftUI

struct ContentView: View {
    @State private var showScanner = false
    
    var body: some View {
        NavigationView {
            MainMenuView()
        }
        .fullScreenCover(isPresented: $showScanner) {
            NavigationView {
                ScannerView()
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