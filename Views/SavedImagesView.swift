import SwiftUI

// MARK: - Saved Images View (Android refreshSavedImagesList equivalent)
struct SavedImagesView: View {
    @State private var uploadedCustomers: [String] = []
    @State private var selectedCustomer: String?
    @State private var customerImages: [(path: String, isUploading: Bool)] = []
    @State private var isLoading = false
    @State private var isExpanded = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                if isLoading {
                    Spacer()
                    ProgressView("Müşteri listesi yükleniyor...")
                        .scaleEffect(1.2)
                    Spacer()
                } else {
                    // Customer List with Expandable Images
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(uploadedCustomers, id: \.self) { customer in
                                CustomerSection(
                                    customerName: customer,
                                    imageCount: SQLiteManager.shared.getCustomerImageCount(musteriAdi: customer),
                                    isExpanded: selectedCustomer == customer,
                                    images: selectedCustomer == customer ? customerImages : [],
                                    onHeaderTap: {
                                        if selectedCustomer == customer {
                                            selectedCustomer = nil
                                            customerImages = []
                                        } else {
                                            selectedCustomer = customer
                                            loadCustomerImages(customer: customer)
                                        }
                                    }
                                )
                                .animation(.easeInOut, value: selectedCustomer)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadUploadedCustomers()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Kayıtlı Resimler")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            
            Divider()
        }
    }
    
    // MARK: - Helper Methods
    private func loadUploadedCustomers() {
        isLoading = true
        
        DispatchQueue.global(qos: .background).async {
            let customers = SQLiteManager.shared.getUploadedCustomers()
            
            DispatchQueue.main.async {
                self.uploadedCustomers = customers
                self.isLoading = false
                print("📋 Loaded \(customers.count) uploaded customers")
            }
        }
    }
    
    private func loadCustomerImages(customer: String) {
        DispatchQueue.global(qos: .background).async {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let customerDirectory = documentsPath
                .appendingPathComponent("EnvantoBarkod")
                .appendingPathComponent(customer)
            
            var imagePaths: [(path: String, isUploading: Bool)] = []
            
            do {
                let files = try FileManager.default.contentsOfDirectory(at: customerDirectory, includingPropertiesForKeys: nil)
                imagePaths = files.compactMap { url in
                    let fileName = url.lastPathComponent.lowercased()
                    if fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") || fileName.hasSuffix(".png") {
                        // Check if image is waiting for upload
                        let isUploading = !SQLiteManager.shared.isImageUploaded(imagePath: url.path)
                        return (url.path, isUploading)
                    }
                    return nil
                }.sorted(by: { $0.path < $1.path })
            } catch {
                print("❌ Error loading customer images: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                self.customerImages = imagePaths
                print("📋 Loaded \(imagePaths.count) images for customer: \(customer)")
            }
        }
    }
}

// MARK: - Customer Section
struct CustomerSection: View {
    let customerName: String
    let imageCount: Int
    let isExpanded: Bool
    let images: [(path: String, isUploading: Bool)]
    let onHeaderTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onHeaderTap) {
                HStack {
                    Text(customerName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("(\(imageCount))")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
            }
            
            // Images Grid
            if isExpanded {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        CustomerImageCell(imagePath: image.path, isUploading: image.isUploading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
            }
            
            Divider()
        }
    }
}

// MARK: - Customer Image Cell
struct CustomerImageCell: View {
    let imagePath: String
    let isUploading: Bool
    
    var body: some View {
        ZStack {
            if let image = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(8)
                
                if isUploading {
                    Color.black.opacity(0.5)
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("İnternet Bekleniyor")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(4)
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        }
    }
}

#Preview {
    SavedImagesView()
}