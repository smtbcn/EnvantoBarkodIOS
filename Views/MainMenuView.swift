import SwiftUI

struct MainMenuView: View {
    @State private var showingScanner = false
    @State private var showingUpload = false
    @State private var showingCustomerImages = false
    @State private var showingVehicleProducts = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Logo ve Başlık Bölümü (Android ile aynı)
                    VStack(spacing: 12) {
                        Image("EnvantoLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .foregroundColor(.blue)
                        
                        Text("Envanto Barkod")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Barkod Tarama ve Yönetim Sistemi")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                    
                    // 2x2 Buton Grid (Android ile birebir aynı)
                    VStack(spacing: 16) {
                        // Üst sıra: Barkod Tara + Barkod Yükle
                        HStack(spacing: 8) {
                            // Barkod Tara (Sol üst - Primary color)
                            MenuCard(
                                icon: "barcode.viewfinder",
                                title: "Barkod Tara",
                                color: .blue,
                                action: { showingScanner = true }
                            )
                            
                            // Barkod Yükle (Sağ üst - Secondary color)
                            MenuCard(
                                icon: "square.and.arrow.up",
                                title: "Barkod Yükle", 
                                color: .orange,
                                action: { showingUpload = true }
                            )
                        }
                        
                        // Alt sıra: Müşteri Resimleri + Araçtaki Ürünler
                        HStack(spacing: 8) {
                            // Müşteri Resimleri (Sol alt - Info color)
                            MenuCard(
                                icon: "person.2.crop.square.stack",
                                title: "Müşteri Resimleri",
                                color: .cyan,
                                action: { showingCustomerImages = true }
                            )
                            
                            // Araçtaki Ürünler (Sağ alt - Success color)
                            MenuCard(
                                icon: "car.fill",
                                title: "Araçtaki Ürünler",
                                color: .green,
                                action: { showingVehicleProducts = true }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Ayarlar Butonu (Android ile aynı şekilde)
                    Button(action: {
                        showingSettings = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gear")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            
                            Text("Uygulama Ayarları")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .foregroundColor(Color.gray.opacity(0.8))
                        )
                    }
                    .frame(maxWidth: .infinity * 0.6)
                    .padding(.top, 24)
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // Alt Bilgi Alanı (Android ile aynı)
                    VStack(spacing: 8) {
                        // Cihaz Sahibi (Android'deki gibi)
                        Text("👤 Cihaz Sahibi: Belirtilmemiş")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .foregroundColor(Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        
                        // Versiyon (Android'deki gibi)
                        Text("Versiyon: 1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 16)
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showingScanner) {
            ScannerView()
        }
        // Diğer ekranlar için placeholder sheet'ler (arkaplan kodu daha sonra)
        .sheet(isPresented: $showingUpload) {
            PlaceholderView(title: "Barkod Yükle", message: "Bu özellik yakında eklenecek")
        }
        .sheet(isPresented: $showingCustomerImages) {
            PlaceholderView(title: "Müşteri Resimleri", message: "Bu özellik yakında eklenecek")
        }
        .sheet(isPresented: $showingVehicleProducts) {
            PlaceholderView(title: "Araçtaki Ürünler", message: "Bu özellik yakında eklenecek")
        }
        .sheet(isPresented: $showingSettings) {
            PlaceholderView(title: "Uygulama Ayarları", message: "Bu özellik yakında eklenecek")
        }
    }
}

// MARK: - Menu Card Component (Android MaterialCardView benzeri)
struct MenuCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Placeholder View (Geçici ekranlar için) - iOS 15 uyumlu
struct PlaceholderView: View {
    let title: String
    let message: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "hammer.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: 
                Button("Kapat") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

#if DEBUG
struct MainMenuView_Previews: PreviewProvider {
    static var previews: some View {
        MainMenuView()
    }
}
#endif 