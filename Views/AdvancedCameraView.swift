import SwiftUI
import AVFoundation

// MARK: - Advanced Camera View with Professional Features
struct AdvancedCameraView: View {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraService = AdvancedCameraService()
    
    // UI State
    @State private var showFlash = false
    @State private var isFlashOn = false
    @State private var showStabilizationIndicator = false
    @State private var showZoomControls = false
    @State private var tempZoomFactor: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Camera Preview (Full screen)
            AdvancedCameraPreview(session: cameraService.session)
                .ignoresSafeArea()
                .onTapGesture(coordinateSpace: .local) { location in
                    let normalizedPoint = CGPoint(
                        x: location.x / UIScreen.main.bounds.width,
                        y: location.y / UIScreen.main.bounds.height
                    )
                    cameraService.focusAt(point: normalizedPoint)
                    showFocusAnimation(at: location)
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            tempZoomFactor = max(1.0, min(cameraService.currentZoomFactor * value, cameraService.maxZoomFactor))
                            showZoomControls = true
                        }
                        .onEnded { _ in
                            cameraService.setZoomFactor(tempZoomFactor)
                            hideZoomControlsAfterDelay()
                        }
                )
            
            // Flash overlay animation
            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 0.15), value: showFlash)
            }
            
            // Stabilization indicator
            if showStabilizationIndicator {
                stabilizationIndicator
            }
            
            // Zoom controls (show when zooming)
            if showZoomControls {
                zoomIndicator
            }
            
            // Error message
            if let errorMessage = cameraService.errorMessage {
                errorOverlay(message: errorMessage)
            }
            
            // Main camera controls
            cameraControlsOverlay
        }
        .background(Color.black)
        .onAppear {
            cameraService.startSession()
        }
        .onDisappear {
            cameraService.stopSession()
        }
        .onChange(of: cameraService.currentZoomFactor) { newValue in
            tempZoomFactor = newValue
        }
    }
    
    // MARK: - Camera Controls Overlay
    private var cameraControlsOverlay: some View {
        VStack {
            // Top controls
            topControlsBar
            
            Spacer()
            
            // Bottom controls
            bottomControlsBar
        }
    }
    
    // MARK: - Top Controls Bar
    private var topControlsBar: some View {
        HStack {
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                    )
            }
            
            Spacer()
            
            // Camera type switcher (if ultra-wide available)
            if cameraService.isUltraWideAvailable {
                cameraTypeSwitcher
            }
            
            Spacer()
            
            // Flash button
            Button(action: toggleFlash) {
                Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isFlashOn ? .yellow : .white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                    )
            }
            .disabled(!cameraService.isFlashAvailable)
            .opacity(cameraService.isFlashAvailable ? 1.0 : 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Camera Type Switcher
    private var cameraTypeSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(AdvancedCameraService.CameraType.allCases, id: \.self) { cameraType in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        cameraService.switchCamera(to: cameraType)
                    }
                }) {
                    Text(cameraType.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(cameraService.currentCameraType == cameraType ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(cameraService.currentCameraType == cameraType ? 
                                      Color.white : Color.black.opacity(0.6))
                        )
                }
                .disabled(cameraService.isCapturing)
            }
        }
    }
    
    // MARK: - Bottom Controls Bar
    private var bottomControlsBar: some View {
        VStack(spacing: 20) {
            // Zoom slider (if zoom available)
            if cameraService.maxZoomFactor > 1.0 {
                zoomSlider
            }
            
            // Main capture controls
            captureControlsRow
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    // MARK: - Zoom Slider
    private var zoomSlider: some View {
        VStack(spacing: 8) {
            HStack {
                Text("1×")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Slider(value: $tempZoomFactor, in: 1.0...cameraService.maxZoomFactor, step: 0.1)
                    .accentColor(.white)
                    .onChange(of: tempZoomFactor) { newValue in
                        cameraService.setZoomFactor(newValue)
                    }
                
                Text("\(String(format: "%.1f", cameraService.maxZoomFactor))×")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            Text("Zoom: \(String(format: "%.1f", cameraService.currentZoomFactor))×")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    // MARK: - Capture Controls Row
    private var captureControlsRow: some View {
        HStack(spacing: 0) {
            // Left spacer for balance
            Spacer()
                .frame(maxWidth: .infinity)
            
            // Main capture button
            Button(action: capturePhoto) {
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    // Inner button
                    Circle()
                        .fill(Color.white)
                        .frame(width: 65, height: 65)
                        .scaleEffect(cameraService.isCapturing ? 0.9 : 1.0)
                    
                    // Loading indicator
                    if cameraService.isCapturing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
            .disabled(cameraService.isCapturing || !cameraService.isSessionRunning)
            .animation(.easeInOut(duration: 0.1), value: cameraService.isCapturing)
            .frame(maxWidth: .infinity)
            
            // Right: Stabilization status
            VStack {
                stabilizationStatusIndicator
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Stabilization Status Indicator
    private var stabilizationStatusIndicator: some View {
        Group {
            if cameraService.isImageStabilizationAvailable {
                VStack(spacing: 4) {
                    Image(systemName: "gyroscope")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    Text("Sabit")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.8))
                )
            }
        }
    }
    
    // MARK: - Zoom Indicator (Temporary)
    private var zoomIndicator: some View {
        VStack {
            Text("\(String(format: "%.1f", tempZoomFactor))×")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.7))
                )
            
            Spacer()
        }
        .padding(.top, 80)
    }
    
    // MARK: - Stabilization Indicator
    private var stabilizationIndicator: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack {
                    Image(systemName: "gyroscope")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    
                    Text("Stabilizing...")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.8))
                )
                
                Spacer()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Error Overlay
    private func errorOverlay(message: String) -> some View {
        VStack {
            Spacer()
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.9))
                )
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    private func capturePhoto() {
        // Visual feedback
        withAnimation(.easeInOut(duration: 0.15)) {
            showFlash = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showFlash = false
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Capture photo with advanced service
        cameraService.capturePhoto { result in
            switch result {
            case .success(let image):
                onImageCaptured(image)
            case .failure(let error):
                print("❌ Photo capture failed: \(error.localizedDescription)")
                // Could show error to user here
            }
        }
    }
    
    private func toggleFlash() {
        isFlashOn = cameraService.toggleFlash()
    }
    
    private func showFocusAnimation(at point: CGPoint) {
        // Could add focus ring animation here
        // For now, just provide haptic feedback
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    private func hideZoomControlsAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showZoomControls = false
            }
        }
    }
}

// MARK: - Advanced Camera Preview
struct AdvancedCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        
        // Handle orientation changes properly
        updatePreviewOrientation(previewLayer)
        
        view.layer.addSublayer(previewLayer)
        
        // Listen for orientation changes
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            updatePreviewOrientation(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update if needed
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.session = session
            updatePreviewOrientation(previewLayer)
        }
    }
    
    private func updatePreviewOrientation(_ previewLayer: AVCaptureVideoPreviewLayer) {
        guard let connection = previewLayer.connection else { return }
        
        let deviceOrientation = UIDevice.current.orientation
        let videoOrientation: AVCaptureVideoOrientation
        
        switch deviceOrientation {
        case .portrait:
            videoOrientation = .portrait
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            videoOrientation = .landscapeRight
        case .landscapeRight:
            videoOrientation = .landscapeLeft
        default:
            videoOrientation = .portrait
        }
        
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
    }
}

#Preview {
    AdvancedCameraView { image in
        print("📸 Image captured: \(image.size)")
    }
} 