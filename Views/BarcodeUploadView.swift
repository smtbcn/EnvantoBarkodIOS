import SwiftUI
import PhotosUI
import AVFoundation
import Combine
import MediaPlayer
import Foundation

// Gerçek kamera view implementasyonu (Android design benzeri)
struct CameraView: View {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraModel = CameraModel()
    @State private var showFlash = false
    
    var body: some View {
            ZStack {
            // Kamera preview (Full screen)
            CameraPreview(session: cameraModel.session)
                .ignoresSafeArea()
                .onTapGesture(coordinateSpace: .local) { location in
                    cameraModel.focusAt(point: location)
                }
            
            // Flash overlay (Çekim animasyonu)
            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .opacity(0.7)
                    .animation(.easeInOut(duration: 0.15), value: showFlash)
            }
            
            // Bottom Control Bar (Android style - 3 equal grids)
            VStack {
                Spacer()
                
                HStack {
                    // Sol Grid - Flash & Lens Buttons
                    HStack(spacing: 12) {
                        // Flash Button (48dp equivalent)
                        Group {
                            if cameraModel.captureDevice?.hasTorch == true {
                                Button(action: {
                                    cameraModel.toggleFlash()
                                }) {
                                    Image(systemName: cameraModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(cameraModel.isFlashOn ? .yellow : .white)
                                        .frame(width: 48, height: 48)
                                        .background(
                                            Circle()
                                                .fill(Color.black.opacity(0.5))
                                        )
                                }
                            } else {
                                // Flash yoksa boş alan
                                Spacer()
                                    .frame(width: 48, height: 48)
                            }
                        }
                        
                        // 🎯 Lens Switch Button (48dp equivalent)
                        if cameraModel.availableLensTypes.count > 1 {
                            Button(action: {
                                cameraModel.switchLens()
                            }) {
                                Text(cameraModel.currentLensType.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.5))
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity) // Equal grid weight
                    
                    // Orta Grid - Capture Button (100dp equivalent)
                    Button(action: {
                        capturePhoto()
                    }) {
                        ZStack {
                            // Ana capture button (Material Design style)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 100, height: 100)
                                .opacity(0.9)
                            
                            // Kamera ikonu (Android'deki gibi)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 35, weight: .medium))
                                .foregroundColor(.black)
                            
                            // Loading indicator
                            if cameraModel.isCapturing {
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 100, height: 100)
                                
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(1.2)
                            }
                        }
                    }
                    .scaleEffect(cameraModel.isCapturing ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: cameraModel.isCapturing)
                    .disabled(cameraModel.isCapturing)
                    .frame(maxWidth: .infinity) // Equal grid weight
                    
                    // Sağ Grid - Close Button (48dp equivalent)
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.8))
                            )
                    }
                    .frame(maxWidth: .infinity) // Equal grid weight
                }
                .padding(.horizontal, 12) // Android padding
                .padding(.bottom, 120)    // Android bottom margin (120dp)
            }
        }
        .background(Color.black) // Android siyah arkaplan
        .onAppear {
            cameraModel.startSession()
        }
        .onDisappear {
            cameraModel.stopSession()
        }
    }
    
    private func capturePhoto() {
        // Flash efekti (Android style)
        withAnimation(.easeInOut(duration: 0.15)) {
            showFlash = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showFlash = false
        }
        
        cameraModel.capturePhoto { image in
            if let image = image {
                DispatchQueue.main.async {
                    // Titreşim
                    AudioManager.shared.playVibration()
                    
                    // Haptic feedback (iOS native)
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    onImageCaptured(image)
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
    @Published var currentLensType: LensType = .wide // 🎯 init'te ayarlanacak
    
    private var photoOutput = AVCapturePhotoOutput()
    var captureDevice: AVCaptureDevice?
    private var photoCompletion: ((UIImage?) -> Void)?
    
    // YENİ: Orientation tracking için
    private var deviceOrientation: UIDeviceOrientation = .portrait
    private var orientationObserver: NSObjectProtocol?
    
    // 🎯 Lens tipleri
    enum LensType {
        case ultraWide  // 0.5x
        case wide       // 1x
        
        var deviceType: AVCaptureDevice.DeviceType {
            switch self {
            case .ultraWide:
                return .builtInUltraWideCamera
            case .wide:
                return .builtInWideAngleCamera
            }
        }
        
        var displayName: String {
            switch self {
            case .ultraWide:
                return "0.5×"
            case .wide:
                return "1×"
            }
        }
    }
    
    // 🎯 Available lens types based on device capability
    var availableLensTypes: [LensType] {
        var types: [LensType] = [.wide] // Her cihazda var
        
        // Ultra-wide lens kontrolü
        if AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil {
            types.insert(.ultraWide, at: 0) // Başa ekle
        }
        
        return types
    }
    
    override init() {
        super.init()
        // 🎯 Ultra-wide varsa default olarak ayarla, yoksa wide kullan
        if availableLensTypes.contains(.ultraWide) {
            currentLensType = .ultraWide
        } else {
            currentLensType = .wide
        }
        setupCamera()
        setupOrientationTracking()
    }
    
    deinit {
        // Orientation observer'ı temizle
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Device orientation notifications'ı durdur
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    private func setupCamera() {
        setupCameraForLens(currentLensType)
    }
    
    // 🎯 Lens değiştirme fonksiyonu
    func switchLens() {
        let availableTypes = availableLensTypes
        guard availableTypes.count > 1 else { return }
        
        if let currentIndex = availableTypes.firstIndex(of: currentLensType) {
            let nextIndex = (currentIndex + 1) % availableTypes.count
            currentLensType = availableTypes[nextIndex]
            setupCameraForLens(currentLensType)
        }
    }
    
    // 🎯 Belirli lens için kamera kurulumu
    private func setupCameraForLens(_ lensType: LensType) {
        session.beginConfiguration()
        
        // Eski input'ları kaldır
        session.inputs.forEach { session.removeInput($0) }
        
        // Yeni kamera cihazını seç
        guard let device = AVCaptureDevice.default(lensType.deviceType, for: .video, position: .back) else {
            // Ultra-wide yoksa wide'a geri dön
            if lensType == .ultraWide {
                setupCameraForLens(.wide)
                return
            }
            session.commitConfiguration()
            return
        }
        
        captureDevice = device
        
        // Torch durumunu kontrol et ve logla
        
        
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
            // Kamera ayarlama hatası
        }
        
        session.commitConfiguration()
        
        // YENİ: Kamera kurulumu sonrası orientation'ı güncelle
        updateCameraOrientation()
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
        
        // YENİ: Device orientation'a göre video orientation ayarla
        if let connection = photoOutput.connection(with: .video) {
            connection.videoOrientation = getVideoOrientation(from: deviceOrientation)
            print("📷 [CameraModel] Photo capture orientation: \(connection.videoOrientation) (device: \(getOrientationName(deviceOrientation)))")
        }
        
        // Sistem kamera sesini tamamen kapat - tüm ayarları devre dışı bırak
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .speed
            settings.isAutoStillImageStabilizationEnabled = false
            settings.isAutoRedEyeReductionEnabled = false
        }
        
        // Ses çıkışını tamamen kapat
        settings.isHighResolutionPhotoEnabled = false
        
        // Flash ayarı - hem photo flash hem torch kontrol et
        if let device = captureDevice {
            // Photo flash varsa onu kullan
            if device.hasFlash {
                settings.flashMode = isFlashOn ? .on : .off
    
            } 
            // Torch açıksa ve photo flash yoksa, torch'u geçici olarak güçlendir
            else if device.hasTorch && isFlashOn {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = .on
                    device.unlockForConfiguration()
    
                } catch {
    
                }
            }
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Orientation Tracking
    
    private func setupOrientationTracking() {
        // Device orientation notifications'ı etkinleştir
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // Device orientation değişikliklerini dinle
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleOrientationChange()
        }
        
        // İlk orientation değerini al
        updateDeviceOrientation()
    }
    
    private func handleOrientationChange() {
        updateDeviceOrientation()
        updateCameraOrientation()
    }
    
    private func updateDeviceOrientation() {
        let newOrientation = UIDevice.current.orientation
        
        print("🔍 [CameraModel] Raw device orientation: \(getOrientationName(newOrientation))")
        
        // Sadece valid orientation'ları kabul et
        if newOrientation != .unknown && newOrientation != .faceUp && newOrientation != .faceDown {
            deviceOrientation = newOrientation
            print("📱 [CameraModel] Device orientation güncellendi: \(getOrientationName(deviceOrientation))")
        } else {
            print("⚠️ [CameraModel] Invalid orientation ignored, keeping: \(getOrientationName(deviceOrientation))")
        }
    }
    
    private func updateCameraOrientation() {
        guard let connection = photoOutput.connection(with: .video) else { return }
        
        // Video orientation'ı güncelle
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = getVideoOrientation(from: deviceOrientation)
            print("📷 [CameraModel] Camera orientation güncellendi: \(connection.videoOrientation)")
        }
    }
    
    private func getOrientationName(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait: return "PORTRAIT (0°)"
        case .landscapeLeft: return "LANDSCAPE_LEFT (90°)"
        case .portraitUpsideDown: return "PORTRAIT_UPSIDE_DOWN (180°)"
        case .landscapeRight: return "LANDSCAPE_RIGHT (270°)"
        default: return "UNKNOWN"
        }
    }
    
    // Android mantığı: Device orientation'a göre target format belirle
    private func shouldTargetBePortrait(deviceOrientation: UIDeviceOrientation) -> Bool {
        switch deviceOrientation {
        case .portrait, .portraitUpsideDown:
            return true  // Portrait orientations → Portrait resim
        case .landscapeLeft, .landscapeRight:
            return false // Landscape orientations → Landscape resim
        default:
            return true  // Unknown → Default portrait
        }
    }

    // YENİ: Device orientation'dan video orientation'a çevirme
    private func getVideoOrientation(from deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch deviceOrientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return .portrait
        }
    }
    
    func toggleFlash() {
        
        // Flash/Torch varlığını kontrol et
        guard let device = captureDevice else {
            return
        }
        
        guard device.hasTorch else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if isFlashOn {
                device.torchMode = .off
            } else {
                device.torchMode = .on
            }
            
            device.unlockForConfiguration()
            
            // UI state'i güncelle
            DispatchQueue.main.async {
                self.isFlashOn.toggle()
            }
            
        } catch {
        }
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
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { 
            isCapturing = false 
        }
        
        if error != nil {
            photoCompletion?(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            photoCompletion?(nil)
            return
        }
        
        // YENİ: Geçici dosya oluştur ve orientation düzeltmesi uygula
        let tempURL = createTempImageFile()
        
        do {
            try imageData.write(to: tempURL)
            
            // Arka planda orientation düzeltmesi yap
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.processImageOrientation(at: tempURL.path)
            }
            
        } catch {
            print("❌ Resim kaydetme hatası: \(error)")
            photoCompletion?(nil)
        }
    }
    
    private func createTempImageFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "temp_camera_\(UUID().uuidString).jpg"
        return tempDir.appendingPathComponent(fileName)
    }
    
    private func processImageOrientation(at imagePath: String) {
        print("🔄 [CameraModel] Resim orientation işleniyor: \(imagePath)")
        
        // Orijinal resim boyutlarını kontrol et
        if let originalImage = UIImage(contentsOfFile: imagePath) {
            print("📐 [CameraModel] Orijinal resim boyutları: \(originalImage.size.width)x\(originalImage.size.height)")
        }
        
        // ImageOrientationUtils'daki Android mantığını kullan
        let fixedPath = ImageOrientationUtils.fixImageOrientationWithDeviceOrientation(
            imagePath: imagePath, 
            deviceOrientation: deviceOrientation
        )
        
        // Ana thread'de sonucu döndür
        DispatchQueue.main.async { [weak self] in
            if let image = UIImage(contentsOfFile: fixedPath) {
                print("✅ [CameraModel] Orientation düzeltmesi tamamlandı, resim callback'e gönderiliyor")
                self?.photoCompletion?(image)
            } else {
                print("❌ [CameraModel] Final resim yüklenemedi")
                self?.photoCompletion?(nil)
            }
        }
    }
    

    
    private func applyManualRotation(imagePath: String) {
        guard let image = UIImage(contentsOfFile: imagePath) else { return }
        
        let imageSize = image.size
        let isImageLandscape = imageSize.width > imageSize.height
        
        print("📐 [CameraModel] Resim boyutları: \(imageSize.width)x\(imageSize.height) (landscape: \(isImageLandscape))")
        print("� [CaimeraModel] Device orientation: \(getOrientationName(deviceOrientation))")
        
        var shouldRotate = false
        var rotationAngle: CGFloat = 0
        
        switch deviceOrientation {
        case .portrait:
            // Cihaz portrait, resim landscape ise 90° döndür
            if isImageLandscape {
                shouldRotate = true
                rotationAngle = 90
            }
        case .landscapeLeft:
            // Cihaz landscape left, resim portrait ise 270° döndür
            if !isImageLandscape {
                shouldRotate = true
                rotationAngle = 270
            }
        case .portraitUpsideDown:
            // Cihaz upside down, resim landscape ise 270° döndür
            if isImageLandscape {
                shouldRotate = true
                rotationAngle = 270
            }
        case .landscapeRight:
            // Cihaz landscape right, resim portrait ise 90° döndür
            if !isImageLandscape {
                shouldRotate = true
                rotationAngle = 90
            }
        default:
            break
        }
        
        if shouldRotate && rotationAngle != 0 {
            print("🔄 [CameraModel] Manuel rotation uygulanıyor: \(rotationAngle)°")
            
            let rotatedImage = ImageOrientationUtils.rotateImage(image, angle: rotationAngle)
            
            // Döndürülmüş resmi kaydet
            if let imageData = rotatedImage.jpegData(compressionQuality: 0.9) {
                do {
                    try imageData.write(to: URL(fileURLWithPath: imagePath))
                    print("✅ [CameraModel] Manuel rotation başarıyla uygulandı: \(rotationAngle)°")
                    
                    // Final resim boyutlarını kontrol et
                    if let finalImage = UIImage(contentsOfFile: imagePath) {
                        print("📐 [CameraModel] Final resim boyutları: \(finalImage.size.width)x\(finalImage.size.height)")
                    }
                } catch {
                    print("❌ [CameraModel] Manuel rotation kaydetme hatası: \(error)")
                }
            }
        } else {
            print("ℹ️ [CameraModel] Manuel rotation gerekmiyor, resim zaten doğru yönde")
        }
    }
    
    // YENİ: Android mantığı ile manuel rotation
    private func applyManualRotationNew(imagePath: String) {
        print("🔧 [CameraModel] applyManualRotation başladı (Android mantığı)")
        
        guard let image = UIImage(contentsOfFile: imagePath) else { 
            print("❌ [CameraModel] Resim dosyası yüklenemedi: \(imagePath)")
            return 
        }
        
        let imageSize = image.size
        print("📐 [CameraModel] Resim boyutları: \(imageSize.width)x\(imageSize.height)")
        print("📱 [CameraModel] Device orientation: \(getOrientationName(deviceOrientation))")
        
        // Android mantığı: Device orientation'a göre target format belirle
        let targetShouldBePortrait = shouldTargetBePortrait(deviceOrientation: deviceOrientation)
        let currentIsPortrait = imageSize.height > imageSize.width
        
        print("🎯 [CameraModel] Target format: \(targetShouldBePortrait ? "PORTRAIT" : "LANDSCAPE")")
        print("📐 [CameraModel] Current format: \(currentIsPortrait ? "PORTRAIT" : "LANDSCAPE")")
        
        var rotationAngle: CGFloat = 0
        
        if targetShouldBePortrait && !currentIsPortrait {
            // Target portrait ama current landscape → 90° döndür
            rotationAngle = 90
            print("🔄 [CameraModel] Landscape → Portrait: 90° rotation")
        } else if !targetShouldBePortrait && currentIsPortrait {
            // Target landscape ama current portrait → 270° döndür  
            rotationAngle = 270
            print("🔄 [CameraModel] Portrait → Landscape: 270° rotation")
        } else {
            print("ℹ️ [CameraModel] Format zaten doğru, rotation gerekmiyor")
            return
        }
        
        // Rotation uygula
        print("🔄 [CameraModel] Manuel rotation uygulanıyor: \(rotationAngle)°")
        
        let rotatedImage = ImageOrientationUtils.rotateImage(image, angle: rotationAngle)
        
        // Döndürülmüş resmi kaydet
        if let imageData = rotatedImage.jpegData(compressionQuality: 0.9) {
            do {
                try imageData.write(to: URL(fileURLWithPath: imagePath))
                print("✅ [CameraModel] Manuel rotation başarıyla uygulandı: \(rotationAngle)°")
                
                // Final resim boyutlarını kontrol et
                if let finalImage = UIImage(contentsOfFile: imagePath) {
                    print("📐 [CameraModel] Final resim boyutları: \(finalImage.size.width)x\(finalImage.size.height)")
                }
            } catch {
                print("❌ [CameraModel] Manuel rotation kaydetme hatası: \(error)")
            }
        }
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
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var expandedCustomerId: String? = nil // Accordion state
    @State private var showingDeleteCustomerAlert = false
    @State private var customerToDelete: String = ""
    

    
    // 🎯 iOS 15+ Focus State for TextField
    @available(iOS 15.0, *)
    @FocusState private var isSearchFieldFocused: Bool
    
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

            .alert("Toplu Resim Silme", isPresented: $showingDeleteCustomerAlert) {
                Button("İptal", role: .cancel) { }
                Button("Sil", role: .destructive) {
                    // Müşteri klasörünü sil
                    viewModel.deleteCustomerFolder(customerToDelete)
                    // Eğer silinen müşteri açıksa accordion'u kapat
                    if expandedCustomerId == customerToDelete {
                        expandedCustomerId = nil
                    }
                    customerToDelete = ""
                }
            } message: {
                Text("'\(customerToDelete)' müşterisine ait SADECE YÜKLENMİŞ resimler silinecek.\n\n⚠️ Yükleme bekleyen resimler korunacak.\n\nBu işlem geri alınamaz.")
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
        .onTapGesture {
            // Background'a tap yapıldığında focus'u kaldır
            if #available(iOS 15.0, *) {
                isSearchFieldFocused = false
            }
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
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                Group {
                    if #available(iOS 15.0, *) {
                        // iOS 15+ gelişmiş özellikler
                        TextField("Müşteri ara...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                            .focused($isSearchFieldFocused)
                            .onSubmit {
                                if viewModel.searchText.count >= 2 {
                                    viewModel.searchCustomers()
                                }
                            }
                            .onTapGesture {
                                // Manuel focus tetikle
                                isSearchFieldFocused = true
                            }
                    } else {
                        // iOS 14 fallback
                        TextField("Müşteri ara...", text: $viewModel.searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16))
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                }
                .onChange(of: viewModel.searchText) { newValue in
                    if newValue.count >= 2 {
                        viewModel.searchCustomers()
                    } else if newValue.isEmpty {
                        viewModel.customers = []
                        viewModel.showDropdown = false
                    }
                }
                
                if viewModel.isSearching {
                    if #available(iOS 15.0, *) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
            }
            .padding(.horizontal, 16)  // Horizontal padding artırıldı
            .padding(.vertical, 16)    // Vertical padding artırıldı (yükseklik için)
            .background(
                RoundedRectangle(cornerRadius: 12)  // Corner radius artırıldı
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)  // Subtle shadow
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
                        
                        // 🎯 iOS 15+ için focus'u kaldır
                        if #available(iOS 15.0, *) {
                            isSearchFieldFocused = false
                        }
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
    let group: BarcodeImageGroup
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
                            AndroidImageRow(image: image, onDelete: {
                                onDeleteImage(image)
                            }, onViewImage: {
                                // 🎯 Resim önizleme - QuickLook ile
                                previewImage(imagePath: image.imagePath)
                            })
                            
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
    
    // 🎯 Basit resim önizleme - Sheet ile
    private func previewImage(imagePath: String) {
        guard FileManager.default.fileExists(atPath: imagePath) else {
            print("⚠️ Resim dosyası bulunamadı: \(imagePath)")
            return
        }
        
        print("📁 Resim yolu: \(imagePath)")
        
        // Basit sheet ile resim göster
        let url = URL(fileURLWithPath: imagePath)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let imageViewController = SimpleImageViewController(imageURL: url)
            let navController = UINavigationController(rootViewController: imageViewController)
            rootVC.present(navController, animated: true)
        }
    }
}

// MARK: - Android Image Row (Resim Yükleme'deki gibi)
struct AndroidImageRow: View {
    let image: SavedImage
    let onDelete: () -> Void
    let onViewImage: () -> Void // 🎯 Resim önizleme callback'i
    
    var body: some View {
        HStack(spacing: 12) {
            // Sol: Resim preview (Android like) - TIKLANABILIR
            Button(action: {
                onViewImage() // 🎯 Resim önizleme aç
            }) {
                Group {
                    if image.fileExists {
                        // Dosya mevcut - normal AsyncImage
                        AsyncImage(url: URL(fileURLWithPath: image.imagePath)) { phase in
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
                    } else {
                        // Dosya mevcut değil - error göster
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                            .frame(width: 50, height: 50)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Orta: Dosya bilgileri (Android like)
            VStack(alignment: .leading, spacing: 4) {
                // Dosya adı (sadece filename)
                Text(extractFileName(from: image.imagePath))
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
                    
                    Text("Yükleyen: \(image.yukleyen)")
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
    
    
    private func getUploadStatusIcon() -> String {
        // Dosya yoksa farklı ikon göster
        if !image.fileExists {
            return "doc.questionmark"
        }
        // Database'den upload durumu
        return image.isUploaded ? "checkmark.circle.fill" : "clock.circle"
    }
    
    private func getUploadStatusColor() -> Color {
        // Dosya yoksa turuncu
        if !image.fileExists {
            return .orange
        }
        return image.isUploaded ? .green : .orange
    }
    
    private func getUploadStatusText() -> String {
        // Dosya yoksa farklı mesaj
        if !image.fileExists {
            return "DOSYA BULUNAMADI"
        }
        return image.isUploaded ? "SUNUCUYA YÜKLENDİ" : "YÜKLEME BEKLİYOR"
    }
}

// MARK: - Saved Image Card (Legacy - artık kullanılmıyor)
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

// MARK: - Simple Image View Controller (Resim önizleme için)
class SimpleImageViewController: UIViewController, UIScrollViewDelegate {
    private let imageURL: URL
    private var scrollView: UIScrollView!
    private var imageView: UIImageView!
    
    init(imageURL: URL) {
        self.imageURL = imageURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        title = "Resim Önizleme"
        
        // Navigation items
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Kapat", 
            style: .done, 
            target: self, 
            action: #selector(closePressed)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action, 
            target: self, 
            action: #selector(sharePressed)
        )
        
        setupScrollView()
        loadImage()
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
    }
    
    private func loadImage() {
        if let imageData = try? Data(contentsOf: imageURL),
           let image = UIImage(data: imageData) {
            imageView.image = image
        }
    }
    
    @objc private func closePressed() {
        dismiss(animated: true)
    }
    
    @objc private func sharePressed() {
        let activityVC = UIActivityViewController(activityItems: [imageURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(activityVC, animated: true)
    }
    
    // MARK: - UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

#Preview {
    BarcodeUploadView()
} 
                  
