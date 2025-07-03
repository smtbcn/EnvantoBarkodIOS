import Foundation
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    func playBeepSound() {
        guard let url = Bundle.main.url(forResource: "beep", withExtension: "mp3") else {
            // Fallback to system beep
            AudioServicesPlaySystemSound(1004)
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 0.8
            audioPlayer?.play()
        } catch {
            // Fallback to system beep if custom sound fails
            AudioServicesPlaySystemSound(1004)
        }
    }
    
    func playSystemBeep() {
        AudioServicesPlaySystemSound(1004)
    }
    
    func playVibration() {
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
} 