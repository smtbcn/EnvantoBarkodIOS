import SwiftUI
import PhotosUI
import AVFoundation
import Combine

struct CustomerImagesView: View {
    @StateObject private var viewModel = CustomerImagesViewModel()
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var expandedCustomerId: String? = nil // Accordion state
    @State private var showingDeleteCustomerAlert = false
    @State private var customerToDelete: String = ""
    

    
    // 🎯 iOS 15+ Focus State for TextField
    @available(iOS 15.0, *)
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    LoadingOverlay()
                } else if !viewModel.isDeviceAuthorized {
                    // Cihaz yetkili değilse uyarı mesajı göster (Android mantığı)
                    unauthorizedDeviceView
                } else {
                    mainContent
                }
            }
        }
        .navigationTitle("Müşteri Resimleri")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Yenile") {
                    viewModel.refreshSavedImages()
                }
            }
        }
        .alert("Uyarı", isPresented: $showingAlert) {
            Button("Tamam") { }
        } message: {
            Text(alertMessage)
        }

        .alert("Toplu Resim Silme", isPresented: $showingDeleteCustomerAlert) {
            Button("İptal", role: .cancel) { }
            Button("Sil", role: .destructive) {
                // Müşteri klasörünü sil
                viewModel.deleteCustomerFolder(customerToDelete)
                // Eğer silinen müşteri açıksa accordion'u kapat
                if expandedCustomerId == customerToDelete {
                    expandedCustomerId = nil
                }
                customerToDelete = ""
            }
        } message: {
            Text("'\(customerToDelete)' müşterisine ait TÜM resimler silinecek.\n\nBu işlem geri alınamaz.")
        }
        .onChange(of: selectedPhotos) { photos in
            Task {
                await viewModel.handleSelectedPhotos(photos)
            }
            selectedPhotos.removeAll()
        }
        .onReceive(viewModel.$errorMessage) { message in
            if !message.isEmpty {
                alertMessage = message
                showingAlert = true
            }
        }
        .sheet(isPresented: $viewModel.showingCamera) {
            AdvancedCameraView { capturedImage in
                // Çekilen resmi işle
                if let customer = viewModel.selectedCustomer {
                    Task {
                        await viewModel.handleCapturedImage(capturedImage, customer: customer)
                    }
                }
            }
        }
        .onAppear {
            // Sayfa açıldığında müşteri gruplarını yükle
            viewModel.loadCustomerImageGroups()
        }
    }
    
    // MARK: - Yetkisiz Cihaz Görünümü (Android mantığı)
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
            
            Text("Bu cihaz müşteri resim işlemi için yetkilendirilmemiş. Lütfen sistem yöneticisine başvurun.")
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
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                        )
                    
                    Button(action: {
                        UIPasteboard.general.string = DeviceIdentifier.getUniqueDeviceId()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.top, 10)
            
            // Yeniden kontrol butonu
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
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Müşteri Seçimi Bölümü (Android like)
                customerSelectionSection
                
                // Resim Yükleme Bölümü (Müşteri seçildikten sonra görünür)
                if viewModel.selectedCustomer != nil {
                    imageUploadSection
                }
                
                // Kayıtlı Resimler Bölümü
                savedImagesSection
            }
            .padding()
        }
        .onTapGesture {
            // Background'a tap yapıldığında focus'u kaldır
            if #available(iOS 15.0, *) {
                isSearchFieldFocused = false
            }
        }
    }
    
    // MARK: - Müşteri Seçimi (Android style)
    private var customerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Müşteri Seçimi")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let selectedCustomer = viewModel.selectedCustomer {
                // Seçilen müşteri card'ı (Android like)
                selectedCustomerCard(customer: selectedCustomer)
            } else {
                // Müşteri arama input'u
                customerSearchInput
            }
        }
    }
    
    // Seçilen müşteri card'ı (Material Design like - BarcodeUploadView ile birebir aynı)
    private func selectedCustomerCard(customer: Customer) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(customer.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                        
                if let code = customer.code, !code.isEmpty {
                    Text("Kod: \(code)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.selectedCustomer = nil
                    viewModel.searchText = ""
                    viewModel.customers = []
                    viewModel.showDropdown = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button("Değiştir") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.selectedCustomer = nil
                    viewModel.searchText = ""
                    viewModel.customers = []
                    viewModel.showDropdown = false
                }
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // Müşteri arama input'u (BarcodeUploadView ile birebir aynı)
    private var customerSearchInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                Group {
                    if #available(iOS 15.0, *) {
                        // iOS 15+ gelişmiş özellikler
                        TextField("Müşteri ara...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                            .focused($isSearchFieldFocused)
                            .onSubmit {
                                if viewModel.searchText.count >= 2 {
                                    viewModel.searchCustomers()
                                }
                            }
                            .onTapGesture {
                                // Manuel focus tetikle
                                isSearchFieldFocused = true
                            }
                    } else {
                        // iOS 14 fallback
                        TextField("Müşteri ara...", text: $viewModel.searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16))
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                }
                .onChange(of: viewModel.searchText) { newValue in
                    if newValue.count >= 2 {
                        viewModel.searchCustomers()
                    } else if newValue.isEmpty {
                        viewModel.customers = []
                        viewModel.showDropdown = false
                    }
                }
                
                if viewModel.isSearching {
                    if #available(iOS 15.0, *) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
            }
            .padding(.horizontal, 16)  // Horizontal padding artırıldı
            .padding(.vertical, 16)    // Vertical padding artırıldı (yükseklik için)
            .background(
                RoundedRectangle(cornerRadius: 12)  // Corner radius artırıldı
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)  // Subtle shadow
            )
            
            // Dropdown müşteri listesi
            if viewModel.showDropdown && !viewModel.customers.isEmpty {
                customerDropdown
            }
        }
    }
    
    // Müşteri dropdown listesi (BarcodeUploadView ile birebir aynı)
    private var customerDropdown: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.customers.prefix(5)) { customer in
                CustomerRow(customer: customer) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.selectedCustomer = customer
                        viewModel.showDropdown = false
                        viewModel.searchText = ""
                        viewModel.customers = []
                        
                        // 🎯 iOS 15+ için focus'u kaldır
                        if #available(iOS 15.0, *) {
                            isSearchFieldFocused = false
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Resim Yükleme Bölümü (BarcodeUploadView ile birebir aynı)
    private var imageUploadSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Müşteri Resmi Yükleme")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Android like button layout
            HStack(spacing: 12) {
                // Kamera butonu (birincil - Android like)
                Button(action: {
                    viewModel.showingCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Hızlı Çekim")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // Galeri butonu (ikincil - Android like)
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Galeriden")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Kayıtlı Müşteri Resimleri Bölümü (Android Accordion design)
    private var savedImagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Müşteri Resimleri")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Toplam müşteri sayısı badge
                if !viewModel.customerImageGroups.isEmpty {
                    Text("\(viewModel.customerImageGroups.count) müşteri")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            

            
            if viewModel.customerImageGroups.isEmpty {
                // Boş durum (Android empty state)
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("Henüz resim eklenmemiş")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Müşteri seçerek resim eklemeye başlayın")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            } else {
                // Müşteri kartları (Android like - Accordion)
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.customerImageGroups, id: \.customerName) { group in
                        CustomerImageGroupCard(
                            group: group,
                            isExpanded: expandedCustomerId == group.customerName,
                            onExpand: {
                                // Accordion davranışı: Bir müşteri açıldığında diğerleri kapansın
                                if expandedCustomerId == group.customerName {
                                    expandedCustomerId = nil // Aynı müşteriye basıldıysa kapat
                                } else {
                                    expandedCustomerId = group.customerName // Farklı müşteriye basıldıysa onları kapat, bunu aç
                                }
                            },
                            onDeleteCustomer: {
                                // Onay dialogu göster
                                customerToDelete = group.customerName
                                showingDeleteCustomerAlert = true
                            },
                            onDeleteImage: { imagePath in
                                viewModel.deleteImageByPath(imagePath)
                            },
                            onViewImage: { imagePath in
                                // 🎯 Resim önizleme - QuickLook ile
                                previewImage(imagePath: imagePath)
                            },
                            onShareWhatsApp: { customerName, imagePaths in
                                viewModel.shareToWhatsApp(customerName: customerName, imagePaths: imagePaths)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // 🎯 Basit resim önizleme - Sheet ile
    private func previewImage(imagePath: String) {
        guard FileManager.default.fileExists(atPath: imagePath) else {
            print("⚠️ Resim dosyası bulunamadı: \(imagePath)")
            return
        }
        
        print("📁 Resim yolu: \(imagePath)")
        
        // Basit sheet ile resim göster
        let url = URL(fileURLWithPath: imagePath)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let imageViewController = SimpleImageViewController(imageURL: url)
            let navController = UINavigationController(rootViewController: imageViewController)
            rootVC.present(navController, animated: true)
        }
    }

}



// LoadingOverlay ve CustomerImageCard BarcodeUploadView'da tanımlı - tekrar tanımlamaya gerek yok

#Preview {
    NavigationView {
        CustomerImagesView()
    }
} 