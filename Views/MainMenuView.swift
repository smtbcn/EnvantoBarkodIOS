import SwiftUI

struct MainMenuView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingSettings = false
    @State private var showingPermissionAlert = false
    @State private var showingBarcodeUpload = false
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
                            // Barkod Tara - Cihaz yetkilendirme muafiyeti
                            GridButton(
                                title: "Barkod Tara",
                                icon: "qrcode.viewfinder",
                                color: .blue
                            ) {
                                if viewModel.hasRequiredPermissions {
                                    // Android mantık: AppStateManager ile scanner aç
                                    appState.showScanner = true
                                } else {
                                    showingPermissionAlert = true
                                }
                            }
                            
                            // Barkod Yükle - Cihaz yetkilendirme gerekli
                            GridButton(
                                title: "Barkod Yükle",
                                icon: "square.and.arrow.up",
                                color: .orange
                            ) {
                                if viewModel.isDeviceAuthorized {
                                    if viewModel.hasRequiredPermissions {
                                        showingBarcodeUpload = true
                                    } else {
                                        showingPermissionAlert = true
                                    }
                                } else {
                                    // Cihaz yetkilendirme gerekli uyarısı
                                    showingPermissionAlert = true
                                }
                            }
                        }
                        
                        HStack(spacing: 16) {
                            // Müşteri Resimleri - Cihaz yetkilendirme gerekli
                            GridButton(
                                title: "Müşteri Resimleri",
                                icon: "photo.on.rectangle",
                                color: .blue
                            ) {
                                if viewModel.isDeviceAuthorized {
                                    if viewModel.hasRequiredPermissions {
                                        // Customer images görünümüne git
                                    } else {
                                        showingPermissionAlert = true
                                    }
                                } else {
                                    // Cihaz yetkilendirme gerekli uyarısı
                                    showingPermissionAlert = true
                                }
                            }
                            
                            // Araçtaki Ürünler - Cihaz yetkilendirme gerekli
                            GridButton(
                                title: "Araçtaki Ürünler",
                                icon: "car.fill",
                                color: .green
                            ) {
                                if viewModel.isDeviceAuthorized {
                                    if viewModel.hasRequiredPermissions {
                                        // Vehicle products görünümüne git
                                    } else {
                                        showingPermissionAlert = true
                                    }
                                } else {
                                    // Cihaz yetkilendirme gerekli uyarısı
                                    showingPermissionAlert = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(viewModel.isLoading ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
                
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
                .disabled(viewModel.isLoading)
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
            
            // Loading overlay - Android'deki gibi
            if viewModel.isLoading {
                LoadingOverlay(message: "Cihaz yetkilendirme kontrolü yapılıyor...")
            }
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
            if viewModel.isDeviceAuthorized {
                Button("Ayarlara Git") {
                    viewModel.openSettings()
                }
                Button("İptal", role: .cancel) { }
            } else {
                Button("Tamam", role: .cancel) { }
            }
        } message: {
            if viewModel.isDeviceAuthorized {
                Text("Bu özelliği kullanmak için kamera izni gerekli.")
            } else {
                Text("Bu özelliği kullanmak için cihaz yetkilendirmesi gerekli. Lütfen yöneticinizle iletişime geçin.")
            }
        }
        .onAppear {
            // Arka planda cihaz yetkilendirme kontrolü (sessizce)
            viewModel.checkDeviceAuthorizationSilently()
        }
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
            )
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