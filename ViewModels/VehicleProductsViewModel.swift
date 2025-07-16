import SwiftUI
import Foundation

public class VehicleProductsViewModel: ObservableObject, DeviceAuthCallback {
    @Published public var products: [VehicleProduct] = []
    @Published public var customerGroups: [CustomerGroup] = []
    @Published public var isLoading = false
    @Published public var showError = false
    @Published public var errorMessage: String?
    @Published public var isDeviceAuthorized = false
    @Published public var isUserLoggedIn = false
    @Published public var showLoginSheet = false
    
    private var currentUser: User?
    
    public struct CustomerGroup: Identifiable {
        public let id = UUID()
        public let customerName: String
        public let products: [VehicleProduct]
        public var isExpanded: Bool = false
        public var isSelected: Bool = false
        
        public var productCount: Int {
            return products.count
        }
        
        public init(customerName: String, products: [VehicleProduct], isExpanded: Bool = false, isSelected: Bool = false) {
            self.customerName = customerName
            self.products = products
            self.isExpanded = isExpanded
            self.isSelected = isSelected
        }
    }
    
    public init() {}
    
    public func onAppear() {
        checkDeviceAuthorization()
    }
    
    public func refresh() {
        Task {
            await loadVehicleProducts()
        }
    }
    
    // MARK: - Device Authorization
    public func checkDeviceAuthorization() {
        DeviceAuthManager.checkDeviceAuthorization(callback: self)
    }
    
    // MARK: - DeviceAuthCallback
    public func onAuthSuccess() {
        DispatchQueue.main.async {
            self.isDeviceAuthorized = true
            self.checkUserLogin()
        }
    }
    
    public func onAuthFailure() {
        DispatchQueue.main.async {
            self.isDeviceAuthorized = false
        }
    }
    
    public func onShowLoading() {
        DispatchQueue.main.async {
            self.isLoading = true
        }
    }
    
    public func onHideLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
    
    // MARK: - User Login
    private func checkUserLogin() {
        // Her zaman login dialog'u göster (kullanıcı seçimi için)
        // Session varsa kayıtlı kullanıcı olarak gösterilecek
        showLoginSheet = true
    }
    
    public func onLoginSuccess(_ user: User) {
        currentUser = user
        isUserLoggedIn = true
        showLoginSheet = false
        Task {
            await loadVehicleProducts()
        }
    }
    
    public func onLoginCancel() {
        showLoginSheet = false
        // Login iptal edildi, kullanıcı sayfayı kapatabilir
    }
    
    public func showLoginForm() {
        showLoginSheet = true
    }
    
    // MARK: - API Calls
    @MainActor
    private func loadVehicleProducts() async {
        guard let user = currentUser else { return }
        
        isLoading = true
        
        do {
            let baseURL = Constants.Network.baseURL
            guard let url = URL(string: "\(baseURL)/vehicle_products.asp?user_id=\(user.userId)") else {
                throw URLError(.badURL)
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let vehicleProducts = try JSONDecoder().decode([VehicleProduct].self, from: data)
            
            self.products = vehicleProducts
            self.updateCustomerGroups()
            
        } catch {
            self.showError(message: "Araçtaki ürünler yüklenemedi: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func updateCustomerGroups() {
        let grouped = Dictionary(grouping: products) { $0.musteriAdi }
        
        customerGroups = grouped.map { (customerName, products) in
            let existingGroup = customerGroups.first { $0.customerName == customerName }
            return CustomerGroup(
                customerName: customerName,
                products: products,
                isExpanded: existingGroup?.isExpanded ?? false,
                isSelected: existingGroup?.isSelected ?? false
            )
        }.sorted { $0.customerName < $1.customerName }
    }
    
    // MARK: - User Interface
    public var currentUserName: String {
        return currentUser?.fullName ?? "Kullanıcı"
    }
    
    public var hasSelectedCustomers: Bool {
        return customerGroups.contains { $0.isSelected }
    }
    
    public var selectedCustomerCount: Int {
        return customerGroups.filter { $0.isSelected }.count
    }
    
    public var isEmpty: Bool {
        return products.isEmpty
    }
    
    // MARK: - Customer Selection & Expansion
    public func toggleCustomerSelection(_ customerName: String) {
        if let index = customerGroups.firstIndex(where: { $0.customerName == customerName }) {
            customerGroups[index].isSelected.toggle()
        }
    }
    
    public func toggleCustomerExpansion(_ customerName: String) {
        if let index = customerGroups.firstIndex(where: { $0.customerName == customerName }) {
            customerGroups[index].isExpanded.toggle()
        }
    }
    
    // MARK: - Delivery & Return Operations
    public func deliverSelectedCustomers() {
        Task {
            await performDelivery()
        }
    }
    
    public func returnProductToDepot(_ product: VehicleProduct) {
        Task {
            await performReturnToDepot(product)
        }
    }
    
    @MainActor
    private func performDelivery() async {
        guard let user = currentUser else { return }
        
        let selectedCustomers = customerGroups.filter { $0.isSelected }.map { $0.customerName }
        
        guard !selectedCustomers.isEmpty else { return }
        
        isLoading = true
        
        do {
            let baseURL = Constants.Network.baseURL
            guard let url = URL(string: "\(baseURL)/vehicle_delivery.asp") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let selectedCustomersString = selectedCustomers.joined(separator: ",")
            
            // URL encoding for form data
            let encodedCustomers = selectedCustomersString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? selectedCustomersString
            let encodedUserName = user.fullName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? user.fullName
            
            let bodyString = "selected_customers=\(encodedCustomers)&user_id=\(user.userId)&user_name=\(encodedUserName)"
            request.httpBody = bodyString.data(using: String.Encoding.utf8)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let deliveryResponse = try JSONDecoder().decode(DeliveryResponse.self, from: data)
            
            if deliveryResponse.success {
                // Seçimleri temizle
                clearSelections()
                
                // Listeyi yenile
                await loadVehicleProducts()
                
                // Başarı mesajı (kullanıcı arayüzünde toast gösterilecek)
                print("Teslim başarılı: \(deliveryResponse.message)")
            } else {
                throw NSError(domain: "DeliveryError", code: 0, userInfo: [NSLocalizedDescriptionKey: deliveryResponse.message])
            }
            
        } catch {
            showError(message: "Teslim işlemi başarısız: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func performReturnToDepot(_ product: VehicleProduct) async {
        guard let user = currentUser else { return }
        
        isLoading = true
        
        do {
            let baseURL = Constants.Network.baseURL
            guard let url = URL(string: "\(baseURL)/vehicle_return_to_depot.asp") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            // URL encoding for form data
            let encodedUserName = user.fullName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? user.fullName
            
            let bodyString = "product_id=\(product.id)&user_id=\(user.userId)&user_name=\(encodedUserName)"
            request.httpBody = bodyString.data(using: String.Encoding.utf8)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let returnResponse = try JSONDecoder().decode(ReturnToDepotResponse.self, from: data)
            
            if returnResponse.success {
                // Listeyi yenile
                await loadVehicleProducts()
                
                // Başarı mesajı (kullanıcı arayüzünde toast gösterilecek)
                print("Depoya iade başarılı: \(returnResponse.message)")
            } else {
                throw NSError(domain: "ReturnError", code: 0, userInfo: [NSLocalizedDescriptionKey: returnResponse.message])
            }
            
        } catch {
            showError(message: "Depoya iade işlemi başarısız: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func clearSelections() {
        for index in customerGroups.indices {
            customerGroups[index].isSelected = false
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
} 