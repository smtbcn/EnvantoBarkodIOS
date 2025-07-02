import Foundation
import Network
import SystemConfiguration
import Combine

class NetworkUtils: ObservableObject {
    static let shared = NetworkUtils()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var isWiFiConnected = false
    @Published var connectionType: ConnectionType = .none
    
    enum ConnectionType {
        case none
        case wifi
        case cellular
        case wiredEthernet
    }
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? false
                let wasWiFiConnected = self?.isWiFiConnected ?? false
                
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionType(path: path)
                
                // Network durumu değişti - Upload servisini tetikle
                self?.handleNetworkChange(wasConnected: wasConnected, wasWiFiConnected: wasWiFiConnected)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateConnectionType(path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
            isWiFiConnected = true
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
            isWiFiConnected = false
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
            isWiFiConnected = false
        } else {
            connectionType = .none
            isWiFiConnected = false
        }
    }
    
    // MARK: - Network Change Handler
    private func handleNetworkChange(wasConnected: Bool, wasWiFiConnected: Bool) {
        let nowConnected = isConnected
        let nowWiFiConnected = isWiFiConnected
        
        // Bağlantı durumu değişti mi?
        if wasConnected != nowConnected || wasWiFiConnected != nowWiFiConnected {
            print("🌐 NetworkUtils: Bağlantı durumu değişti")
            print("   - Was connected: \(wasConnected) -> Now connected: \(nowConnected)")
            print("   - Was WiFi: \(wasWiFiConnected) -> Now WiFi: \(nowWiFiConnected)")
            
            // Bağlantı geldi ve WiFi ayarları varsa upload'ı tetikle
            if nowConnected && (!wasConnected || (!wasWiFiConnected && nowWiFiConnected)) {
                triggerUploadOnNetworkChange()
            }
        }
    }
    
    private func triggerUploadOnNetworkChange() {
        // Upload tetikleme koşulları:
        // 1. İnternet bağlantısı geldi VEYA
        // 2. WiFi bağlantısı geldi ve WiFi-only ayarı açık
        
        let wifiOnly = UserDefaults.standard.bool(forKey: "wifi_only")
        
        if wifiOnly && isWiFiConnected {
            print("🚀 NetworkUtils: WiFi bağlandı - Upload servisi tetikleniyor")
            UploadService.shared.startUploadService(wifiOnly: true)
        } else if !wifiOnly && isConnected {
            print("🚀 NetworkUtils: İnternet bağlandı - Upload servisi tetikleniyor")
            UploadService.shared.startUploadService(wifiOnly: false)
        }
    }
    
    // MARK: - Static Methods (Android uyumluluğu için)
    static func isNetworkAvailable() -> Bool {
        return shared.isConnected
    }
    
    static func isWifiConnected() -> Bool {
        return shared.isWiFiConnected
    }
    
    static func getConnectionType() -> ConnectionType {
        return shared.connectionType
    }
    
    // MARK: - Upload Kontrolü (Android mantığı)
    static func canUploadWithSettings(wifiOnly: Bool) -> (canUpload: Bool, reason: String) {
        let isNetworkAvailable = NetworkUtils.isNetworkAvailable()
        let isWiFiConnected = NetworkUtils.isWifiConnected()
        
        if !isNetworkAvailable {
            return (false, "İnternet bağlantısı bekleniyor...")
        }
        
        if wifiOnly && !isWiFiConnected {
            return (false, "WiFi bağlantısı bekleniyor...")
        }
        
        return (true, "Yükleme hazır")
    }
    
    deinit {
        monitor.cancel()
    }
} 