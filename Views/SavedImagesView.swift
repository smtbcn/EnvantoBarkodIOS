import SwiftUI

// MARK: - Saved Images View (Android refreshSavedImagesList equivalent)
struct SavedImagesView: View {
    @State private var uploadedCustomers: [String] = []
    @State private var selectedCustomer: String?
    @State private var expandedCustomer: String?
    @State private var customerImages: [String: [CustomerImage]] = [:]
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(8)
                }
                
                Spacer()
                
                Text("Kayıtlı Resimler")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                // Sağ tarafta boş alan için
                Color.clear
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            if isLoading {
                Spacer()
                ProgressView("Yükleniyor...")
                Spacer()
            } else if uploadedCustomers.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(uploadedCustomers, id: \.self) { customer in
                            CustomerImagesCard(
                                customerName: customer,
                                isExpanded: expandedCustomer == customer,
                                images: customerImages[customer] ?? [],
                                onExpandTap: {
                                    withAnimation {
                                        if expandedCustomer == customer {
                                            expandedCustomer = nil
                                        } else {
                                            expandedCustomer = customer
                                            loadImagesForCustomer(customer)
                                        }
                                    }
                                },
                                onDeleteTap: { imagePath in
                                    deleteImage(imagePath, for: customer)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear {
            loadUploadedCustomers()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Henüz Resim Yok")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("Kaydedilen resimler burada görünecek")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
    
    private func loadUploadedCustomers() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let customers = SQLiteManager.shared.getUploadedCustomers()
            
            DispatchQueue.main.async {
                self.uploadedCustomers = customers
                self.isLoading = false
                
                // Her müşteri için resim sayısını yükle
                for customer in customers {
                    loadImagesForCustomer(customer)
                }
            }
        }
    }
    
    private func loadImagesForCustomer(_ customer: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let customerDirectory = documentsPath
            .appendingPathComponent("EnvantoBarkod")
            .appendingPathComponent(customer)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: customerDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            let images = try files.compactMap { url -> CustomerImage? in
                let attributes = try url.resourceValues(forKeys: [.contentModificationDateKey])
                let modificationDate = attributes.contentModificationDate ?? Date()
                
                if url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg" {
                    return CustomerImage(
                        id: url.lastPathComponent,
                        path: url.path,
                        date: modificationDate,
                        isUploading: false
                    )
                }
                return nil
            }
            .sorted { $0.date > $1.date }
            
            DispatchQueue.main.async {
                self.customerImages[customer] = images
            }
        } catch {
            print("❌ Error loading images for \(customer): \(error)")
        }
    }
    
    private func deleteImage(_ path: String, for customer: String) {
        do {
            try FileManager.default.removeItem(atPath: path)
            
            // Güncelle UI'ı
            if var images = customerImages[customer] {
                images.removeAll { $0.path == path }
                customerImages[customer] = images
                
                // Eğer müşterinin son resmi silindiyse
                if images.isEmpty {
                    uploadedCustomers.removeAll { $0 == customer }
                }
            }
            
            // SQLite'ı güncelle
            SQLiteManager.shared.updateCustomerImageCount(musteriAdi: customer, decrease: true)
        } catch {
            print("❌ Error deleting image: \(error)")
        }
    }
}

struct CustomerImage: Identifiable {
    let id: String
    let path: String
    let date: Date
    var isUploading: Bool
}

struct CustomerImagesCard: View {
    let customerName: String
    let isExpanded: Bool
    let images: [CustomerImage]
    let onExpandTap: () -> Void
    let onDeleteTap: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Müşteri başlığı
            Button(action: onExpandTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customerName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(images.count) resim")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
            }
            
            // Resim listesi
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(images) { image in
                        HStack {
                            // Resim
                            if let uiImage = UIImage(contentsOfFile: image.path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                    .clipped()
                            }
                            
                            // Resim bilgileri
                            VStack(alignment: .leading, spacing: 4) {
                                Text(image.id)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                
                                if image.isUploading {
                                    Text("İnternet Bekleniyor")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                } else {
                                    Text(image.date, style: .date)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Silme butonu
                            Button(action: { onDeleteTap(image.path) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .padding(8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        
                        if image.id != images.last?.id {
                            Divider()
                                .padding(.leading, 84)
                        }
                    }
                }
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
            }
        }
    }
}

#Preview {
    SavedImagesView()
}