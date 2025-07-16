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
            CameraView { capturedImage in
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
    
    // Seçilen müşteri card'ı (Material Design like)
    private func selectedCustomerCard(customer: Customer) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(customer.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Seçili Müşteri")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Değiştir") {
                viewModel.clearSelectedCustomer()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Müşteri arama input'u (Android AutoCompleteTextView benzeri)
    private var customerSearchInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                if #available(iOS 15.0, *) {
                    TextField("Müşteri adı ile arama yapın...", text: $viewModel.searchText)
                        .focused($isSearchFieldFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            viewModel.searchCustomers()
                        }
                } else {
                    TextField("Müşteri adı ile arama yapın...", text: $viewModel.searchText, onCommit: {
                        viewModel.searchCustomers()
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                }
                
                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(viewModel.showDropdown ? Color.blue : Color.clear, lineWidth: 1)
            )
            
            // Dropdown arama sonuçları (Android Spinner benzeri)
            if viewModel.showDropdown && !viewModel.customers.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.customers.prefix(5), id: \.name) { customer in
                        customerDropdownItem(customer: customer)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .animation(.easeInOut(duration: 0.2), value: viewModel.showDropdown)
            }
        }
        .onChange(of: viewModel.searchText) { _ in
            viewModel.searchCustomers()
        }
    }
    
    private func customerDropdownItem(customer: Customer) -> some View {
        Button(action: {
            viewModel.selectCustomer(customer)
        }) {
            HStack {
                Text(customer.name)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                    .opacity(0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(Color(.systemGray6).opacity(0.5))
                .opacity(0)
        )
    }
    
    // MARK: - Resim Yükleme Bölümü (Android like)
    private var imageUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resim Ekle")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Resim seçme butonları (Android like)
            HStack(spacing: 12) {
                // Galeri butonu
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18))
                        Text("Galeri")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                    )
                }
                
                // Kamera butonu
                Button(action: {
                    viewModel.showingCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera")
                            .font(.system(size: 18))
                        Text("Kamera")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green)
                    )
                }
            }
        }
    }
    
    // MARK: - Kayıtlı Resimler Bölümü (Android Accordion design)
    private var savedImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kayıtlı Resimler")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("(\(viewModel.customerImageGroups.count) müşteri)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                                // Resim görüntüleme işlemi (opsiyonel)
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
}

// LoadingOverlay ve CustomerImageCard BarcodeUploadView'da tanımlı - tekrar tanımlamaya gerek yok

#Preview {
    NavigationView {
        CustomerImagesView()
    }
} 