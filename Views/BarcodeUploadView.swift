import SwiftUI
import PhotosUI

// Basit kamera view (geçici implementasyon)
struct CameraView: View {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Kamera Çekim")
                .font(.title)
                .padding()
            
            Text("Geçici kamera implementasyonu")
                .foregroundColor(.secondary)
                .padding()
            
            Button("Test Resim Çek") {
                // Test için dummy resim
                if let testImage = UIImage(systemName: "photo") {
                    onImageCaptured(testImage)
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Button("İptal") {
                dismiss()
            }
            .padding()
        }
    }
}

struct BarcodeUploadView: View {
    @StateObject private var viewModel = BarcodeUploadViewModel()
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    if viewModel.isLoading {
                        LoadingOverlay()
                    } else {
                        mainContent
                    }
                }
            }
            .navigationTitle("Barkod Yükleme")
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
        }
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
    
    // Müşteri arama input'u
    private var customerSearchInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Müşteri ara...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: viewModel.searchText) { newValue in
                        if newValue.count >= 2 {
                            viewModel.searchCustomers()
                        } else if newValue.isEmpty {
                            viewModel.customers = []
                            viewModel.showDropdown = false
                        }
                    }
                
                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            
            // Dropdown müşteri listesi
            if viewModel.showDropdown && !viewModel.customers.isEmpty {
                customerDropdown
            }
        }
    }
    
    // Müşteri dropdown listesi
    private var customerDropdown: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.customers.prefix(5)) { customer in
                CustomerRow(customer: customer) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.selectedCustomer = customer
                        viewModel.showDropdown = false
                        viewModel.searchText = ""
                        viewModel.customers = []
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Resim Yükleme Bölümü (Android like conditional visibility)
    private var imageUploadSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Barkod Resmi Yükleme")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Debug butonu - Path'leri kontrol et
            Button("📱 Path'leri Kontrol Et") {
                ImageStorageManager.printDocumentsPath()
            }
            .font(.caption)
            .foregroundColor(.orange)
            .padding(.vertical, 4)
            
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
    
    // MARK: - Müşteri Bazlı Resimler Bölümü (Android like customer cards)
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
                VStack {
                    Image(systemName: "person.2.square.stack")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("Henüz müşteriye ait resim yok")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Müşteri kartları (Android like)
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.customerImageGroups) { group in
                        CustomerImageCard(
                            group: group,
                            onDeleteImage: { image in
                                viewModel.deleteImage(image)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Customer Row Component (Android like design)
struct CustomerRow: View {
    let customer: Customer
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Müşteri ikonu (Material Design like)
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let code = customer.code, !code.isEmpty {
                        Text("Kod: \(code)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
        
        // Divider (Android like)
        Divider()
            .padding(.leading, 44) // İkon ile hizalı
    }
}

// MARK: - Customer Image Card (Müşteri bazlı resim kartı)
struct CustomerImageCard: View {
    let group: CustomerImageGroup
    let onDeleteImage: (SavedImage) -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Müşteri header'ı (Android Material Design like)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    // Müşteri ikonu
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.customerName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(group.imageCount) resim • \(formattedDate(group.lastUpdated))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Resim sayısı badge
                    Text("\(group.imageCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(10)
                    
                    // Expand/Collapse ikonu
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Resim grid'i (expandable)
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(group.images) { image in
                            SavedImageCard(image: image) {
                                onDeleteImage(image)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Saved Image Card
struct SavedImageCard: View {
    let image: SavedImage
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(fileURLWithPath: image.localPath)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(6)
                        
                case .failure(_):
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .frame(width: 60, height: 60)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                        
                case .empty:
                    ProgressView()
                        .frame(width: 60, height: 60)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                        
                @unknown default:
                    EmptyView()
                }
            }
            
            Text(image.customerName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Button("Sil") {
                onDelete()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Cihaz yetkilendirme kontrol ediliyor...")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}

#Preview {
    BarcodeUploadView()
} 