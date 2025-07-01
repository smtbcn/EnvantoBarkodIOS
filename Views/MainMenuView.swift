import SwiftUI

enum AlertType {
    case cameraPermission
}

struct MainMenuView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingSettings = false
    @State private var showingPermissionAlert = false
    @State private var showingBarcodeUpload = false
    @State private var alertType: AlertType = .cameraPermission
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
                                    alertType = .cameraPermission
                                    showingPermissionAlert = true
                                }
                            }
                            
                                                         // Barkod Yükle - Direkt açılacak (cihaz yetkilendirme BarcodeUploadView'da)
                             GridButton(
                                 title: "Barkod Yükle",
                                 icon: "square.and.arrow.up",
                                 color: .orange
                             ) {
                                 showingBarcodeUpload = true
                             }
                        }
                        
                        HStack(spacing: 16) {
                                                         // Müşteri Resimleri - Henüz implementasyonu yok
                             GridButton(
                                 title: "Müşteri Resimleri",
                                 icon: "photo.on.rectangle",
                                 color: .blue
                             ) {
                                 // TODO: CustomerImagesView implementasyonu
                             }
                            
                                                         // Araçtaki Ürünler - Henüz implementasyonu yok
                             GridButton(
                                 title: "Araçtaki Ürünler",
                                 icon: "car.fill",
                                 color: .green
                             ) {
                                 // TODO: VehicleProductsView implementasyonu
                             }
                        }
                    }
                                         .padding(.horizontal, 20)
                
                Spacer()
                
                // Uygulama Ayarları butonu - her zaman aktif
                Button(action: {
                    showingSettings = true
                }) {
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingBarcodeUpload) {
            BarcodeUploadView()
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
            // Kamera izinlerini kontrol et
            viewModel.checkPermissions()
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