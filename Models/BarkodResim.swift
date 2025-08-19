import Foundation

struct BarkodResim: Identifiable, Equatable {
    let id: Int
    let musteriAdi: String
    let resimYolu: String
    let tarih: String
    let yukleyen: String
    let yuklendi: Int
    
    var isUploaded: Bool {
        return yuklendi > 0
    }
    
    var uploadStatusText: String {
        return isUploaded ? "Yüklendi" : "Bekliyor"
    }
}