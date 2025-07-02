import SwiftUI
import PhotosUI
import AVFoundation
import Combine

// Gerçek kamera view implementasyonu (sürekli çekim)
struct CameraView: View {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraModel = CameraModel()
    @State private var captureCount = 0
    @State private var showFlash = false
    @State private var showSuccessIndicator = false
    
    var body: some View {
            ZStack {
            // Kamera preview
            CameraPreview(session: cameraModel.session)
                .ignoresSafeArea()
                .onTapGesture(coordinateSpace: .local) { location in
                    cameraModel.focusAt(point: location)
                }
            
            // Flash overlay
            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 0.1), value: showFlash)
            }
            
            // Başarı göstergesi
            if showSuccessIndicator {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("Kaydedildi!")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(25)
                    .scaleEffect(showSuccessIndicator ? 1.0 : 0.5)
                    .opacity(showSuccessIndicator ? 1.0 : 0.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showSuccessIndicator)
                    
                    Spacer()
                        .frame(height: 120)
                }
            }
            
            // Camera controls overlay
            VStack {
                // Üst kontroller
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Çekim sayacı
                    Text("Çekilen: \(captureCount)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(15)
                    
                    Spacer()
                    
                    Button(action: {
                        cameraModel.toggleFlash()
                    }) {
                        Image(systemName: cameraModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                            .font(.title2)
                            .foregroundColor(cameraModel.isFlashOn ? .yellow : .white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // Alt kontroller
                VStack(spacing: 20) {
                    // Ana çekim butonu
                    Button(action: {
                        capturePhoto()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 90, height: 90)
                            
                            // Loading indicator
                            if cameraModel.isCapturing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(1.5)
                            }
                        }
                    }
                    .scaleEffect(cameraModel.isCapturing ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: cameraModel.isCapturing)
                    .disabled(cameraModel.isCapturing)
                    
                    Text("Resim çekmek için butona basın")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            cameraModel.startSession()
        }
        .onDisappear {
            cameraModel.stopSession()
        }
    }
    
    private func capturePhoto() {
        // Flash efekti
        withAnimation(.easeInOut(duration: 0.1)) {
            showFlash = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showFlash = false
        }
        
        cameraModel.capturePhoto { image in
            if let image = image {
                DispatchQueue.main.async {
                    onImageCaptured(image)
                    captureCount += 1
                    
                    // Başarı göstergesi
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        showSuccessIndicator = true
                    }
                    
                    // Başarı göstergesini gizle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSuccessIndicator = false
                        }
                    }
                    
                    // Başarı haptik feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }
}

// MARK: - Camera Model
class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isCapturing = false
    @Published var isFlashOn = false
    
    private var photoOutput = AVCapturePhotoOutput()
    private var captureDevice: AVCaptureDevice?
    private var photoCompletion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        // Kamera cihazını seç
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            return
        }
        
        captureDevice = device
        
        do {
            // Kamera input
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // Photo output
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            
            // Kamera ayarları
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
            
        } catch {
            print("❌ Kamera ayarlama hatası: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard !isCapturing else { return }
        
        photoCompletion = completion
        isCapturing = true
        
        let settings = AVCapturePhotoSettings()
        
        // Flash ayarı
        if captureDevice?.hasFlash == true {
            settings.flashMode = isFlashOn ? .on : .off
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    func focusAt(point: CGPoint) {
        guard let device = captureDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
                device.focusPointOfInterest = point
            }
            
            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
                device.exposurePointOfInterest = point
            }
            
            device.unlockForConfiguration()
        } catch {
            print("❌ Odaklama hatası: \(error)")
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { 
            isCapturing = false 
        }
        
        if let error = error {
            print("❌ Foto çekim hatası: \(error)")
            photoCompletion?(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCompletion?(nil)
            return
        }
        
        photoCompletion?(image)
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Preview layer güncelleme gerekirse
    }
}

struct BarcodeUploadView: View {
    @StateObject private var viewModel = BarcodeUploadViewModel()
    @StateObject private var uploadService = UploadService.shared
    @State private var showingCamera = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var expandedCustomerId: String?
    @State private var showingDeleteCustomerAlert = false
    @State private var customerToDelete: String?
    @FocusState private var isSearchFieldFocused: Bool  // Focus state eklendi
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
            .alert("Müşteri Klasörünü Sil", isPresented: $showingDeleteCustomerAlert) {
                Button("İptal", role: .cancel) { }
                Button("Sil", role: .destructive) {
                    // Müşteri klasörünü sil
                    viewModel.deleteCustomerFolder(customerToDelete)
                    // Eğer silinen müşteri açıksa accordion'u kapat
                    if expandedCustomerId == customerToDelete {
                        expandedCustomerId = nil
                    }
                    customerToDelete = nil
                }
            } message: {
                Text("'\(customerToDelete ?? "")' müşterisine ait tüm resimler silinecek. Bu işlem geri alınamaz.")
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
        .onReceive(NotificationCenter.default.publisher(for: .uploadCompleted)) { _ in
            // Upload tamamlandığında resim listesini yenile
            DispatchQueue.main.async {
                viewModel.loadCustomerImageGroups()
                print("🔄 BarcodeUploadView: Upload tamamlandı, resim listesi yenileniyor")
            }
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
            
            Text("Bu cihaz barkod yükleme işlemi için yetkilendirilmemiş. Lütfen sistem yöneticisine başvurun.")
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
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Button(action: {
                        UIPasteboard.general.string = DeviceIdentifier.getUniqueDeviceId()
                        
                        // Toast göster
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.title2)
                    }
                }
            }
            
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
                    .font(.system(size: 16))  // Font boyutu ayarla
                    .autocapitalization(.none)  // Otomatik büyük harf kapatma
                    .disableAutocorrection(true)  // Otomatik düzeltme kapatma
                    .textContentType(.name)  // İçerik tipi belirleme
                    .focused($isSearchFieldFocused)  // Focus state bağla
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
            .padding(.horizontal, 16)  // Yatay padding artırıldı
            .padding(.vertical, 14)     // Dikey padding artırıldı (yükseklik için)
            .background(
                RoundedRectangle(cornerRadius: 10)  // Corner radius artırıldı
                    .fill(Color(.systemBackground))
                    .stroke(viewModel.searchText.isEmpty ? Color(.systemGray4) : Color.blue, lineWidth: 1)
            )
            .contentShape(Rectangle())  // Tüm alan tıklanabilir
            .onTapGesture {
                // Modern focus yönetimi - Anında klavye açılması için
                isSearchFieldFocused = true
            }
            
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
                        isSearchFieldFocused = false  // Klavye kapat
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
            
            // Upload Status Card (Android mantığı)
            uploadStatusCard
            
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
                // Müşteri kartları (Android like - Accordion)
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.customerImageGroups) { group in
                        CustomerImageCard(
                            group: group,
                            isExpanded: expandedCustomerId == group.customerName,
                            onToggle: {
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
                            onDeleteImage: { image in
                                viewModel.deleteImage(image)
                        }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Upload Status Card (Android benzeri yükleme durumu)
    private var uploadStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Ana Status Row
            HStack {
                // Status ikonu
                Image(systemName: getStatusIcon())
                .font(.title2)
                    .foregroundColor(getStatusColor())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sunucu Yükleme Durumu")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(uploadService.uploadStatus)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(getStatusColor())
                }
                
                Spacer()
                
                // Progress badge
                if uploadService.uploadProgress.total > 0 {
                    VStack(spacing: 4) {
                        Text("\(uploadService.uploadProgress.current)/\(uploadService.uploadProgress.total)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        let progress = Double(uploadService.uploadProgress.current) / Double(uploadService.uploadProgress.total)
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: getStatusColor()))
                            .frame(width: 50)
                    }
                }
            }
            
            // Network Durumu (Android tarzı)
            HStack(spacing: 8) {
                Image(systemName: getNetworkIcon())
                    .font(.caption)
                    .foregroundColor(getNetworkColor())
                
                Text(getNetworkStatus())
                    .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
                
                // WiFi-only ayarı göstergesi
                if UserDefaults.standard.bool(forKey: Constants.UserDefaults.wifiOnly) {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi")
                            .font(.caption2)
                        Text("Sadece WiFi")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(getCardBackgroundColor())
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(getCardBorderColor(), lineWidth: 1)
        )
    }
    
    // MARK: - Upload Status Helper Methods
    private func getStatusIcon() -> String {
        if uploadService.isUploading {
            return "icloud.and.arrow.up"
        } else if uploadService.uploadStatus.contains("WiFi") || uploadService.uploadStatus.contains("İnternet") {
            return "wifi.exclamationmark"
        } else if uploadService.uploadStatus.contains("Yüklendi") || uploadService.uploadStatus.contains("✅") {
            return "checkmark.icloud"
        } else if uploadService.uploadStatus.contains("yetkili değil") {
            return "exclamationmark.shield"
        } else {
            return "icloud"
        }
    }
    
    private func getStatusColor() -> Color {
        if uploadService.isUploading {
            return .blue
        } else if uploadService.uploadStatus.contains("WiFi") || uploadService.uploadStatus.contains("İnternet") {
            return .orange
        } else if uploadService.uploadStatus.contains("Yüklendi") || uploadService.uploadStatus.contains("✅") {
            return .green
        } else if uploadService.uploadStatus.contains("yetkili değil") {
            return .red
        } else {
            return .secondary
        }
    }
    
    private func getCardBackgroundColor() -> Color {
        if uploadService.isUploading {
            return Color.blue.opacity(0.1)
        } else if uploadService.uploadStatus.contains("WiFi") || uploadService.uploadStatus.contains("İnternet") {
            return Color.orange.opacity(0.1)
        } else if uploadService.uploadStatus.contains("Yüklendi") || uploadService.uploadStatus.contains("✅") {
            return Color.green.opacity(0.1)
        } else if uploadService.uploadStatus.contains("yetkili değil") {
            return Color.red.opacity(0.1)
        } else {
            return Color(.systemGray6)
        }
    }
    
    private func getCardBorderColor() -> Color {
        if uploadService.isUploading {
            return Color.blue.opacity(0.3)
        } else if uploadService.uploadStatus.contains("WiFi") || uploadService.uploadStatus.contains("İnternet") {
            return Color.orange.opacity(0.3)
        } else if uploadService.uploadStatus.contains("Yüklendi") || uploadService.uploadStatus.contains("✅") {
            return Color.green.opacity(0.3)
        } else if uploadService.uploadStatus.contains("yetkili değil") {
            return Color.red.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private func getNetworkIcon() -> String {
        let networkUtils = NetworkUtils.shared
        if !networkUtils.isConnected {
            return "wifi.slash"
        } else if networkUtils.isWiFiConnected {
            return "wifi"
        } else {
            return "cellularbars"
        }
    }
    
    private func getNetworkColor() -> Color {
        let networkUtils = NetworkUtils.shared
        if !networkUtils.isConnected {
            return .red
        } else if networkUtils.isWiFiConnected {
            return .green
        } else {
            return .orange
        }
    }
    
    private func getNetworkStatus() -> String {
        let networkUtils = NetworkUtils.shared
        if !networkUtils.isConnected {
            return "İnternet bağlantısı yok"
        } else if networkUtils.isWiFiConnected {
            return "WiFi bağlı"
        } else {
            return "Mobil veri bağlı"
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

// MARK: - Customer Image Card (Android Resim Yükleme tasarımı)
struct CustomerImageCard: View {
    let group: CustomerImageGroup
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDeleteCustomer: () -> Void
    let onDeleteImage: (SavedImage) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Müşteri header'ı (Android Material Design like)
            Button(action: {
                onToggle() // Animasyonu kaldırdık, direk toggle
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
                        
                        Text("Kayıtlı Resimler (\(group.imageCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
                    
                    Spacer()
                    
                    // Müşteri klasörü silme butonu
                    Button(action: {
                        onDeleteCustomer()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
        }
        .buttonStyle(PlainButtonStyle())
                    
                    // Expand/Collapse ikonu
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Resim listesi (Android like - vertical list)
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(group.images) { image in
                            AndroidImageRow(image: image) {
                                onDeleteImage(image)
                            }
                            
                            // Son item değilse divider ekle
                            if image.id != group.images.last?.id {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
                .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

// MARK: - Android Image Row (Resim Yükleme'deki gibi)
struct AndroidImageRow: View {
    let image: SavedImage
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Sol: Resim preview (Android like)
            AsyncImage(url: URL(fileURLWithPath: image.localPath)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipped()
                        .cornerRadius(6)
                        
                case .failure(_):
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .frame(width: 50, height: 50)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                        
                case .empty:
                    ProgressView()
                        .frame(width: 50, height: 50)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                        
                @unknown default:
                    EmptyView()
                }
            }
            
            // Orta: Dosya bilgileri (Android like)
            VStack(alignment: .leading, spacing: 4) {
                // Dosya adı (sadece filename)
                Text(extractFileName(from: image.localPath))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Upload durumu (Android tarzı)
                HStack(spacing: 6) {
                    Image(systemName: getUploadStatusIcon())
                        .font(.system(size: 12))
                        .foregroundColor(getUploadStatusColor())
                    
                    Text(getUploadStatusText())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(getUploadStatusColor())
                    
                    Spacer()
                }
                
                // Müşteri bilgisi
                Text("Müşteri: \(image.customerName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Tarih ve yükleyen - 2 satır
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tarih: \(formattedDate(image.uploadDate))")
                        .font(.caption)
                    .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text("Yükleyen: \(getUploaderName())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Sağ: Silme butonu (Android like)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private func extractFileName(from path: String) -> String {
        return URL(fileURLWithPath: path).lastPathComponent
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    private func getUploaderName() -> String {
        // 🗄️ Database'den yukleyen bilgisini kullan
        return image.yukleyen.isEmpty ? "Bilinmeyen Kullanıcı" : image.yukleyen
    }
    
    private func getUploadStatusIcon() -> String {
        // Bu bilgiyi database'den alacağız
        // Şimdilik placeholder - gelecekte isUploaded kontrolü
        return image.isUploaded ? "checkmark.circle.fill" : "clock.circle"
    }
    
    private func getUploadStatusColor() -> Color {
        return image.isUploaded ? .green : .orange
    }
    
    private func getUploadStatusText() -> String {
        return image.isUploaded ? "SUNUCUYA YÜKLENDİ" : "YÜKLEME BEKLİYOR"
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