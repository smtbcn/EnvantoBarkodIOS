import SwiftUI
import PhotosUI

struct CustomerImagesView: View {
    @StateObject private var viewModel = CustomerImagesViewModel()
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var expandedCustomerId: String? = nil
    @State private var showingDeleteCustomerAlert = false
    @State private var customerToDelete: String = ""
    @State private var showingCamera = false
    
    // iOS 15+ Focus State for TextField
    @available(iOS 15.0, *)
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    LoadingOverlay()
                } else if !viewModel.isDeviceAuthorized {
                    // Cihaz yetkili değilse uyarı mesajı göster
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
        .onAppear {
            viewModel.checkDeviceAuthorization()
            viewModel.refreshSavedImages()
        }
        .onChange(of: selectedPhotos) { _ in
            processSelectedPhotos()
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                if let selectedCustomer = viewModel.selectedCustomer {
                    viewModel.saveImageLocally(image, customerName: selectedCustomer.name)
                    viewModel.refreshSavedImages()
                }
                showingCamera = false
            }
        }
        .alert("Müşteri Resimleri", isPresented: $showingAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("Müşteri Sil", isPresented: $showingDeleteCustomerAlert) {
            Button("Sil", role: .destructive) {
                viewModel.deleteCustomerImages(customerName: customerToDelete)
                customerToDelete = ""
            }
            Button("İptal", role: .cancel) {
                customerToDelete = ""
            }
        } message: {
            Text("\(customerToDelete) müşterisine ait tüm resimler silinecek. Bu işlem geri alınamaz.")
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Müşteri Arama Bölümü
            customerSearchSection
            
            // Seçilen Müşteri Kartı
            if let selectedCustomer = viewModel.selectedCustomer {
                selectedCustomerCard(customer: selectedCustomer)
            }
            
            // Resim Yükleme Butonları
            if viewModel.selectedCustomer != nil {
                imageUploadSection
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Kayıtlı Resimler Listesi
            savedImagesSection
        }
        .padding()
    }
    
    // MARK: - Customer Search Section
    private var customerSearchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.selectedCustomer == nil {
                Text("Müşteri Ara")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    TextField("Müşteri adı girin...", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            viewModel.searchCustomers()
                        }
                    
                    Button("Ara") {
                        viewModel.searchCustomers()
                        isSearchFieldFocused = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Arama Sonuçları
                if viewModel.showDropdown && !viewModel.customers.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.customers, id: \.name) { customer in
                                CustomerRowView(customer: customer) {
                                    viewModel.selectCustomer(customer)
                                    isSearchFieldFocused = false
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Selected Customer Card
    private func selectedCustomerCard(customer: Customer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Seçilen Müşteri")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(customer.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    if let code = customer.code {
                        Text("Kod: \(code)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Değiştir") {
                    viewModel.clearSelectedCustomer()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Image Upload Section
    private var imageUploadSection: some View {
        VStack(spacing: 12) {
            Text("Resim Yükle")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                // Galeri Butonu
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("Galeriden Seç", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                // Kamera Butonu
                Button(action: {
                    showingCamera = true
                }) {
                    Label("Fotoğraf Çek", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Saved Images Section
    private var savedImagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Kayıtlı Müşteri Resimleri")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("(\(viewModel.customerImageGroups.count) müşteri)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.customerImageGroups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Henüz müşteri resmi bulunmuyor")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Yukarıdaki butonları kullanarak müşterileriniz için resim ekleyebilirsiniz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.customerImageGroups, id: \.customerName) { group in
                            CustomerImageGroupCard(
                                group: group,
                                isExpanded: expandedCustomerId == group.customerName,
                                onExpand: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if expandedCustomerId == group.customerName {
                                            expandedCustomerId = nil
                                        } else {
                                            expandedCustomerId = group.customerName
                                        }
                                    }
                                },
                                onDeleteCustomer: {
                                    customerToDelete = group.customerName
                                    showingDeleteCustomerAlert = true
                                },
                                onDeleteImage: { imagePath in
                                    viewModel.deleteImage(imagePath: imagePath)
                                },
                                onViewImage: { imagePath in
                                    // TODO: Resim görüntüleme
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
    
    // MARK: - Unauthorized Device View
    private var unauthorizedDeviceView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Cihaz Yetkisi Gerekli")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Bu özelliği kullanabilmek için cihazınızın yetkilendirilmesi gerekiyor. Lütfen yöneticinizle iletişime geçin.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Yeniden Dene") {
                viewModel.checkDeviceAuthorization()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    private func processSelectedPhotos() {
        guard let selectedCustomer = viewModel.selectedCustomer else {
            alertMessage = "Lütfen önce müşteri seçiniz"
            showingAlert = true
            selectedPhotos.removeAll()
            return
        }
        
        Task {
            for photo in selectedPhotos {
                if let data = try? await photo.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    viewModel.saveImageLocally(image, customerName: selectedCustomer.name)
                }
            }
            
            await MainActor.run {
                selectedPhotos.removeAll()
                viewModel.refreshSavedImages()
            }
        }
    }
}

// MARK: - Supporting Views
struct CustomerRowView: View {
    let customer: Customer
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(customer.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let code = customer.code {
                        Text("Kod: \(code)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Yükleniyor...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }
}

// MARK: - Camera View (Basit kamera arayüzü)
struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // Kullanıcı iptal etti - hiçbir şey yapma
        }
    }
}

#Preview {
    NavigationView {
        CustomerImagesView()
    }
} 