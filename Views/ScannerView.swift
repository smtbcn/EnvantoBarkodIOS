import SwiftUI
import AVFoundation
import Vision

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingBarcodeResult = false
    @State private var scannedCode = ""
    
    var body: some View {
        ZStack {
            // Kamera önizlemesi
            CameraPreview(session: viewModel.captureSession)
                .ignoresSafeArea()
            
            // Scanner overlay
            VStack {
                // Üst kısım
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.toggleFlash()
                    }) {
                        Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Tarama alanı
                VStack {
                    Text("Barkodu tarama alanına yerleştirin")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.bottom, 20)
                    
                    // Tarama çerçevesi
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 280, height: 280)
                        .overlay(
                            // Tarama çizgisi animasyonu
                            Rectangle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.clear, .blue, .clear]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(height: 3)
                                .offset(y: viewModel.scannerLineOffset)
                                .animation(
                                    Animation.easeInOut(duration: 2.0)
                                        .repeatForever(autoreverses: true),
                                    value: viewModel.scannerLineOffset
                                )
                        )
                    
                    Text("QR kod veya Data Matrix desteklenir")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 20)
                }
                
                Spacer()
                
                // Alt kısım - otomatik odaklama durumu
                if viewModel.isAutoFocusing {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        
                        Text("Odaklanıyor...")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .onReceive(viewModel.$scannedBarcode) { barcode in
            if !barcode.isEmpty {
                scannedCode = barcode
                showingBarcodeResult = true
                viewModel.handleBarcodeDetection(barcode)
            }
        }
        .alert("Barkod Tarandı", isPresented: $showingBarcodeResult) {
            Button("Web Sitesini Aç") {
                viewModel.openWebsite(with: scannedCode)
                dismiss()
            }
            Button("Tekrar Tara") {
                viewModel.resetScanning()
            }
        } message: {
            Text("Barkod içeriği: \(scannedCode)")
        }
    }
}

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
        // Güncelleme gerektiğinde buraya kod eklenebilir
    }
}

#Preview {
    ScannerView()
} 