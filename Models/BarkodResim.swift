import Foundation

struct BarkodResim: Identifiable {
    let id: Int64
    let musteriAdi: String
    let resimYolu: String
    let tarih: Date
    let yukleyen: String
    let yuklendi: Bool
    
    init(id: Int64, musteriAdi: String, resimYolu: String, tarih: Date, yukleyen: String, yuklendi: Bool) {
        self.id = id
        self.musteriAdi = musteriAdi
        self.resimYolu = resimYolu
        self.tarih = tarih
        self.yukleyen = yukleyen
        self.yuklendi = yuklendi
    }
    
    var formattedTarih: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: tarih)
    }
} 