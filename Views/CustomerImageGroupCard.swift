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
            // Müşteri header'ı (Android Material Design like - BarcodeUploadView ile birebir aynı)
            Button(action: {
                onExpand() // Direk toggle
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
                    
                    // WhatsApp paylaş butonu (müşteri resimleri için)
                    Button(action: {
                        let imagePaths = group.images.map { $0.imagePath }
                        onShareWhatsApp(group.customerName, imagePaths)
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(group.isSharedToday ? .green : .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
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
                        ForEach(group.images, id: \.id) { image in
                            CustomerAndroidImageRow(image: image) {
                                onDeleteImage(image.imagePath)
                            }
                            
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
}

// MARK: - Customer Android Image Row (Müşteri resimleri için - BarcodeUploadView AndroidImageRow benzeri)
struct CustomerAndroidImageRow: View {
    let image: SavedCustomerImage
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Sol: Resim preview (Android like)
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
                    // Dosya yok - database kaydı mevcut ama dosya silinmiş
                    Image(systemName: "doc.questionmark")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                        .frame(width: 50, height: 50)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                        .overlay(
                            // Dosya bulunamadı işareti
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                                .offset(x: 15, y: -15)
                        )
                }
            }
            
            // Orta: Dosya bilgileri (Android like)
            VStack(alignment: .leading, spacing: 4) {
                // Dosya adı (sadece filename)
                Text(extractFileName(from: image.imagePath))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Local kayıt durumu (Android tarzı)
                HStack(spacing: 6) {
                    Image(systemName: getLocalStatusIcon())
                        .font(.system(size: 12))
                        .foregroundColor(getLocalStatusColor())
                    
                    Text(getLocalStatusText())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(getLocalStatusColor())
                    
                    Spacer()
                }
                
                // Müşteri bilgisi
                Text("Müşteri: \(image.customerName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Tarih ve yükleyen - 2 satır
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tarih: \(formattedDate(image.date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text("Yükleyen: \(image.uploadedBy)")
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
    
    private func getLocalStatusIcon() -> String {
        // Dosya yoksa farklı ikon göster
        if !image.fileExists {
            return "doc.questionmark"
        }
        // Müşteri resimleri için local kayıt ikonu
        return "externaldrive.fill"
    }
    
    private func getLocalStatusColor() -> Color {
        // Dosya yoksa turuncu
        if !image.fileExists {
            return .orange
        }
        // Müşteri resimleri için yeşil (local kayıt)
        return .green
    }
    
    private func getLocalStatusText() -> String {
        // Dosya yoksa farklı mesaj
        if !image.fileExists {
            return "DOSYA BULUNAMADI"
        }
        // Müşteri resimleri için local kayıt mesajı
        return "LOCAL KAYIT"
    }
}

#Preview {
    let sampleImage = SavedCustomerImage(
        id: 1,
        customerName: "SAMET BELER",
        imagePath: "/test/path/image.jpg",
        date: Date(),
        uploadedBy: "Test User"
    )
    
    let sampleGroup = CustomerImageGroup(
        customerName: "SAMET BELER",
        images: [sampleImage]
    )
    
    CustomerImageGroupCard(
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