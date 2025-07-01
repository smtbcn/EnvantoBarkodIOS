import SwiftUI

// MARK: - Saved Images View (Android CustomerImagesActivity birebir equivalent)
struct SavedImagesView: View {
    @State private var uploadedCustomers: [String] = []
    @State private var selectedCustomer: String?
    @State private var customerImages: [String] = []
    @State private var isLoading = false
    @State private var isCheckingAuth = true
    @State private var isAuthSuccess = false
    @State private var showingDeviceAuthDialog = false
    @State private var selectedImageType: ImageType = .barkod // Android'deki tab sistemi
    
    // Sanal PC performansı için lazy loading
    @State private var isViewLoaded = false
    
    // Android CustomerImagesActivity'deki gibi image type enum
    enum ImageType: String, CaseIterable {
        case barkod = "Barkod Resimleri"
        case musteri = "Müşteri Resimleri"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                if isCheckingAuth {
                    // Yetki kontrolü yapılıyor
                    VStack(spacing: 20) {
                        Spacer()
                        ProgressView("Cihaz yetkilendirmesi kontrol ediliyor...")
                            .scaleEffect(1.2)
                        Spacer()
                    }
                } else if !isAuthSuccess {
                    // Yetkisiz kullanıcı - Android benzeri mesaj
                    VStack(spacing: 20) {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Image(systemName: "lock.circle")
                                .font(.system(size: 64))
                                .foregroundColor(.orange)
                            
                            Text("Cihaz Yetkilendirme Gerekli")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Bu özelliği kullanabilmek için cihazınızın yetkilendirilmesi gerekiyor.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            Button(action: {
                                showingDeviceAuthDialog = true
                            }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                    Text("Yetkilendirme İsteği")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    // Yetkili kullanıcı içeriği
                    VStack(spacing: 0) {
                        // Android'deki gibi tab seçici
                        imageTypeSegmentedControl
                        
                        if isLoading {
                            // Yetkili kullanıcı - liste yükleniyor
                            VStack(spacing: 20) {
                                Spacer()
                                ProgressView("Resimler yükleniyor...")
                                    .scaleEffect(1.2)
                                Spacer()
                            }
                        } else if selectedCustomer == nil {
                            // Customer List (Android style)
                            customerListView
                        } else {
                            // Customer Images (Android style)
                            customerImagesView
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !isViewLoaded {
                // Sanal PC performansı için lazy initialization
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    checkDeviceAuthorization()
                    isViewLoaded = true
                }
            }
        }
        .onChange(of: showingDeviceAuthDialog) { showing in
            if showing {
                // Android benzeri device auth dialog göster
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootViewController = window.rootViewController {
                        
                        DeviceAuthManager.showDeviceAuthDialog(on: rootViewController) { success in
                            showingDeviceAuthDialog = false
                            if success {
                                checkDeviceAuthorization() // Yeniden kontrol et
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedImageType) { _ in
            // Image type değiştiğinde müşteri listesini yenile
            selectedCustomer = nil
            customerImages = []
            if isAuthSuccess {
                loadUploadedCustomers()
            }
        }
    }
    
    // MARK: - Header View (Android ActionBar benzeri)
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
                
                Text(selectedCustomer ?? "Resimler")
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
    
    // MARK: - Image Type Segmented Control (Android Tab benzeri)
    private var imageTypeSegmentedControl: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ImageType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedImageType = type
                    }) {
                        Text(type.rawValue)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedImageType == type ? .white : .blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedImageType == type ? Color.blue : Color.clear)
                    }
                }
            }
            .background(Color(UIColor.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.3))
                    .offset(y: 0),
                alignment: .bottom
            )
            
            Divider()
        }
    }
    
    // MARK: - Customer List View (Android CustomerAdapter equivalent)
    private var customerListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if uploadedCustomers.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: selectedImageType == .barkod ? "barcode" : "photo.stack")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Henüz \(selectedImageType.rawValue.lowercased()) bulunmuyor")
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
                            imageCount: getCustomerImageCount(customer: customer),
                            imageType: selectedImageType
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
                    
                    Text("\(selectedCustomer ?? "") müşterisine ait \(selectedImageType.rawValue.lowercased()) bulunamadı")
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
    
    // MARK: - Device Authorization Check
    private func checkDeviceAuthorization() {
        isCheckingAuth = true
        
        let callback = SavedImagesDeviceAuthCallback(
            authSuccessHandler: { [self] in
                DispatchQueue.main.async {
                    self.isCheckingAuth = false
                    self.isAuthSuccess = true
                    self.loadUploadedCustomers()
                }
            },
            authFailureHandler: { [self] in
                DispatchQueue.main.async {
                    self.isCheckingAuth = false
                    self.isAuthSuccess = false
                }
            },
            showLoadingHandler: { [self] in
                DispatchQueue.main.async {
                    self.isCheckingAuth = true
                }
            },
            hideLoadingHandler: { [self] in
                DispatchQueue.main.async {
                    self.isCheckingAuth = false
                }
            }
        )
        
        DeviceAuthManager.checkDeviceAuthorization(callback: callback)
    }
    
    // MARK: - Helper Methods
    
    private func loadUploadedCustomers() {
        isLoading = true
        
        DispatchQueue.global(qos: .background).async {
            let customers: [String]
            
            switch selectedImageType {
            case .barkod:
                customers = SQLiteManager.shared.getUploadedCustomers() // TABLE_BARKOD_RESIMLER
            case .musteri:
                customers = SQLiteManager.shared.getUploadedMusteriCustomers() // TABLE_MUSTERI_RESIMLER
            }
            
            DispatchQueue.main.async {
                self.uploadedCustomers = customers
                self.isLoading = false
                print("📋 Loaded \(customers.count) uploaded customers for \(selectedImageType.rawValue)")
            }
        }
    }
    
    private func loadCustomerImages(customer: String) {
        DispatchQueue.global(qos: .background).async {
            var imagePaths: [String] = []
            
            switch selectedImageType {
            case .barkod:
                // Get image paths from barkod_resimler table (Android getBarkodImages equivalent)
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let customerDirectory = documentsPath
                    .appendingPathComponent("EnvantoBarkod")
                    .appendingPathComponent("BarkodImages")
                    .appendingPathComponent(customer)
                
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
                    print("❌ Error loading barkod images: \(error.localizedDescription)")
                }
                
            case .musteri:
                // Get image paths from musteri_resimler table (Android getMusteriImages equivalent)  
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let customerDirectory = documentsPath
                    .appendingPathComponent("EnvantoBarkod")
                    .appendingPathComponent("MusteriImages")
                    .appendingPathComponent(customer)
                
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
                    print("❌ Error loading musteri images: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self.customerImages = imagePaths
                print("🖼️ Loaded \(imagePaths.count) images for customer: \(customer) (\(selectedImageType.rawValue))")
            }
        }
    }
    
    private func getCustomerImageCount(customer: String) -> Int {
        switch selectedImageType {
        case .barkod:
            return SQLiteManager.shared.getCustomerImageCount(musteriAdi: customer)
        case .musteri:
            return SQLiteManager.shared.getMusteriResimCount(musteriAdi: customer)
        }
    }
}

// MARK: - Customer Row View (Android CustomerViewHolder equivalent)
struct CustomerRowView: View {
    let customerName: String
    let imageCount: Int
    let imageType: SavedImagesView.ImageType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Müşteri ikonu
                Image(systemName: imageType == .barkod ? "barcode" : "person.circle")
                    .font(.system(size: 24))
                    .foregroundColor(imageType == .barkod ? .blue : .purple)
                    .frame(width: 40, height: 40)
                    .background((imageType == .barkod ? Color.blue : Color.purple).opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(customerName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text("\(imageCount) \(imageType == .barkod ? "barkod" : "müşteri") resmi")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(UIColor.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Customer Image View (Android ImageViewHolder equivalent)
struct CustomerImageView: View {
    let imagePath: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            AsyncImage(url: URL(fileURLWithPath: imagePath)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 100, height: 100)
            .clipped()
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Device Auth Callback Implementation for SavedImagesView
private struct SavedImagesDeviceAuthCallback: DeviceAuthCallback {
    let authSuccessHandler: () -> Void
    let authFailureHandler: () -> Void
    let showLoadingHandler: () -> Void
    let hideLoadingHandler: () -> Void
    
    func onAuthSuccess() {
        authSuccessHandler()
    }
    
    func onAuthFailure() {
        authFailureHandler()
    }
    
    func onShowLoading() {
        showLoadingHandler()
    }
    
    func onHideLoading() {
        hideLoadingHandler()
    }
}

#Preview {
    SavedImagesView()
}