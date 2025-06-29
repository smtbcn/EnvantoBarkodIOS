import SwiftUI

struct ContentView: View {
    @State private var shouldOpenScanner = false
    
    var body: some View {
        NavigationView {
            MainMenuView(shouldOpenScanner: $shouldOpenScanner)
        }
        .onOpenURL { url in
            // URL scheme: envantobarcode://
            if url.scheme == "envantobarcode" {
                shouldOpenScanner = true
            }
        }
    }
}

#Preview {
    ContentView()
} 