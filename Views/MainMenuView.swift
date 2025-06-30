import SwiftUI

struct MainMenuView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingSettings = false
    @State private var showingPermissionAlert = false
    @State private var showingBarcodeUpload = false
    @State private var showingSavedImages = false
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
                
                // Ana menü butonları
                VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            // Barkod Tara (İzin kontrolü: sadece kamera izni)
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
                            
                            // Barkod Yükle (Cihaz yetki kontrolü burada değil, sayfa içinde)
                            GridButton(
                                title: "Barkod Yükle",
                                icon: "square.and.arrow.up",
                                color: .orange
                            ) {
                                showingBarcodeUpload = true
                            }
                        }
                        
                        HStack(spacing: 16) {
                            // Müşteri Resimleri (Cihaz yetki kontrolü sayfa içinde)
                            GridButton(
                                title: "Kaydedilen Resimler",
                                icon: "photo.on.rectangle",
                                color: .purple
                            ) {
                                showingSavedImages = true
                            }
                            
                            // Araçtaki Ürünler (Cihaz yetki kontrolü sayfa içinde)
                            GridButton(
                                title: "Araçtaki Ürünler",
                                icon: "car.fill",
                                color: .green
                            ) {
                                // Vehicle products görünümüne git (cihaz kontrolü sayfa içinde)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // Uygulama Ayarları butonu
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingBarcodeUpload) {
            BarcodeUploadView()
        }
        .sheet(isPresented: $showingSavedImages) {
            SavedImagesView()
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