import SwiftUI

public struct VehicleProductsView: View {
    @StateObject private var viewModel = VehicleProductsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDeliveryConfirmation = false
    @State private var showReturnConfirmation = false
    @State private var productToReturn: VehicleProduct?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Kullanıcı bilgisi ve teslim butonu
                userInfoHeader
                
                // Ana içerik
                mainContent
            }
            .navigationTitle("Araçtaki Ürünler")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Geri") {
                        dismiss()
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
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
            } else if viewModel.isEmpty {
                // Boş durum
                emptyStateView
            } else {
                // Ürün listesi
                productsList
            }
        }
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
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            viewModel.refresh()
        }
    }
    
    // MARK: - Müşteri Header View
    private func customerHeaderView(group: VehicleProductsViewModel.CustomerGroup) -> some View {
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
                
                // Checkbox
                Button(action: {
                    viewModel.toggleCustomerSelection(group.customerName)
                }) {
                    Image(systemName: group.isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
                
                // Genişlet/daralt ikonu
                Image(systemName: group.isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
        .padding(.vertical, 2)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
} 