import SwiftUI
import AVFoundation
import Vision
import WebKit

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
                // In-app browser ile web sitesini aç
                viewModel.openWebsite(with: barcode)
            }
        }
        .sheet(isPresented: $viewModel.showWebBrowser) {
            if let url = viewModel.webURL {
                WebBrowserView(url: url)
                    .onDisappear {
                        // Web browser kapandığında kamera session'ını tekrar başlat
                        viewModel.resumeCamera()
                        viewModel.resetScanning()
                        // Ana menüye performanslı dönüş
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            appState.closeScannerToMainMenu()
                        }
                    }
            }
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

// MARK: - WebBrowserView
struct WebBrowserView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webTitle = "Yükleniyor..."
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Loading indicator
                if isLoading {
                    ProgressView()
                        .frame(height: 3)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
                
                // Web content
                WebView(
                    url: url,
                    isLoading: $isLoading,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    webTitle: $webTitle
                )
            }
            .navigationTitle(webTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            NotificationCenter.default.post(name: .webViewGoBack, object: nil)
                        }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!canGoBack)
                        
                        Button(action: {
                            NotificationCenter.default.post(name: .webViewGoForward, object: nil)
                        }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!canGoForward)
                        
                        Button(action: {
                            NotificationCenter.default.post(name: .webViewReload, object: nil)
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var webTitle: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        
        // Navigation olaylarını dinle
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.goBack),
            name: .webViewGoBack,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.goForward),
            name: .webViewGoForward,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.reload),
            name: .webViewReload,
            object: nil
        )
        
        context.coordinator.webView = webView
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Güncelleme gerekirse buraya eklenebilir
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        var webView: WKWebView?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            parent.webTitle = webView.title ?? "Web Sayfası"
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.webTitle = "Hata"
        }
        
        @objc func goBack() {
            webView?.goBack()
        }
        
        @objc func goForward() {
            webView?.goForward()
        }
        
        @objc func reload() {
            webView?.reload()
        }
    }
}

// Notification names
extension Notification.Name {
    static let webViewGoBack = Notification.Name("webViewGoBack")
    static let webViewGoForward = Notification.Name("webViewGoForward")
    static let webViewReload = Notification.Name("webViewReload")
}

#Preview {
    ScannerView()
        .environmentObject(AppStateManager())
} 