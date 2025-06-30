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
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(message)
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(30)
            .background(Color.black.opacity(0.8))
            .cornerRadius(15)
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
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.setTitle("📷", for: .normal)
        captureButton.titleLabel?.font = UIFont.systemFont(ofSize: 30)
        captureButton.addTarget(self, action: #selector(captureImage), for: .touchUpInside)
        
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

// MARK: - Main View

struct BarcodeUploadView: View {
    @StateObject private var viewModel = BarcodeUploadViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingCameraView = false
    @State private var showingActionSheet = false
    @State private var cameraKey = UUID()
    
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
            .id(cameraKey)
        }
        .overlay(
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
                
                Text("").frame(width: 50)
            }
            
            Divider()
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 20) {
            customerSelectionView
            
            if viewModel.selectedCustomer != nil {
                imageUploadView
            }
            
            Spacer()
        }
    }
    
    private var customerSelectionView: some View {
        VStack(spacing: 15) {
            if viewModel.selectedCustomer == nil {
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
        VStack(spacing: 15) {
            Text("Resim Yükle")
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: {
                showingActionSheet = true
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Resim Seç")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            if !selectedImages.isEmpty {
                Text("\(selectedImages.count) resim seçildi")
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func selectCustomer(_ customer: String) {
        viewModel.selectedCustomer = customer
        viewModel.customerSearchText = ""
        viewModel.searchResults = []
    }
    
    private func clearCustomerSelection() {
        viewModel.selectedCustomer = nil
        viewModel.customerSearchText = ""
        viewModel.searchResults = []
    }
    
    private func handleSelectedImages(_ images: [UIImage]) {
        selectedImages = images
        viewModel.showToast("Gallery: \(images.count) resim seçildi")
    }
    
    private func handleCapturedImage(_ image: UIImage) {
        selectedImages.append(image)
        viewModel.showToast("Camera: Resim çekildi (\(selectedImages.count) toplam)")
        cameraKey = UUID() // Force refresh camera
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
            viewModel.showToast("Kamera izni gerekli")
        }
    }
}

#Preview {
    BarcodeUploadView()
} 