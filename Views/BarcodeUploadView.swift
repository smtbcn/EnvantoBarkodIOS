import SwiftUI
import UIKit
import Photos
import AVFoundation
import PhotosUI

struct BarcodeUploadView: View {
    @StateObject private var viewModel = BarcodeUploadViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingCameraView = false
    @State private var showingActionSheet = false
    @State private var cameraKey = UUID() // Force camera refresh
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gray.opacity(0.1).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    headerView
                    
                    if viewModel.isLoading {
                        LoadingOverlay(message: "Device authorization in progress...")
                    } else if viewModel.isAuthSuccess {
                        contentView
                    }
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.checkDeviceAuthorization()
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Resim Seç"),
                message: Text("Nereden resim seçmek istiyorsunuz?"),
                buttons: [
                    .default(Text("📷 Kamera")) {
                        checkCameraPermissionAndStart()
                    },
                    .default(Text("🖼️ Galeri (Çoklu)")) {
                        sourceType = .photoLibrary
                        showingImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            MultipleImagePicker(
                selectedImages: $selectedImages,
                onImagesSelected: { images in
                    handleSelectedImages(images)
                }
            )
        }
        .sheet(isPresented: $showingCameraView) {
            ContinuousCameraView(
                onImageCaptured: { image in
                    handleCapturedImage(image)
                },
                onDismiss: {
                    showingCameraView = false
                }
            )
            .id(cameraKey) // Force refresh when camera reopens
        }
        .overlay(
            // Toast notification
            ToastView(message: viewModel.toastMessage, isShowing: $viewModel.showingToast)
        )
    }
    
    private var headerView: some View {
        VStack(spacing: 10) {
            HStack {
                Button("< Geri") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("Barkod Yükle")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Balance space
                Text("").frame(width: 50)
            }
            
            Divider()
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 20) {
            // Customer Selection Section
            customerSelectionView
            
            // Image Upload Section (only show when customer is selected)
            if viewModel.selectedCustomer != nil {
                imageUploadView
            }
            
            Spacer()
        }
    }
    
    private var customerSelectionView: some View {
        VStack(spacing: 15) {
            if viewModel.selectedCustomer == nil {
                // Customer Search Layout
                VStack(alignment: .leading, spacing: 10) {
                    Text("Müşteri Seç")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        TextField("Müşteri ara...", text: $viewModel.customerSearchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: viewModel.customerSearchText) { newValue in
                                if newValue.count >= 2 {
                                    viewModel.searchCustomers(query: newValue)
                                }
                            }
                        
                        if viewModel.isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    // Customer dropdown list
                    if !viewModel.searchResults.isEmpty {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(viewModel.searchResults, id: \.self) { customer in
                                    Button(action: {
                                        selectCustomer(customer)
                                    }) {
                                        HStack {
                                            Text(customer)
                                                .foregroundColor(.primary)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 16)
                                            Spacer()
                                        }
                                    }
                                    .background(Color.white)
                                    .overlay(
                                        Rectangle()
                                            .frame(height: 1)
                                            .foregroundColor(.gray.opacity(0.3)),
                                        alignment: .bottom
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(radius: 3)
                    }
                }
            } else {
                // Selected Customer Layout
                VStack(alignment: .leading, spacing: 10) {
                    Text("Seçili Müşteri")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text(viewModel.selectedCustomer!)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Button("Değiştir") {
                            clearCustomerSelection()
                        }
                        .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var imageUploadView: some View {
        VStack(spacing: 20) {
            // Upload buttons
            HStack(spacing: 20) {
                Button(action: {
                    showingActionSheet = true
                }) {
                    VStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                        Text("Resim Ekle")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Button(action: {
                    checkCameraPermissionAndStart()
                }) {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                        Text("Kamera")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Upload progress
            if viewModel.isUploading {
                VStack(spacing: 10) {
                    ProgressView(value: viewModel.uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text(viewModel.uploadMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Selected images preview
            if !selectedImages.isEmpty {
                Text("Seçilen Resimler: \(selectedImages.count)")
                    .font(.headline)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<selectedImages.count, id: \.self) { index in
                            Image(uiImage: selectedImages[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                                .clipped()
                                .overlay(
                                    Button(action: {
                                        selectedImages.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                    }
                                    .offset(x: 30, y: -30),
                                    alignment: .topTrailing
                                )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func selectCustomer(_ customer: String) {
        viewModel.selectedCustomer = customer
        viewModel.customerSearchText = ""
        viewModel.searchResults = []
        
        // Show toast
        viewModel.showToast("Müşteri seçildi: \(customer)")
    }
    
    private func clearCustomerSelection() {
        viewModel.selectedCustomer = nil
        viewModel.customerSearchText = ""
        viewModel.searchResults = []
        selectedImages = []
    }
    
    private func checkCameraPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startContinuousCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        startContinuousCamera()
                    } else {
                        viewModel.showToast("Kamera izni reddedildi")
                    }
                }
            }
        case .denied, .restricted:
            viewModel.showToast("Kamera izni gerekli. Ayarlar'dan etkinleştirin.")
        @unknown default:
            break
        }
    }
    
    private func startContinuousCamera() {
        cameraKey = UUID() // Force refresh
        showingCameraView = true
    }
    
    private func handleSelectedImages(_ images: [UIImage]) {
        // Save images to customer directory
        saveImagesToDirectory(images)
    }
    
    private func handleCapturedImage(_ image: UIImage) {
        // Save single image and restart camera
        saveImagesToDirectory([image])
        
        // Small delay then restart camera
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startContinuousCamera()
        }
    }
    
    private func saveImagesToDirectory(_ images: [UIImage]) {
        guard let customerName = viewModel.selectedCustomer else { return }
        
        viewModel.isUploading = true
        viewModel.uploadProgress = 0.0
        viewModel.uploadMessage = "Resimler kaydediliyor..."
        
        // Create customer directory in app documents
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let envantoDir = documentsPath.appendingPathComponent("EnvantoBarkod")
        let customerDir = envantoDir.appendingPathComponent(customerName)
        
        do {
            try FileManager.default.createDirectory(at: customerDir, withIntermediateDirectories: true, attributes: nil)
            print("📁 Customer directory created: \(customerDir.path)")
        } catch {
            print("❌ Directory creation error: \(error)")
            viewModel.showToast("Klasör oluşturma hatası")
            return
        }
        
        // Save images
        DispatchQueue.global(qos: .userInitiated).async {
            var successCount = 0
            let totalCount = images.count
            
            for (index, image) in images.enumerated() {
                let fileName = "IMG_\(Date().timeIntervalSince1970)_\(index).jpg"
                let filePath = customerDir.appendingPathComponent(fileName)
                
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    do {
                        try imageData.write(to: filePath)
                        successCount += 1
                        print("✅ Image saved: \(filePath.lastPathComponent)")
                    } catch {
                        print("❌ Image save error: \(error)")
                    }
                }
                
                // Update progress
                DispatchQueue.main.async {
                    viewModel.uploadProgress = Double(index + 1) / Double(totalCount)
                    viewModel.uploadMessage = "\(index + 1)/\(totalCount) resim kaydedildi"
                }
            }
            
            DispatchQueue.main.async {
                viewModel.isUploading = false
                
                if successCount == totalCount {
                    viewModel.showToast("✅ \(successCount) resim başarıyla kaydedildi")
                    selectedImages.append(contentsOf: images)
                } else {
                    viewModel.showToast("⚠️ \(successCount)/\(totalCount) resim kaydedildi")
                }
            }
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Multiple Image Picker (iOS 16+)

struct MultipleImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    var onImagesSelected: ([UIImage]) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // 0 = unlimited selection
        config.filter = .images
        config.preferredAssetRepresentationMode = .current
        
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
            
            guard !results.isEmpty else {
                return
            }
            
            var images: [UIImage] = []
            let group = DispatchGroup()
            
            for result in results {
                group.enter()
                
                result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                    defer { group.leave() }
                    
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            images.append(image)
                        }
                    } else {
                        print("❌ Failed to load image: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
            
            group.notify(queue: .main) {
                print("📸 Loaded \(images.count)/\(results.count) images from gallery")
                self.parent.onImagesSelected(images)
            }
        }
    }
}

// MARK: - Continuous Camera View

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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
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
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
    }
    
    private func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(videoPreviewLayer)
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Capture button
        let captureButton = UIButton(type: .system)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.setTitle("📷", for: .normal)
        captureButton.titleLabel?.font = UIFont.systemFont(ofSize: 30)
        captureButton.addTarget(self, action: #selector(captureImage), for: .touchUpInside)
        
        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 20
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeCamera), for: .touchUpInside)
        
        view.addSubview(captureButton)
        view.addSubview(closeButton)
        
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
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

// MARK: - Toast View

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            if isShowing && !message.isEmpty {
                Text(message)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(25)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.3), value: isShowing)
                    .padding(.bottom, 100)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    BarcodeUploadView()
} 