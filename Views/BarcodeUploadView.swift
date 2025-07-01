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
                        // Müşteri arama bölümü (her zaman görünür)
                        customerSearchSection
                        
                        // Resim yükleme bölümü (sadece müşteri seçildiğinde)
                        if viewModel.selectedCustomer != nil {
                            imageUploadSection
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                ))
                        }
                        
                        // Kayıtlı resimler (sadece müşteri seçildiğinde ve resim varsa)
                        if viewModel.selectedCustomer != nil {
                            savedImagesSection
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                ))
                        } else {
                            // Müşteri seçilmediğinde placeholder
                            customerSelectionPlaceholder
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                ))
                        }
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
            
            if let selectedCustomer = viewModel.selectedCustomer {
                // Seçilen müşteri gösterimi (Android like design)
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCustomer.name)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Müşteri seçildi")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Button("Değiştir") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.selectedCustomer = nil
                            viewModel.searchText = ""
                            viewModel.showDropdown = false
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        )
                )
                .animation(.easeInOut(duration: 0.3), value: selectedCustomer)
                
            } else {
                // Müşteri arama inputu (müşteri seçilmediğinde)
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Müşteri adı arayın...", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .onChange(of: viewModel.searchText) { _ in
                            viewModel.searchCustomers()
                        }
                        .submitLabel(.search)
                    
                    // Dropdown - müşteri listesi (customers.asp'den gelecek)
                    if viewModel.showDropdown && !viewModel.customers.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(viewModel.customers.prefix(5)) { customer in
                                CustomerRow(customer: customer) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        viewModel.selectCustomer(customer)
                                    }
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                    }
                    
                    // Yardım metni
                    if viewModel.searchText.isEmpty {
                        Text("Müşteri adı yazarak arama yapabilirsiniz")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.selectedCustomer)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Image Upload Section (Müşteri seçiminden sonra görünür)
    private var imageUploadSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Başlık
            HStack {
                Image(systemName: "photo.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Resim Yükleme")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Upload durumu badge
                if !selectedImages.isEmpty {
                    Text("\(selectedImages.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                }
            }
            
            // Android like açıklama metni
            Text("Fotoğraf çekin veya galeriden seçin")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            
            // Yükleme butonları (Android tasarım)
            VStack(spacing: 12) {
                // Kamera butonu (Birincil)
                Button(action: {
                    viewModel.showingCamera = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fotoğraf Çek")
                                .font(.body)
                                .fontWeight(.semibold)
                            Text("Kamera ile yeni fotoğraf")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isUploading)
                
                // Galeri butonu (İkincil)
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Galeriden Seç")
                                .font(.body)
                                .fontWeight(.semibold)
                            Text("Mevcut fotoğraflardan seç")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isUploading)
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
    
    // MARK: - Customer Selection Placeholder
    private var customerSelectionPlaceholder: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Müşteri Seçin")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Resim yükleyebilmek için önce bir müşteri seçmeniz gerekiyor")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                    Text("Yukarıdaki arama kutusunu kullanın")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.blue)
                    Text("Müşteri adı yazarak arama yapın")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.blue)
                    Text("Listeden müşteriyi seçin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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

// MARK: - CustomerRow (Android like design)
struct CustomerRow: View {
    let customer: Customer
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Müşteri ikonu
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("Müşteri")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
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

#Preview {
    BarcodeUploadView()
} 