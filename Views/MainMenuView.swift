import SwiftUI

// AlertType artık sadece kamera izni için kullanılıyor

struct MainMenuView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingPermissionAlert = false
    // AlertType kaldırıldı - sadece kamera izni kontrolü
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        ZStack {
            // Ana içerik
            VStack(spacing: 20) {
                // Logo ve başlık
                VStack(spacing: 16) {
                    // App Logo - Özel EnvantoLogo image set
                    Image("EnvantoLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    // Başlık
                    Text("Envanto Barkod")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Açıklama metni
                    Text("Barkod tarama ve yükleme işlemlerinizi kolayca gerçekleştirin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Ana menü butonları - Main ve Barkod Tara için cihaz yetkilendirme muafiyeti
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            // Barkod Tara - Sadece kamera izni gerekli
                            GridButton(
                                title: "Barkod Tara",
                                icon: "qrcode.viewfinder",
                                color: .blue
                            ) {
                                if viewModel.hasRequiredPermissions {
                                    appState.showScanner = true
                                } else {
                                    showingPermissionAlert = true
                                }
                            }
                            
                            // Barkod Yükle - NavigationLink ile tam sayfa açılır
                            NavigationLink(destination: BarcodeUploadView()) {
                                GridButtonContent(
                                    title: "Barkod Yükle",
                                    icon: "square.and.arrow.up",
                                    color: .orange
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        HStack(spacing: 16) {
                            // Müşteri Resimleri - Direkt açılır (cihaz yetki kontrolü kendi sayfasında)
                            GridButton(
                                title: "Müşteri Resimleri",
                                icon: "photo.on.rectangle",
                                color: .blue
                            ) {
                                // TODO: Customer images görünümüne git
                            }
                            
                            // Araçtaki Ürünler - Direkt açılır (cihaz yetki kontrolü kendi sayfasında)
                            GridButton(
                                title: "Araçtaki Ürünler",
                                icon: "car.fill",
                                color: .green
                            ) {
                                // TODO: Vehicle products görünümüne git
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // Uygulama Ayarları butonu - NavigationLink ile tam sayfa açılır
                NavigationLink(destination: SettingsView(viewModel: viewModel)) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Uygulama Ayarları")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                // Loading kaldırıldı - her zaman aktif
                .padding(.horizontal, 40)
                
                // Alt bilgiler
                VStack(spacing: 4) {
                    if !viewModel.deviceOwner.isEmpty {
                        Text("Cihaz Sahibi: \(viewModel.deviceOwner)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Versiyon: \(Bundle.main.appVersionLong)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .alert("Kamera İzni Gerekli", isPresented: $showingPermissionAlert) {
            Button("Ayarlara Git") {
                viewModel.openSettings()
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Barkod tarama özelliğini kullanmak için kamera izni gerekli.")
        }
        .onAppear {
            // Kamera izinlerini kontrol et
            viewModel.checkPermissions()
            
            // Upload servisini başlat (WiFi ayarı ile)
            startUploadService()
        }
    }
    
    // MARK: - Upload Service Management
    private func startUploadService() {
        // WiFi ayarını UserDefaults'tan oku
        let wifiOnly = UserDefaults.standard.bool(forKey: Constants.UserDefaults.wifiOnly)
        
        // Upload servisini başlat
        UploadService.shared.startUploadService(wifiOnly: wifiOnly)
        
        print("🚀 MainMenuView: Upload servisi başlatıldı - WiFi only: \(wifiOnly)")
    }
}

struct GridButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GridButtonContent(title: title, icon: icon, color: color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GridButtonContent: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [color.opacity(0.9), color]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    MainMenuView()
        .environmentObject(AppStateManager())
} 