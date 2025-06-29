import SwiftUI
import WebKit

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
    WebBrowserView(url: URL(string: "https://envanto.app")!)
} 