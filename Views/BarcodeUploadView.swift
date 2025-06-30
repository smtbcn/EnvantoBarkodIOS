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
    @State private var showingCustomerSearch = false
    @State private var showingImageOptions = false
    @State private var showingSavedImages = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Müşteri Seçimi
                customerSelectionSection
                
                // Kayıtlı Resimler
                if !viewModel.selectedCustomerImages.isEmpty {
                    savedImagesSection
                }
                
                // Resim Yükleme Seçenekleri
                imageUploadSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Barkod Yükleme")
            .navigationBarTitleDisplayMode(.inline)
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
            .overlay {
                if viewModel.isLoading {
                    LoadingOverlay(message: "Yükleniyor...")
                }
                
                ToastView(message: viewModel.toastMessage, isShowing: $viewModel.showingToast)
            }
        }
        .onAppear {
            viewModel.checkDeviceAuthorization()
        }
    }
    
    // MARK: - UI Components
    
    private var customerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Müşteri Seçimi")
                .font(.headline)
            
            HStack {
                if let selectedCustomer = viewModel.selectedCustomer {
                    Text(selectedCustomer)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.selectedCustomer = nil
                        viewModel.selectedCustomerImages = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                } else {
                    Button(action: {
                        showingCustomerSearch = true
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Müşteri Ara")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingCustomerSearch) {
                customerSearchSheet
            }
        }
    }
    
    private var savedImagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Kayıtlı Resimler")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.selectedCustomerImages.count) resim")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.selectedCustomerImages) { resim in
                        savedImageCell(resim)
                    }
                }
            }
            .frame(height: 120)
        }
    }
    
    private func savedImageCell(_ resim: BarkodResim) -> some View {
        VStack {
            if let image = loadImage(from: resim.resimYolu) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
                    .overlay(
                        Group {
                            if resim.yuklendi {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .padding(4)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .padding(4)
                            }
                        },
                        alignment: .topTrailing
                    )
            } else {
                Color.gray
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white)
                    )
            }
            
            Text(resim.formattedTarih)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private var imageUploadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resim Yükleme")
                .font(.headline)
            
            HStack(spacing: 15) {
                Button(action: {
                    if viewModel.selectedCustomer == nil {
                        viewModel.showToast("Lütfen önce müşteri seçiniz")
                        return
                    }
                    showingCameraView = true
                }) {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                        Text("Kamera")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.blue)
                }
                
                Button(action: {
                    if viewModel.selectedCustomer == nil {
                        viewModel.showToast("Lütfen önce müşteri seçiniz")
                        return
                    }
                    showingImagePicker = true
                }) {
                    VStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 24))
                        Text("Galeri")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.blue)
                }
            }
            .disabled(viewModel.selectedCustomer == nil)
            .opacity(viewModel.selectedCustomer == nil ? 0.5 : 1)
        }
    }
    
    private var customerSearchSheet: some View {
        NavigationView {
            VStack {
                SearchBar(text: $viewModel.customerSearchText)
                    .padding(.horizontal)
                
                if viewModel.isSearching {
                    ProgressView()
                        .padding()
                } else {
                    List(viewModel.searchResults, id: \.self) { customer in
                        Button(action: {
                            viewModel.selectCustomer(customer)
                            showingCustomerSearch = false
                        }) {
                            Text(customer)
                        }
                    }
                }
            }
            .navigationTitle("Müşteri Ara")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Kapat") {
                showingCustomerSearch = false
            })
        }
        .onChange(of: viewModel.customerSearchText) { newValue in
            viewModel.searchCustomers(query: newValue)
        }
    }
    
    // MARK: - Helper Functions
    
    private func handleSelectedImages(_ images: [UIImage]) {
        guard let selectedCustomer = viewModel.selectedCustomer else { return }
        
        for image in images {
            if let imagePath = saveImageToDocuments(image, for: selectedCustomer) {
                viewModel.saveImage(imagePath: imagePath)
            }
        }
    }
    
    private func handleCapturedImage(_ image: UIImage) {
        guard let selectedCustomer = viewModel.selectedCustomer else { return }
        
        if let imagePath = saveImageToDocuments(image, for: selectedCustomer) {
            viewModel.saveImage(imagePath: imagePath)
        }
        
        cameraKey = UUID() // Force refresh camera
    }
    
    private func saveImageToDocuments(_ image: UIImage, for customer: String) -> String? {
        let fileName = "\(customer)_\(UUID().uuidString).jpg"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            do {
                try imageData.write(to: fileURL)
                return fileURL.path
            } catch {
                print("Error saving image: \(error)")
                return nil
            }
        }
        return nil
    }
    
    private func loadImage(from path: String) -> UIImage? {
        return UIImage(contentsOfFile: path)
    }
}

// MARK: - SearchBar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Müşteri adı girin...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

#Preview {
    BarcodeUploadView()
} 