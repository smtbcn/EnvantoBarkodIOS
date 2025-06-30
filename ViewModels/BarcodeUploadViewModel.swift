import SwiftUI
import Foundation

// MARK: - Customer Model (API'den gelen format: {"musteri_adi":"..."})
struct Customer: Codable {
    let musteri_adi: String
}

// MARK: - BarcodeUploadViewModel
class BarcodeUploadViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var isAuthSuccess = false
    @Published var customerSearchText = ""
    @Published var searchResults: [String] = []
    @Published var selectedCustomer: String?
    @Published var isSearching = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadMessage = ""
    @Published var showingToast = false
    @Published var toastMessage = ""
    
    private var customerCache: [String] = []
    private var lastCacheUpdate: Date?
    private let cacheExpirationInterval: TimeInterval = 6 * 60 * 60 // 6 hours like Android
    
    init() {
        loadCustomerCache()
    }
    
    func checkDeviceAuthorization() {
        isLoading = true
        
        DeviceAuthManager.checkDeviceAuthorization(callback: DeviceAuthCallbackImpl(
            authSuccessHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.isAuthSuccess = true
                    self?.checkAndUpdateCustomerCache()
                }
            },
            authFailureHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.isAuthSuccess = false
                }
            },
            showLoadingHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.isLoading = true
                }
            },
            hideLoadingHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            }
        ))
    }
    
    func searchCustomers(query: String) {
        guard query.count >= 2 else { 
            searchResults = []
            return 
        }
        
        isSearching = true
        
        // First search in cache (offline)
        searchOfflineCustomers(query: query)
        
        // Then search online in parallel
        searchOnlineCustomers(query: query)
    }
    
    private func searchOfflineCustomers(query: String) {
        let filteredCache = customerCache.filter { customer in
            customer.lowercased().contains(query.lowercased())
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.searchResults = Array(filteredCache.prefix(10)) // Limit to 10 results
            print("📱 Offline search: Found \(filteredCache.count) customers")
        }
    }
    
    private func searchOnlineCustomers(query: String) {
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: "\(baseURL)customers.asp") else {
            print("❌ Invalid API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = "action=search&query=\(query)"
        request.httpBody = parameters.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isSearching = false
            }
            
            if let error = error {
                print("❌ Search API error: \(error)")
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            print("📡 Search API response: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
            
            do {
                let customers = try JSONDecoder().decode([Customer].self, from: data)
                let customerNames = customers.map { $0.musteri_adi }
                
                DispatchQueue.main.async {
                    // Merge with offline results, removing duplicates
                    let combinedResults = Array(Set(self?.searchResults ?? [] + customerNames))
                        .sorted()
                        .prefix(10)
                    
                    self?.searchResults = Array(combinedResults)
                    print("🌐 Online search: Found \(customers.count) customers, total results: \(combinedResults.count)")
                }
            } catch {
                print("❌ JSON decode error: \(error)")
            }
        }.resume()
    }
    
    private func checkAndUpdateCustomerCache() {
        let cachedCount = customerCache.count
        print("📋 Customer cache check: \(cachedCount) customers in cache")
        
        // If no customers in cache, immediately fetch all
        if cachedCount == 0 {
            print("📋 No customers in cache, fetching all immediately...")
            fetchAndCacheAllCustomers()
            return
        }
        
        // Check if cache needs update (6 hours)
        if let lastUpdate = lastCacheUpdate {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate < cacheExpirationInterval {
                print("📋 Cache is fresh (\(Int(timeSinceLastUpdate/3600)) hours old), no update needed")
                return
            }
        }
        
        print("📋 Cache is stale, updating...")
        fetchAndCacheAllCustomers()
    }
    
    private func fetchAndCacheAllCustomers() {
        print("📋 Fetching all customers for cache...")
        
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: "\(baseURL)customers.asp") else {
            print("❌ Invalid API URL for cache")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = "action=getall"
        request.httpBody = parameters.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Cache API error: \(error)")
                return
            }
            
            guard let data = data else {
                print("❌ No cache data received")
                return
            }
            
            print("📡 Cache API response size: \(data.count) bytes")
            
            do {
                let customers = try JSONDecoder().decode([Customer].self, from: data)
                let customerNames = customers.map { $0.musteri_adi }
                
                DispatchQueue.main.async {
                    self?.customerCache = customerNames
                    self?.lastCacheUpdate = Date()
                    self?.saveCustomerCache()
                    print("📋 ✅ Customer cache updated: \(customers.count) customers")
                }
            } catch {
                print("❌ Cache JSON decode error: \(error)")
            }
        }.resume()
    }
    
    private func loadCustomerCache() {
        if let cached = UserDefaults.standard.array(forKey: "customerCache") as? [String] {
            customerCache = cached
            print("📋 Loaded \(cached.count) customers from cache")
        }
        
        if let lastUpdate = UserDefaults.standard.object(forKey: "lastCacheUpdate") as? Date {
            lastCacheUpdate = lastUpdate
            let hoursAgo = Int(Date().timeIntervalSince(lastUpdate) / 3600)
            print("📋 Last cache update: \(hoursAgo) hours ago")
        }
    }
    
    private func saveCustomerCache() {
        UserDefaults.standard.set(customerCache, forKey: "customerCache")
        UserDefaults.standard.set(lastCacheUpdate, forKey: "lastCacheUpdate")
        print("📋 Customer cache saved to UserDefaults")
    }
    
    func showToast(_ message: String) {
        toastMessage = message
        showingToast = true
        
        // Auto hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showingToast = false
        }
    }
}

// MARK: - Device Auth Callback Implementation
private struct DeviceAuthCallbackImpl: DeviceAuthCallback {
    let authSuccessHandler: () -> Void
    let authFailureHandler: () -> Void
    let showLoadingHandler: () -> Void
    let hideLoadingHandler: () -> Void
    
    func onAuthSuccess() {
        authSuccessHandler()
    }
    
    func onAuthFailure() {
        authFailureHandler()
    }
    
    func onShowLoading() {
        showLoadingHandler()
    }
    
    func onHideLoading() {
        hideLoadingHandler()
    }
} 