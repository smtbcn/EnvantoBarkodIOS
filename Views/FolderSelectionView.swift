import SwiftUI
import UniformTypeIdentifiers

struct FolderSelectionView: View {
    @State private var showingDocumentPicker = false
    @State private var selectedFolderPath = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let onFolderSelected: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            
            Spacer()
            
            // Firefox benzeri simge
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Klasör Seçimi Gerekli")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Firefox gibi uygulamalarda olduğu gibi, resimlerin kaydedileceği ana klasörü seçmeniz gerekiyor.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 15) {
                Text("Seçilen Klasör:")
                    .font(.headline)
                
                if selectedFolderPath.isEmpty {
                    Text("Henüz klasör seçilmedi")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text(selectedFolderPath)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .lineLimit(3)
                }
            }
            
            VStack(spacing: 15) {
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Klasör Seç")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                if !selectedFolderPath.isEmpty {
                    Button(action: {
                        // Seçilen klasörü onayla
                        onFolderSelected()
                    }) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Klasörü Onayla")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal)
            
            // Bilgilendirme
            VStack(spacing: 10) {
                Text("ℹ️ Bilgi")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Seçeceğiniz klasörde 'Envanto' adında bir alt klasör oluşturulacak")
                    Text("• Tüm müşteri resimleri bu klasör altında saklanacak")
                    Text("• Files uygulamasından kolayca erişebileceksiniz")
                    Text("• Firefox gibi diğer uygulamaların klasörleri de burada görünür")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Klasör Seçimi")
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(
                allowedContentTypes: [.folder],
                onDocumentPicked: { url in
                    handleFolderSelection(url)
                }
            )
        }
        .alert("Klasör Seçimi", isPresented: $showingAlert) {
            Button("Tamam") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            updateSelectedFolderPath()
        }
    }
    
    private func handleFolderSelection(_ url: URL) {
        // Güvenlik kapsamlı kaynak erişimi başlat
        guard url.startAccessingSecurityScopedResource() else {
            alertMessage = "Seçilen klasöre erişim izni alınamadı"
            showingAlert = true
            return
        }
        
        // Seçilen klasörü kaydet
        ImageStorageManager.saveUserSelectedFolder(url)
        
        // UI'ı güncelle
        updateSelectedFolderPath()
        
        alertMessage = "Klasör başarıyla seçildi! Artık resimleri bu konuma kaydedebilirsiniz."
        showingAlert = true
        
        // Kaynak erişimini sonlandır
        url.stopAccessingSecurityScopedResource()
    }
    
    private func updateSelectedFolderPath() {
        if let folderURL = ImageStorageManager.getUserSelectedFolder() {
            selectedFolderPath = folderURL.path
            folderURL.stopAccessingSecurityScopedResource()
        } else {
            selectedFolderPath = ""
        }
    }
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Güncelleme gerektiğinde
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Kullanıcı iptal etti
        }
    }
}

#Preview {
    FolderSelectionView {
        print("Klasör seçildi!")
    }
} 