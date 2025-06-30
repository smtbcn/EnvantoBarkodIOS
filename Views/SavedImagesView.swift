import SwiftUI

// MARK: - Saved Images View (Android refreshSavedImagesList equivalent)
struct SavedImagesView: View {
    @State private var uploadedCustomers: [String] = []
    @State private var selectedCustomer: String?
    @State private var customerImages: [String] = []
    @State private var isLoading = false
    
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
                } else if selectedCustomer == nil {
                    // Customer List (Android style)
                    customerListView
                } else {
                    // Customer Images (Android style)
                    customerImagesView
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadUploadedCustomers()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                if selectedCustomer != nil {
                    Button(action: {
                        selectedCustomer = nil
                        customerImages = []
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 18, weight: .medium))
                            Text("Geri")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 80, height: 44)
                }
                
                Spacer()
                
                Text(selectedCustomer ?? "Kaydedilen Resimler")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 80, height: 44)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
            
            Divider()
        }
    }
    
    // MARK: - Customer List View (Android UploadedCustomersAdapter equivalent)
    private var customerListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if uploadedCustomers.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "photo.stack")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Henüz kaydedilmiş resim bulunmuyor")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text("Barkod yükleme sayfasından resim ekleyin")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
            } else {
                List {
                    ForEach(uploadedCustomers, id: \.self) { customer in
                        CustomerRowView(
                            customerName: customer,
                            imageCount: SQLiteManager.shared.getCustomerImageCount(musteriAdi: customer)
                        ) {
                            selectedCustomer = customer
                            loadCustomerImages(customer: customer)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    // MARK: - Customer Images View (Android ImagesAdapter equivalent)
    private var customerImagesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if customerImages.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("\(selectedCustomer ?? "") müşterisine ait resim bulunamadı")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Array(customerImages.enumerated()), id: \.offset) { index, imagePath in
                            CustomerImageView(imagePath: imagePath) {
                                // Image tap action
                                print("Tapped image: \(imagePath)")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
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
            // Get image paths from file system (Android getCustomerImages equivalent)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let customerDirectory = documentsPath
                .appendingPathComponent("EnvantoBarkod")
                .appendingPathComponent(customer)
            
            var imagePaths: [String] = []
            
            do {
                let files = try FileManager.default.contentsOfDirectory(at: customerDirectory, includingPropertiesForKeys: nil)
                imagePaths = files.compactMap { url in
                    let fileName = url.lastPathComponent.lowercased()
                    if fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") || fileName.hasSuffix(".png") {
                        return url.path
                    }
                    return nil
                }.sorted()
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

// MARK: - Customer Row View (Android customer list item equivalent)
struct CustomerRowView: View {
    let customerName: String
    let imageCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customerName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text("\(imageCount) resim")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(UIColor.systemBackground))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Customer Image View (Android image grid item equivalent)
struct CustomerImageView: View {
    let imagePath: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = UIImage(contentsOfFile: imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(8)
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
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SavedImagesView()
}