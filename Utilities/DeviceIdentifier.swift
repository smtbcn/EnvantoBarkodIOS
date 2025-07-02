import Foundation
import UIKit

class DeviceIdentifier {
    private static let DEVICE_ID_KEY = "envanto_device_id"
    
    // Android uyumlu unique device ID
    static func getUniqueDeviceId() -> String {
        // Önce UserDefaults'tan kontrol et
        if let savedDeviceId = UserDefaults.standard.string(forKey: DEVICE_ID_KEY),
           !savedDeviceId.isEmpty {
            return savedDeviceId
        }
        
        // Yeni device ID oluştur
        let deviceId = generateDeviceId()
        
        // UserDefaults'a kaydet
        UserDefaults.standard.set(deviceId, forKey: DEVICE_ID_KEY)
        UserDefaults.standard.synchronize()
        
        return deviceId
    }
    
    private static func generateDeviceId() -> String {
        // iOS cihaz bilgileri kombinasyonu
        let deviceModel = UIDevice.current.model
        let systemName = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion
        
        // Cihaz adını al (kullanıcı tarafından değiştirilebilir ama referans için)
        let deviceName = UIDevice.current.name
        
        // Vendor ID (app'e özel, ama stable)
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        // Bundle ID
        let bundleId = Bundle.main.bundleIdentifier ?? "com.envanto.barcode"
        
        // Kombinasyon string'i oluştur
        let combinedString = "\(deviceModel)-\(systemName)-\(systemVersion)-\(vendorId)-\(bundleId)"
        
        // MD5 hash ile kısalt (Android ile uyumlu format)
        let deviceId = combinedString.md5
        
        print("🔧 DeviceIdentifier: Yeni device ID oluşturuldu: \(deviceId)")
        print("📱 DeviceIdentifier: Cihaz bilgileri:")
        print("   - Model: \(deviceModel)")
        print("   - System: \(systemName) \(systemVersion)")
        print("   - Name: \(deviceName)")
        print("   - Vendor ID: \(vendorId)")
        
        return deviceId
    }
    
    // Device bilgilerini debug amaçlı döndür
    static func getDeviceInfo() -> [String: String] {
        return [
            "model": UIDevice.current.model,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "name": UIDevice.current.name,
            "vendorId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "bundleId": Bundle.main.bundleIdentifier ?? "unknown",
            "deviceId": getUniqueDeviceId()
        ]
    }
}

// MARK: - String MD5 Extension
extension String {
    var md5: String {
        import CryptoKit
        
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
} 