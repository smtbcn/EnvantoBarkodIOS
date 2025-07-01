import SwiftUI
import AVFoundation
import Vision

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppStateManager
    
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
                viewModel.handleBarcodeDetection(barcode)
                // Android logic: External browser aç ve ScannerView'ı kapat
                viewModel.openWebsite(with: barcode)
            }
        }
        .onReceive(viewModel.$shouldDismissToMain) { shouldDismiss in
            if shouldDismiss {
                // Android finish() equivalent - ScannerView'ı tamamen kapat
                appState.closeScannerToMainMenu()
            }
        }
        .sheet(isPresented: $viewModel.showWebBrowser) {
            WebBrowserView(
                url: viewModel.currentURL,
                onReturnToScanner: {
                    viewModel.showWebBrowser = false
                    viewModel.resetScanning()
                },
                onClose: {
                    viewModel.showWebBrowser = false
                    appState.closeScannerToMainMenu()
                }
            )
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

// MARK: - Web Browser View
struct WebBrowserView: View {
    let url: String
    let onReturnToScanner: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                if let validURL = URL(string: url) {
                    WebView(url: validURL)
                } else {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Geçersiz URL")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top)
                        
                        Text("URL yüklenemedi: \(url)")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding()
                }
            }
            .navigationTitle("Envanto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Tekrar Tara") {
                        onReturnToScanner()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        onClose()
                    }
                }
            }
        }
    }
}

// MARK: - WebView
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Güncelleme gerektiğinde buraya kod eklenebilir
    }
}

#Preview {
    ScannerView()
        .environmentObject(AppStateManager())
} 