import UIKit
import AVFoundation

class BatteryOptimizer {
    static let shared = BatteryOptimizer()
    
    private init() {}
    
    // Pil seviyesine göre kamera ayarlarını optimize et
    func optimizeCameraSettings(for device: AVCaptureDevice) {
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        do {
            try device.lockForConfiguration()
            
            // Pil seviyesi düşükse daha agresif optimizasyon
            if batteryLevel < 0.2 || batteryState == .unplugged {
                // Düşük pil modu: Minimum ayarlar
                optimizeForLowBattery(device: device)
            } else if batteryLevel < 0.5 {
                // Orta pil modu: Dengeli ayarlar
                optimizeForMediumBattery(device: device)
            } else {
                // Yüksek pil modu: Normal ayarlar
                optimizeForHighBattery(device: device)
            }
            
            device.unlockForConfiguration()
        } catch {
            print("❌ Kamera optimizasyonu başarısız: \(error)")
        }
    }
    
    private func optimizeForLowBattery(device: AVCaptureDevice) {
        // En düşük frame rate
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 10) // 10 FPS
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 10)
        
        // Otomatik özellikler kapalı
        if device.isFocusModeSupported(.locked) {
            device.focusMode = .locked
        }
        
        if device.isExposureModeSupported(.locked) {
            device.exposureMode = .locked
        }
        
        print("🔋 Düşük pil modu: 10 FPS, otomatik özellikler kapalı")
    }
    
    private func optimizeForMediumBattery(device: AVCaptureDevice) {
        // Orta frame rate
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15) // 15 FPS
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
        
        // Sınırlı otomatik özellikler
        if device.isFocusModeSupported(.autoFocus) {
            device.focusMode = .autoFocus
        }
        
        if device.isExposureModeSupported(.autoExpose) {
            device.exposureMode = .autoExpose
        }
        
        print("🔋 Orta pil modu: 15 FPS, sınırlı otomatik özellikler")
    }
    
    private func optimizeForHighBattery(device: AVCaptureDevice) {
        // Normal frame rate
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20) // 20 FPS
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 20)
        
        // Tüm otomatik özellikler açık
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        
        print("🔋 Yüksek pil modu: 20 FPS, tüm otomatik özellikler açık")
    }
    
    // Barkod tarama frekansını pil seviyesine göre ayarla
    func getOptimalScanInterval() -> Int {
        let batteryLevel = UIDevice.current.batteryLevel
        
        if batteryLevel < 0.2 {
            return 5 // Her 5 frame'de bir tara
        } else if batteryLevel < 0.5 {
            return 3 // Her 3 frame'de bir tara
        } else {
            return 2 // Her 2 frame'de bir tara
        }
    }
    
    // Pil durumunu izle
    func startBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔋 Pil seviyesi değişti: \(UIDevice.current.batteryLevel)")
        }
    }
    
    func stopBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryLevelDidChangeNotification, object: nil)
    }
    
    deinit {
        stopBatteryMonitoring()
    }
}