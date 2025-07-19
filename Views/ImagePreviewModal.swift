import SwiftUI

// MARK: - Resim Önizleme Modal'ı
struct ImagePreviewModal: View {
    let imagePath: String
    let customerName: String
    @Binding var isPresented: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            ZStack {
                // Siyah arkaplan
                Color.black
                    .ignoresSafeArea()
                
                // Resim container
                GeometryReader { geometry in
                    if FileManager.default.fileExists(atPath: imagePath) {
                        AsyncImage(url: URL(fileURLWithPath: imagePath)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .gesture(
                                        SimultaneousGesture(
                                            // Pinch to zoom
                                            MagnificationGesture()
                                                .onChanged { value in
                                                    let delta = value / lastScale
                                                    lastScale = value
                                                    scale = min(max(scale * delta, 0.5), 5.0)
                                                }
                                                .onEnded { _ in
                                                    lastScale = 1.0
                                                    if scale < 1.0 {
                                                        withAnimation(.spring()) {
                                                            scale = 1.0
                                                            offset = .zero
                                                        }
                                                    }
                                                },
                                            
                                            // Drag to pan
                                            DragGesture()
                                                .onChanged { value in
                                                    let newOffset = CGSize(
                                                        width: lastOffset.width + value.translation.width,
                                                        height: lastOffset.height + value.translation.height
                                                    )
                                                    offset = newOffset
                                                }
                                                .onEnded { _ in
                                                    lastOffset = offset
                                                }
                                        )
                                    )
                                    .onTapGesture(count: 2) {
                                        // Double tap to reset
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                    
                            case .failure(_):
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                    
                                    Text("Resim yüklenemedi")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.top)
                                }
                                
                            case .empty:
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.5)
                                
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        // Dosya mevcut değil
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            
                            Text("Dosya bulunamadı")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.top)
                        }
                    }
                }
            }
            .navigationTitle(customerName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Dosya adını extract et
                        let fileName = URL(fileURLWithPath: imagePath).lastPathComponent
                        shareImage(fileName: fileName)
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(Color.black.opacity(0.7), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Share Image
    private func shareImage(fileName: String) {
        guard FileManager.default.fileExists(atPath: imagePath) else { return }
        
        let url = URL(fileURLWithPath: imagePath)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // iPad için popover ayarları
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window.rootViewController?.view
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

#Preview {
    ImagePreviewModal(
        imagePath: "/path/to/image.jpg",
        customerName: "Test Müşteri",
        isPresented: .constant(true)
    )
} 