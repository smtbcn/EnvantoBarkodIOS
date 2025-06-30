import SwiftUI
import PhotosUI

struct BarcodeUploadView: View {
    @StateObject private var viewModel = BarcodeUploadViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                // Ana içerik
                VStack(spacing: 0) {
                    if viewModel.isDeviceAuthorized {
                        // Müşteri arama bölümü
                        customerSearchSection
                        
                        // Resim yükleme bölümü
                        imageUploadSection
                        
                        // Kayıtlı resimler listesi
                        savedImagesSection
                    } else if !viewModel.isLoading {
                        // Cihaz yetkili değilse uyarı
                        unauthorizedDeviceView
                    }
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    LoadingOverlay(
                        message: "Cihaz yetkilendirme kontrolü yapılıyor..."
                    )
                }
                
                // Upload progress overlay
                if viewModel.isUploading {
                    UploadProgressOverlay(progress: viewModel.uploadProgress)
                }
            }
            .navigationTitle("Barkod Resmi Yükleme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .alert("Hata", isPresented: $viewModel.showingError) {
                Button("Tamam") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .onChange(of: selectedItems) { _ in
            loadSelectedImages()
        }
        .onAppear {
            if !viewModel.isDeviceAuthorized {
                viewModel.checkDeviceAuthorization()
            }
        }
    }
    
    // MARK: - Customer Search Section
    private var customerSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.blue)
                Text("Müşteri Seçimi")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Arama kutusu
            VStack(alignment: .leading, spacing: 8) {
                TextField("Müşteri adı veya kodu arayın...", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: viewModel.searchText) { _ in
                        viewModel.searchCustomers()
                    }
                
                // Dropdown - müşteri listesi
                if viewModel.showDropdown && !viewModel.customers.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(viewModel.customers.prefix(5)) { customer in
                            CustomerRow(customer: customer) {
                                viewModel.selectCustomer(customer)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                
                // Seçilen müşteri
                if let selectedCustomer = viewModel.selectedCustomer {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedCustomer.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let code = selectedCustomer.code {
                                Text("Kod: \(code)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Değiştir") {
                            viewModel.selectedCustomer = nil
                            viewModel.searchText = ""
                            viewModel.showDropdown = false
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Image Upload Section
    private var imageUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık
            HStack {
                Image(systemName: "photo.fill")
                    .foregroundColor(.orange)
                Text("Resim Yükleme")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Yükleme butonları
            HStack(spacing: 12) {
                // Fotoğraf seç
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Galeri")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.selectedCustomer == nil || viewModel.isUploading)
                
                // Kamera
                Button(action: {
                    viewModel.showingCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Kamera")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.selectedCustomer == nil || viewModel.isUploading)
            }
            
            // Seçilen resimler preview
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(8)
                                .overlay(
                                    Button(action: {
                                        selectedImages.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                    }
                                    .offset(x: 8, y: -8),
                                    alignment: .topTrailing
                                )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                // Yükle butonu
                Button(action: {
                    viewModel.uploadImages(selectedImages)
                }) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up.fill")
                        Text("Resimleri Yükle (\(selectedImages.count))")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isUploading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Saved Images Section
    private var savedImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundColor(.purple)
                Text("Kayıtlı Resimler")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.savedImages.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
            }
            
            if viewModel.savedImages.isEmpty {
                // Boş durum
                VStack(spacing: 8) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    
                    Text("Henüz resim yüklenmemiş")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if viewModel.selectedCustomer != nil {
                        Text("Yukarıdaki butonları kullanarak resim ekleyin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Resim listesi
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(viewModel.savedImages) { savedImage in
                        SavedImageThumbnail(savedImage: savedImage)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Unauthorized Device View
    private var unauthorizedDeviceView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("Cihaz Yetkilendirme Gerekli")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Bu özelliği kullanabilmek için cihazınızın yetkilendirilmiş olması gerekir.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Tekrar Dene") {
                viewModel.checkDeviceAuthorization()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Load Selected Images
    private func loadSelectedImages() {
        selectedImages.removeAll()
        
        for item in selectedItems {
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data,
                       let uiImage = UIImage(data: data) {
                        DispatchQueue.main.async {
                            selectedImages.append(uiImage)
                        }
                    }
                case .failure(let error):
                    print("Resim yükleme hatası: \(error)")
                }
            }
        }
    }
}

// MARK: - CustomerRow
struct CustomerRow: View {
    let customer: Customer
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let code = customer.code {
                        Text("Kod: \(code)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(.systemBackground))
    }
}

// MARK: - SavedImageThumbnail
struct SavedImageThumbnail: View {
    let savedImage: SavedImage
    
    var body: some View {
        VStack(spacing: 4) {
            // Placeholder resim (TODO: Gerçek resmi yükle)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray3))
                .frame(height: 80)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.white)
                )
            
            // Upload durumu
            HStack {
                Image(systemName: savedImage.isUploaded ? "checkmark.circle.fill" : "clock.fill")
                    .font(.caption)
                    .foregroundColor(savedImage.isUploaded ? .green : .orange)
                
                Text(savedImage.isUploaded ? "Yüklendi" : "Bekliyor")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Upload Progress Overlay
struct UploadProgressOverlay: View {
    let progress: Float
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("Resimler Yükleniyor...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}

#Preview {
    BarcodeUploadView()
} 