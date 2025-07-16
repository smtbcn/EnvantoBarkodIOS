import SwiftUI

public struct VehicleProductsView: View {
    @StateObject private var viewModel = VehicleProductsViewModel()
    @State private var showDeliveryConfirmation = false
    @State private var showReturnConfirmation = false
    @State private var productToReturn: VehicleProduct?
    
    public var body: some View {
        VStack(spacing: 0) {
            // Kullanıcı bilgisi ve teslim butonu
            userInfoHeader
            
            // Ana içerik
            mainContent
        }
        .navigationTitle("Araçtaki Ürünler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Yenile") {
                    viewModel.refresh()
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .alert("Hata", isPresented: $viewModel.showError) {
            Button("Tamam") { }
        } message: {
            Text(viewModel.errorMessage ?? "Bilinmeyen hata")
        }
        .confirmationDialog("Teslim Onayı", isPresented: $showDeliveryConfirmation) {
            Button("Evet, Teslim Et", role: .destructive) {
                viewModel.deliverSelectedCustomers()
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Seçili \(viewModel.selectedCustomerCount) müşterinin tüm ürünlerini teslim etmek istediğinizden emin misiniz?")
        }
        .confirmationDialog("Depoya Geri Bırak", isPresented: $showReturnConfirmation) {
            Button("Evet, Geri Bırak", role: .destructive) {
                if let product = productToReturn {
                    viewModel.returnProductToDepot(product)
                }
            }
            Button("İptal", role: .cancel) { }
        } message: {
            if let product = productToReturn {
                Text("\"\(product.urunAdi)\" ürününü depoya geri bırakmak istediğinizden emin misiniz?")
            }
        }
        .sheet(isPresented: $viewModel.showLoginSheet) {
            LoginView(
                onLoginSuccess: viewModel.onLoginSuccess,
                onCancel: viewModel.onLoginCancel
            )
        }
    }
    
    // MARK: - Kullanıcı Bilgisi Header
    private var userInfoHeader: some View {
        HStack {
            // Kullanıcı ikonu ve adı
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                
                Text(viewModel.currentUserName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            // Seçilenleri teslim et butonu
            if viewModel.hasSelectedCustomers {
                Button(action: {
                    showDeliveryConfirmation = true
                }) {
                    Text("Seçilenleri Teslim Et (\(viewModel.selectedCustomerCount))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGray6))
    }
    
    // MARK: - Ana İçerik
    private var mainContent: some View {
        ZStack {
            if viewModel.isLoading && viewModel.products.isEmpty {
                // İlk yükleme
                ProgressView("Ürünler yükleniyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.isDeviceAuthorized {
                // Cihaz yetkisiz - uyarı göster
                unauthorizedDeviceView
            } else if !viewModel.isUserLoggedIn {
                // Kullanıcı girişi bekleniyor
                loginWaitingView
            } else if viewModel.isEmpty {
                // Boş durum
                emptyStateView
            } else {
                // Ürün listesi
                productsList
            }
        }
    }
    
    // MARK: - Yetkisiz Cihaz Görünümü
    private var unauthorizedDeviceView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("Yetkilendirme Gerekli")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Bu cihaz araçtaki ürünleri görüntüleme işlemi için yetkilendirilmemiş. Lütfen sistem yöneticisine başvurun.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Cihaz ID göster
            VStack(spacing: 10) {
                Text("Cihaz Kimliği:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(DeviceIdentifier.getUniqueDeviceId())
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Button(action: {
                        UIPasteboard.general.string = DeviceIdentifier.getUniqueDeviceId()
                        
                        // Toast göster
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.title2)
                    }
                }
            }
            
            Button(action: {
                viewModel.checkDeviceAuthorization()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Yeniden Kontrol Et")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Boş Durum
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Araçta ürün bulunamadı")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Ürünler Listesi
    private var productsList: some View {
        List {
            ForEach(viewModel.customerGroups) { group in
                Section {
                    // Müşteri header
                    customerHeaderView(group: group)
                    
                    // Ürünler (eğer genişletilmişse)
                    if group.isExpanded {
                        ForEach(group.products) { product in
                            productItemView(product: product)
                        }
                    }
                } header: {
                    // Section header boşluğunu tamamen kaldır
                    EmptyView()
                        .listRowInsets(EdgeInsets())
                } footer: {
                    // Section footer boşluğunu tamamen kaldır
                    EmptyView()
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .listStyle(PlainListStyle())
        .listSectionSeparator(.hidden)
        .listRowSpacing(2)
        .refreshable {
            viewModel.refresh()
        }
    }
    
    // MARK: - Müşteri Header View
    private func customerHeaderView(group: VehicleProductsViewModel.CustomerGroup) -> some View {
        HStack {
            // Müşteri bilgileri - tıklanabilir alan (genişletme için)
            Button(action: {
                viewModel.toggleCustomerExpansion(group.customerName)
            }) {
                HStack {
                    // Kişi ikonu
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.customerName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Text("\(group.productCount) ürün")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Checkbox - sadece seçim yapar
            Button(action: {
                viewModel.toggleCustomerSelection(group.customerName)
            }) {
                Image(systemName: group.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Genişlet/daralt butonu - sadece genişletme yapar
            Button(action: {
                viewModel.toggleCustomerExpansion(group.customerName)
            }) {
                Image(systemName: group.isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
    }
    
    // MARK: - Ürün Item View
    private func productItemView(product: VehicleProduct) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Üst kısım: Ürün adı + Adet badge
            HStack {
                Text(product.urunAdi)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Adet badge
                Text(product.quantityText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange, Color.red]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            
            // Orta kısım: Depo bilgileri
            HStack(spacing: 16) {
                // Sol: Araca yükleyen
                VStack(alignment: .leading, spacing: 2) {
                    Text("ARACA YÜKLEYEN")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Text(product.depoAktaran)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text(product.formattedDate)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Sağ: Yüklü araç
                VStack(alignment: .leading, spacing: 2) {
                    Text("YÜKLÜ ARAÇ")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Text(product.mevcutDepo)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Alt kısım: Depoya geri bırak butonu
            HStack {
                Spacer()
                
                Button(action: {
                    productToReturn = product
                    showReturnConfirmation = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12))
                        
                        Text("Depoya Geri Bırak")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
    }
    
    // MARK: - Login Waiting View
    private var loginWaitingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Kullanıcı Girişi Bekleniyor")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Araçtaki ürünleri görüntülemek için kullanıcı girişi yapmanız gerekmektedir.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    VehicleProductsView()
} 