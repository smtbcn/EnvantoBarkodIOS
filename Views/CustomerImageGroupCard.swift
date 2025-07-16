import SwiftUI

struct CustomerImageGroupCard: View {
    let group: CustomerImageGroup
    let isExpanded: Bool
    let onExpand: () -> Void
    let onDeleteCustomer: () -> Void
    let onDeleteImage: (String) -> Void
    let onViewImage: (String) -> Void
    let onShareWhatsApp: (String, [String]) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Başlık Kısmı (Her zaman görünür)
            headerSection
            
            // İçerik Kısmı (Genişletildiğinde görünür)
            if isExpanded {
                imageGridSection
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        Button(action: onExpand) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.customerName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 12) {
                        Label("\(group.imageCount)", systemImage: "photo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(formatDate(group.lastImageDate), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // WhatsApp Paylaş Butonu
                    Button(action: {
                        let imagePaths = group.images.map { $0.imagePath }
                        onShareWhatsApp(group.customerName, imagePaths)
                    }) {
                        Image(systemName: group.isSharedToday ? "checkmark.circle.fill" : "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(group.isSharedToday ? .green : .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Müşteri Sil Butonu
                    Button(action: onDeleteCustomer) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Genişlet/Daralt İkonu
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Image Grid Section
    private var imageGridSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            // Resim Izgara
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(group.images, id: \.id) { image in
                    ImageThumbnailView(
                        image: image,
                        onView: { onViewImage(image.imagePath) },
                        onDelete: { onDeleteImage(image.imagePath) }
                    )
                }
            }
            .padding(.horizontal)
            
            // Alt Bilgiler
            if let firstImage = group.images.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ekleyen: \(firstImage.uploadedBy)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if group.isSharedToday {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Bu müşteri bugün paylaşıldı")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return "Bugün " + formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.timeStyle = .short
            return "Dün " + formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Image Thumbnail View
struct ImageThumbnailView: View {
    let image: SavedCustomerImage
    let onView: () -> Void
    let onDelete: () -> Void
    
    @State private var uiImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 4) {
            // Resim Thumbnail
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(1, contentMode: .fit)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let uiImage = uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Yüklenemedi")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Aksiyon Butonları Overlay
                VStack {
                    HStack {
                        Spacer()
                        
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                }
                .padding(4)
            }
            .cornerRadius(8)
            .onTapGesture {
                onView()
            }
            
            // Tarih Bilgisi
            Text(formatImageDate(image.date))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        Task {
            do {
                let url = URL(fileURLWithPath: image.imagePath)
                let data = try Data(contentsOf: url)
                let loadedImage = UIImage(data: data)
                
                await MainActor.run {
                    self.uiImage = loadedImage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatImageDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "dd/MM"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    let sampleImages = [
        SavedCustomerImage(
            id: 1,
            customerName: "Test Müşteri",
            imagePath: "/path/to/image1.jpg",
            date: Date(),
            uploadedBy: "Test User"
        ),
        SavedCustomerImage(
            id: 2,
            customerName: "Test Müşteri",
            imagePath: "/path/to/image2.jpg",
            date: Date().addingTimeInterval(-3600),
            uploadedBy: "Test User"
        )
    ]
    
    let sampleGroup = CustomerImageGroup(
        customerName: "Test Müşteri",
        images: sampleImages
    )
    
    return CustomerImageGroupCard(
        group: sampleGroup,
        isExpanded: true,
        onExpand: {},
        onDeleteCustomer: {},
        onDeleteImage: { _ in },
        onViewImage: { _ in },
        onShareWhatsApp: { _, _ in }
    )
    .padding()
} 