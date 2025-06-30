import Foundation
import UIKit

class DeviceIdentifier {
    // MARK: - Cihaz kimliği oluşturma (Android uyumlu)
    static func getUniqueDeviceId() -> String {
        // Android'deki gibi cihaz bilgilerini al
        let deviceName = UIDevice.current.name
        let deviceModel = UIDevice.current.model
        let systemName = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion
        let identifierForVendor = UIDevice.current.identifierForVendor?.uuidString ?? ""
        
        // Android'deki gibi birleştir ve hash'le
        let combinedString = "\(deviceName)|\(deviceModel)|\(systemName)|\(systemVersion)|\(identifierForVendor)"
        let hashedString = combinedString.data(using: .utf8)?.base64EncodedString() ?? ""
        
        // Android'deki gibi sadece alfanumerik karakterleri al
        let deviceId = hashedString.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        
        print("📱 Device ID generated: \(deviceId)")
        return deviceId
    }
    
    // MARK: - Okunabilir cihaz bilgileri (Android uyumlu)
    static func getReadableDeviceInfo() -> String {
        let deviceName = UIDevice.current.name
        let deviceModel = UIDevice.current.model
        let systemName = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion
        let identifierForVendor = UIDevice.current.identifierForVendor?.uuidString ?? "N/A"
        
        return """
        Cihaz Adı: \(deviceName)
        Model: \(deviceModel)
        İşletim Sistemi: \(systemName)
        Sistem Versiyonu: \(systemVersion)
        Vendor ID: \(identifierForVendor)
        """
    }
} 