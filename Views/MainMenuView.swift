import SwiftUI
import Foundation

// AlertType artık sadece kamera izni için kullanılıyor

struct MainMenuView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingPermissionAlert = false
    // AlertType kaldırıldı - sadece kamera izni kontrolü
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        ZStack {
            // Gradient arka plan
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemGray6), Color(.systemBackground)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Ana içerik
            VStack(spacing: 0) {
                // Logo ve başlık bölümü
                VStack(spacing: 12) {
                    // App Logo
                    Image("EnvantoLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 3, y: 3)
                    
                    // Başlık
                    Text("Envanto Barkod")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Açıklama metni
                    Text("Barkod tarama ve yükleme işlemlerinizi kolayca gerçekleştirin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.top, 30)
                .padding(.bottom, 40)
                
                // Ana menü butonları
                VStack(spacing: 12) {
                    // Üst sıra butonları
                    HStack(spacing: 20) {
                        // Barkod Tara
                        GridButton(
                            title: "Barkod Tara",
                            icon: "qrcode.viewfinder",
                            color: Color(red: 0.2, green: 0.6, blue: 1.0)
                        ) {
                            if viewModel.hasRequiredPermissions {
                                appState.showScanner = true
                            } else {
                                showingPermissionAlert = true
                            }
                        }
                        
                        // Barkod Yükle
                        NavigationLink(destination: BarcodeUploadView()) {
                            GridButtonContent(
                                title: "Barkod Yükle",
                                icon: "square.and.arrow.up",
                                color: Color(red: 1.0, green: 0.4, blue: 0.2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Alt sıra butonları
                    HStack(spacing: 20) {
                        // Müşteri Resimleri
                        NavigationLink(destination: CustomerImagesView()) {
                            GridButtonContent(
                                title: "Müşteri Resimleri",
                                icon: "photo.on.rectangle",
                                color: Color(red: 0.2, green: 0.6, blue: 1.0)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Araçtaki Ürünler - Updated
                        NavigationLink(destination: {
                            VehicleProductsView()
                        }()) {
                            GridButtonContent(
                                title: "Araçtaki Ürünler",
                                icon: "car.fill",
                                color: Color(red: 0.3, green: 0.7, blue: 0.3)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 30)
                
                // Uygulama Ayarları butonu - Ana butonların hemen altına
                NavigationLink(destination: SettingsView(viewModel: viewModel)) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        Text("Uygulama Ayarları")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.5, blue: 0.9)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                Spacer()
                
                // Alt bilgiler - Border içerisinde sadece cihaz sahibi
                VStack(spacing: 8) {
                    if !viewModel.deviceOwner.isEmpty {
                        HStack {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Cihaz Sahibi: \(viewModel.deviceOwner)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemBackground))
                                )
                        )
                        .padding(.horizontal, 30)
                    }
                    
                    // Versiyon bilgisi border dışında
                    Text("Versiyon: \(Bundle.main.appVersionLong)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding(.bottom, 30)
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
            
            // API base URL'ini ayarla (test için)
            setupAPIBaseURL()
            
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
    }
    
    // MARK: - API Setup
    private func setupAPIBaseURL() {
        // Mevcut base URL'i login API için kullan
        if UserDefaults.standard.string(forKey: Constants.UserDefaults.apiBaseURL) == nil {
            UserDefaults.standard.set(Constants.Network.baseURL, forKey: Constants.UserDefaults.apiBaseURL)
            print("API Base URL ayarlandı: \(Constants.Network.baseURL)")
        }
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
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [color.opacity(0.95), color]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    MainMenuView()
        .environmentObject(AppStateManager())
} 
