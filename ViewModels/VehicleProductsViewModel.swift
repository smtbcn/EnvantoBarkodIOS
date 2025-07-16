import Foundation
import SwiftUI

@MainActor
class VehicleProductsViewModel: ObservableObject {
    @Published var products: [VehicleProduct] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var selectedCustomers: Set<String> = []
    @Published var expandedCustomers: Set<String> = []
    
    // Gruplandırılmış veriler
    @Published var customerGroups: [CustomerGroup] = []
    
    // Kullanıcı bilgileri
    @Published var currentUserName: String = ""
    
    private let deviceAuthManager = DeviceAuthManager.shared
    
    struct CustomerGroup: Identifiable {
        let id = UUID()
        let customerName: String
        let products: [VehicleProduct]
        var productCount: Int { products.count }
        var isExpanded: Bool
        var isSelected: Bool
    }
    
    init() {
        // İlk yüklemede kullanıcı adını ayarla
        updateUserDisplay()
    }
    
    // MARK: - Public Methods
    
    /// Sayfa yüklendiğinde çağrılır
    func onAppear() {
        checkDeviceAuthorizationAndLoad()
    }
    
    /// Pull-to-refresh için
    func refresh() {
        Task {
            await loadVehicleProducts()
        }
    }
    
    /// Müşteriyi seç/seçimi kaldır
    func toggleCustomerSelection(_ customerName: String) {
        if selectedCustomers.contains(customerName) {
            selectedCustomers.remove(customerName)
        } else {
            selectedCustomers.insert(customerName)
        }
        updateCustomerGroups()
    }
    
    /// Müşteri grubunu genişlet/daralt
    func toggleCustomerExpansion(_ customerName: String) {
        if expandedCustomers.contains(customerName) {
            expandedCustomers.remove(customerName)
        } else {
            expandedCustomers.insert(customerName)
        }
        updateCustomerGroups()
    }
    
    /// Seçili müşterileri teslim et
    func deliverSelectedCustomers() {
        guard !selectedCustomers.isEmpty else {
            showErrorMessage("Lütfen teslim edilecek müşterileri seçin")
            return
        }
        
        Task {
            await performDelivery()
        }
    }
    
    /// Ürünü depoya geri bırak
    func returnProductToDepot(_ product: VehicleProduct) {
        Task {
            await performReturnToDepot(product)
        }
    }
    
    /// Seçimleri temizle
    func clearSelections() {
        selectedCustomers.removeAll()
        updateCustomerGroups()
    }
    
    // MARK: - Private Methods
    
    private func checkDeviceAuthorizationAndLoad() {
        Task {
            isLoading = true
            
            do {
                let isAuthorized = try await deviceAuthManager.checkDeviceAuthorization()
                if isAuthorized {
                    await loadVehicleProducts()
                } else {
                    showErrorMessage("Cihaz yetkilendirmesi başarısız")
                }
            } catch {
                showErrorMessage("Yetkilendirme hatası: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    private func loadVehicleProducts() async {
        // Şimdilik mock veri kullanıyoruz - sonra API ile değiştirilecek
        await loadMockData()
    }
    
    /// Mock veri yükleme (geliştirme aşamasında)
    private func loadMockData() async {
        isLoading = true
        
        // Simülasyon için delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let mockProducts = [
            VehicleProduct(
                id: 1,
                musteriAdi: "DOĞTAŞ Mobilya A.Ş.",
                urunAdi: "Yatak Odası Takımı Classic",
                urunAdet: 2,
                depoAktaran: "Ahmet Yılmaz",
                depoAktaranTarihi: "15.01.2024 14:30",
                mevcutDepo: "DOĞTAŞ ARACI",
                prosap: "PR001",
                teslimEden: nil,
                teslimatDurumu: 0,
                sevkDurumu: 1,
                urunNotuDurum: 0
            ),
            VehicleProduct(
                id: 2,
                musteriAdi: "DOĞTAŞ Mobilya A.Ş.",
                urunAdi: "Yemek Odası Takımı Modern",
                urunAdet: 1,
                depoAktaran: "Ahmet Yılmaz",
                depoAktaranTarihi: "15.01.2024 14:35",
                mevcutDepo: "DOĞTAŞ ARACI",
                prosap: "PR002",
                teslimEden: nil,
                teslimatDurumu: 0,
                sevkDurumu: 1,
                urunNotuDurum: 0
            ),
            VehicleProduct(
                id: 3,
                musteriAdi: "Lazzoni Mobilya Ltd.",
                urunAdi: "Koltuk Takımı Premium",
                urunAdet: 3,
                depoAktaran: "Mehmet Demir",
                depoAktaranTarihi: "15.01.2024 15:00",
                mevcutDepo: "LAZZONI ARACI",
                prosap: "PR003",
                teslimEden: nil,
                teslimatDurumu: 0,
                sevkDurumu: 1,
                urunNotuDurum: 0
            )
        ]
        
        products = mockProducts
        groupProductsByCustomer()
        isLoading = false
    }
    
    private func groupProductsByCustomer() {
        let grouped = Dictionary(grouping: products, by: { $0.customerName })
        
        customerGroups = grouped.map { customerName, products in
            CustomerGroup(
                customerName: customerName,
                products: products,
                isExpanded: expandedCustomers.contains(customerName),
                isSelected: selectedCustomers.contains(customerName)
            )
        }
        .sorted { $0.customerName < $1.customerName }
    }
    
    private func updateCustomerGroups() {
        customerGroups = customerGroups.map { group in
            CustomerGroup(
                customerName: group.customerName,
                products: group.products,
                isExpanded: expandedCustomers.contains(group.customerName),
                isSelected: selectedCustomers.contains(group.customerName)
            )
        }
    }
    
    private func updateUserDisplay() {
        // LoginManager'dan kullanıcı bilgilerini al (sonra implement edilecek)
        currentUserName = "Test Kullanıcı" // Şimdilik mock
    }
    
    private func performDelivery() async {
        isLoading = true
        
        // Mock delivery işlemi (sonra API ile değiştirilecek)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Başarılı olduğunu varsay
        clearSelections()
        await loadVehicleProducts()
        
        isLoading = false
        showSuccessMessage("Seçili müşteriler başarıyla teslim edildi")
    }
    
    private func performReturnToDepot(_ product: VehicleProduct) async {
        isLoading = true
        
        // Mock return işlemi (sonra API ile değiştirilecek)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Başarılı olduğunu varsay
        await loadVehicleProducts()
        
        isLoading = false
        showSuccessMessage("\(product.urunAdi) başarıyla depoya geri bırakıldı")
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func showSuccessMessage(_ message: String) {
        // Geçici olarak error alert kullanıyoruz, sonra success alert ekleyeceğiz
        errorMessage = message
        showError = true
    }
    
    // MARK: - Computed Properties
    
    var selectedCustomerCount: Int {
        selectedCustomers.count
    }
    
    var hasSelectedCustomers: Bool {
        !selectedCustomers.isEmpty
    }
    
    var isEmpty: Bool {
        products.isEmpty
    }
} 