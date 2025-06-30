import SwiftUI

struct MainMenuView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingScanner = false
    @State private var showingSettings = false
    @State private var showingSavedImages = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo
                Image("EnvantoLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .padding(.top, 20)
                
                // Cihaz Sahibi Bilgisi
                if let deviceOwner = SQLiteManager.shared.getCihazSahibi(DeviceIdentifier.getUniqueDeviceId()) {
                    Text("Hoş geldiniz, \(deviceOwner)")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Ana Menü Butonları
                VStack(spacing: 16) {
                    // Barkod Tara Butonu
                    Button(action: {
                        showingScanner = true
                    }) {
                        MenuButton(
                            title: "Barkod Tara",
                            systemImage: "barcode.viewfinder",
                            backgroundColor: .blue
                        )
                    }
                    
                    // Kayıtlı Resimler Butonu
                    Button(action: {
                        showingSavedImages = true
                    }) {
                        MenuButton(
                            title: "Kayıtlı Resimler",
                            systemImage: "photo.on.rectangle",
                            backgroundColor: .green
                        )
                    }
                    
                    // Ayarlar Butonu
                    Button(action: {
                        showingSettings = true
                    }) {
                        MenuButton(
                            title: "Ayarlar",
                            systemImage: "gear",
                            backgroundColor: .gray
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Versiyon Bilgisi
                Text("Versiyon 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingScanner) {
            ScannerView()
        }
        .sheet(isPresented: $showingSavedImages) {
            SavedImagesView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// MARK: - Özel Menü Butonu
struct MenuButton: View {
    let title: String
    let systemImage: String
    let backgroundColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 30)
            
            Text(title)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
    }
}

#Preview {
    MainMenuView()
} 