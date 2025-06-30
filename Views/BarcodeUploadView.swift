import SwiftUI
import UIKit
import Photos
import AVFoundation
import PhotosUI

// MARK: - Supporting Views

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                
                Text(message)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
        }
    }
}

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            if isShowing && !message.isEmpty {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.3), value: isShowing)
                    .padding(.bottom, 100)
            }
        }
        .allowsHitTesting(false)
    }
}

struct MultipleImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    var onImagesSelected: ([UIImage]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // Unlimited selection
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultipleImagePicker
        
        init(_ parent: MultipleImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard !results.isEmpty else { return }
            
            var images: [UIImage] = []
            let group = DispatchGroup()
            
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                    defer { group.leave() }
                    if let image = object as? UIImage {
                        images.append(image)
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.parent.onImagesSelected(images)
            }
        }
    }
}

struct ContinuousCameraView: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage) -> Void
    var onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> ContinuousCameraViewController {
        let controller = ContinuousCameraViewController()
        controller.onImageCaptured = onImageCaptured
        controller.onDismiss = onDismiss
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ContinuousCameraViewController, context: Context) {}
}

class ContinuousCameraViewController: UIViewController {
    var onImageCaptured: ((UIImage) -> Void)?
    var onDismiss: (() -> Void)?
    
    private var captureSession: AVCaptureSession!
    private var stillImageOutput: AVCapturePhotoOutput!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium
        
        guard let backCamera = AVCaptureDevice.default(for: .video) else {
            print("Unable to access back camera!")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            stillImageOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        } catch let error {
            print("Error Unable to initialize back camera: \(error.localizedDescription)")
        }
    }
    
    private func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(videoPreviewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        let captureButton = UIButton(type: .system)
        captureButton.backgroundColor = .systemBlue
        captureButton.layer.cornerRadius = 35
        captureButton.setTitle("📷", for: .normal)
        captureButton.titleLabel?.font = UIFont.systemFont(ofSize: 30)
        captureButton.tintColor = .white
        captureButton.addTarget(self, action: #selector(captureImage), for: .touchUpInside)
        
        let closeButton = UIButton(type: .system)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 22
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeCamera), for: .touchUpInside)
        
        view.addSubview(captureButton)
        view.addSubview(closeButton)
        
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = view.bounds
    }
    
    @objc private func captureImage() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func closeCamera() {
        onDismiss?()
    }
}

extension ContinuousCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        
        if let image = UIImage(data: imageData) {
            onImageCaptured?(image)
        }
    }
}

// MARK: - Main BarcodeUploadView (Android Layout Compatible)

struct BarcodeUploadView: View {
    @StateObject private var viewModel = BarcodeUploadViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingCameraView = false
    @State private var cameraKey = UUID()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Customer Selection Card
                        if viewModel.selectedCustomer == nil {
                            customerSearchCard
                        } else {
                            selectedCustomerCard
                        }
                        
                        // Image Upload Card
                        androidImageUploadCard
                        
                        // Selected Images Card (Android style)
                        if !selectedImages.isEmpty {
                            androidSelectedImagesCard
                        }
                    }
                    .padding(.vertical, 16)
                }
                
                // Loading Overlay
                if viewModel.isLoading {
                    LoadingOverlay(message: "Lütfen bekleyin...")
                }
                
                // Toast Messages
                ToastView(message: viewModel.toastMessage, isShowing: $viewModel.showingToast)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Kapat") {
                    dismiss()
                }
            )
            .sheet(isPresented: $showingImagePicker) {
                MultipleImagePicker(selectedImages: $selectedImages) { images in
                    handleSelectedImages(images)
                }
            }
            .fullScreenCover(isPresented: $showingCameraView) {
                ContinuousCameraView(
                    onImageCaptured: handleCapturedImage,
                    onDismiss: { showingCameraView = false }
                )
                .id(cameraKey) // Force refresh on capture
            }
        }
        .onAppear {
            viewModel.checkDeviceAuthorization()
        }
    }
    
    // MARK: - Android Style Header
    private var androidHeaderView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    dismiss()
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
                
                Spacer()
                
                Text("Barkod Yükle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Balance the header
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
    
    // MARK: - Android Style Content
    private var androidContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Customer Selection Card (Android CardView style)
                androidCustomerSelectionCard
                
                // Image Upload Card (Only show when customer selected)
                if viewModel.selectedCustomer != nil {
                    androidImageUploadCard
                }
                
                // Selected Images Preview (Android RecyclerView style)
                if !selectedImages.isEmpty {
                    androidSelectedImagesCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Android Customer Selection Card
    private var androidCustomerSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Müşteri Seçimi")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            if viewModel.selectedCustomer == nil {
                // Search Layout (Android AutoCompleteTextView style)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Müşteri adı ile arama yapın...", text: $viewModel.customerSearchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: viewModel.customerSearchText) { newValue in
                                if newValue.count >= 2 {
                                    viewModel.searchCustomers(query: newValue)
                                } else {
                                    viewModel.searchResults = []
                                }
                            }
                        
                        if viewModel.isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Dropdown Results (Android ListView style)
                    if !viewModel.searchResults.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(viewModel.searchResults, id: \.self) { customer in
                                Button(action: {
                                    selectCustomer(customer)
                                }) {
                                    HStack {
                                        Text(customer)
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(UIColor.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if customer != viewModel.searchResults.last {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.bottom, 16)
            } else {
                // Selected Customer Layout (Android selected state)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Seçili Müşteri:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.selectedCustomer!)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Müşteri seçildi")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        Button("Değiştir") {
                            clearCustomerSelection()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Android Image Upload Card
    private var androidImageUploadCard: some View {
        VStack(spacing: 16) {
            // Card Header
            HStack {
                Text("Resim Yükle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Upload Buttons (Android style)
            VStack(spacing: 12) {
                // Gallery Button
                Button(action: {
                    if viewModel.selectedCustomer == nil {
                        viewModel.showToast("Lütfen önce müşteri seçiniz")
                        return
                    }
                    showingImagePicker = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                        
                        Text("Galeriden Seç")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                
                // Camera Button
                Button(action: {
                    if viewModel.selectedCustomer == nil {
                        viewModel.showToast("Lütfen önce müşteri seçiniz")
                        return
                    }
                    checkCameraPermissionAndStart()
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                        
                        Text("Resim Çek")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                
                // Image Count Info (Android style)
                if !selectedImages.isEmpty {
                    HStack {
                        Image(systemName: "photo.stack")
                            .foregroundColor(.green)
                        Text("\(selectedImages.count) resim kaydedildi")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Android Selected Images Card
    private var androidSelectedImagesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Seçilen Resimler")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Tümünü Temizle") {
                    selectedImages.removeAll()
                    viewModel.showToast("Tüm resimler temizlendi")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Images Grid (Android GridView style)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                        
                        Button(action: {
                            selectedImages.remove(at: index)
                            viewModel.showToast("Resim kaldırıldı")
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .background(Color.white.clipShape(Circle()))
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Helper Methods (Android Compatible)
    
    private func selectCustomer(_ customer: String) {
        // Android behavior: hide search, show selected
        viewModel.selectedCustomer = customer
        viewModel.customerSearchText = ""
        viewModel.searchResults = []
        viewModel.showToast("Müşteri seçildi: \(customer)")
    }
    
    private func clearCustomerSelection() {
        // Android behavior: show search again, clear selected
        viewModel.selectedCustomer = nil
        viewModel.customerSearchText = ""
        viewModel.searchResults = []
        viewModel.showToast("Müşteri seçimi temizlendi")
    }
    
    private func handleSelectedImages(_ images: [UIImage]) {
        // Android directSaveImages() behavior - save immediately
        guard let customerName = viewModel.selectedCustomer else {
            viewModel.showToast("Müşteri seçilmemiş")
            return
        }
        
        saveImagesToDevice(images: images, customerName: customerName, source: "Galeri")
    }
    
    private func handleCapturedImage(_ image: UIImage) {
        // Android directSaveImage() behavior - save immediately
        guard let customerName = viewModel.selectedCustomer else {
            viewModel.showToast("Müşteri seçilmemiş")
            return
        }
        
        saveImagesToDevice(images: [image], customerName: customerName, source: "Kamera")
        cameraKey = UUID() // Force refresh camera
    }
    
    // Android uyumlu resim kaydetme (directSaveImages equivalent)
    private func saveImagesToDevice(images: [UIImage], customerName: String, source: String) {
        let totalImages = images.count
        var savedCount = 0
        
        for (index, image) in images.enumerated() {
            // iOS Documents/EnvantoBarkod/customerName/IMG_timestamp_index.jpg
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let appDirectory = documentsPath.appendingPathComponent("EnvantoBarkod")
            let customerDirectory = appDirectory.appendingPathComponent(customerName)
            
            // Create directory if needed
            try? FileManager.default.createDirectory(at: customerDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // Generate filename like Android: IMG_timestamp_index.jpg
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "IMG_\(timestamp)_\(index).jpg"
            let fileURL = customerDirectory.appendingPathComponent(fileName)
            
            // Save image
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                do {
                    try imageData.write(to: fileURL)
                    savedCount += 1
                    print("✅ Resim kaydedildi: \(fileURL.path)")
                    
                    // Add to selectedImages for preview (Android behavior)
                    selectedImages.append(image)
                    
                    // SQLite database'e kaydet (Android addBarkodResim equivalent)
                    let dbResult = SQLiteManager.shared.addBarkodResim(musteriAdi: customerName, resimYolu: fileURL.path, yukleyen: "iOS User")
                    
                    if dbResult > 0 {
                        print("✅ Database kaydı oluşturuldu: ID \(dbResult)")
                    } else {
                        print("❌ Database kaydı başarısız")
                    }
                    
                } catch {
                    print("❌ Resim kaydetme hatası: \(error.localizedDescription)")
                }
            }
        }
        
        // Android style toast message
        if savedCount > 0 {
            viewModel.showToast("\(source)'den \(savedCount)/\(totalImages) resim kaydedildi")
        } else {
            viewModel.showToast("Resim kaydetme başarısız")
        }
    }
    
    private func checkCameraPermissionAndStart() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authStatus {
        case .authorized:
            showingCameraView = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.showingCameraView = true
                    } else {
                        viewModel.showToast("Kamera izni gerekli")
                    }
                }
            }
        default:
            viewModel.showToast("Kamera izni gerekli - Ayarlardan izin verin")
        }
    }
    
    // MARK: - Customer Search Card
    private var customerSearchCard: some View {
        VStack(spacing: 0) {
            // Search Header
            HStack {
                Text("Müşteri Seçin")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Search TextField
            TextField("Müşteri adı yazın (en az 2 karakter)", text: $viewModel.customerSearchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, viewModel.searchResults.isEmpty ? 16 : 8)
                .onChange(of: viewModel.customerSearchText) { newValue in
                    viewModel.searchCustomers(query: newValue)
                }
            
            // Search Results
            if !viewModel.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.searchResults, id: \.self) { customer in
                            Button(action: {
                                selectCustomer(customer)
                            }) {
                                HStack {
                                    Text(customer)
                                        .foregroundColor(.primary)
                                        .font(.system(size: 16))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(UIColor.systemBackground))
                            }
                            
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Selected Customer Card
    private var selectedCustomerCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Seçili Müşteri")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.selectedCustomer ?? "")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button("Değiştir") {
                    clearCustomerSelection()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    BarcodeUploadView()
} 