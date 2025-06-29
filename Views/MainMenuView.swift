import SwiftUI

struct MainMenuView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingSettings = false
    @State private var showingPermissionAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Başlık ve versiyon bilgisi
            VStack(spacing: 8) {
                Text("Envanto Barkod")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Versiyon: \(Bundle.main.appVersionLong)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Ana menü butonları
            VStack(spacing: 16) {
                // Barkod Tara butonu
                NavigationLink(destination: ScannerView()) {
                    MenuButtonContent(
                        title: "Barkod Tara",
                        icon: "qrcode.viewfinder",
                        color: .blue
                    )
                }
                .disabled(!viewModel.hasRequiredPermissions)
                .onTapGesture {
                    if !viewModel.hasRequiredPermissions {
                        showingPermissionAlert = true
                    }
                }
                
                // Barkod Yükle butonu
                MenuButton(
                    title: "Barkod Yükle",
                    icon: "square.and.arrow.up",
                    color: .green
                ) {
                    if viewModel.hasRequiredPermissions {
                        // Upload görünümüne git
                    } else {
                        showingPermissionAlert = true
                    }
                }
                
                // Müşteri Resimleri butonu
                MenuButton(
                    title: "Müşteri Resimleri",
                    icon: "photo.on.rectangle",
                    color: .orange
                ) {
                    if viewModel.hasRequiredPermissions {
                        // Customer images görünümüne git
                    } else {
                        showingPermissionAlert = true
                    }
                }
                
                // Araçtaki Ürünler butonu
                MenuButton(
                    title: "Araçtaki Ürünler",
                    icon: "car.fill",
                    color: .purple
                ) {
                    if viewModel.hasRequiredPermissions {
                        // Vehicle products görünümüne git
                    } else {
                        showingPermissionAlert = true
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Cihaz sahibi bilgisi
            if !viewModel.deviceOwner.isEmpty {
                Text("Cihaz Sahibi: \(viewModel.deviceOwner)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .alert("İzin Gerekli", isPresented: $showingPermissionAlert) {
            Button("Ayarlara Git") {
                viewModel.openSettings()
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Bu özelliği kullanmak için kamera izni gerekli.")
        }
        .onAppear {
            viewModel.checkPermissions()
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            MenuButtonContent(title: title, icon: icon, color: color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MenuButtonContent: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
            
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [color.opacity(0.9), color]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

#Preview {
    NavigationView {
        MainMenuView()
    }
} 