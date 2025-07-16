import Foundation

public struct VehicleProduct: Codable, Identifiable {
    let id: Int
    let musteriAdi: String
    let urunAdi: String
    let urunAdet: Int
    let depoAktaran: String
    let depoAktaranTarihi: String
    let mevcutDepo: String
    let prosap: String?
    let teslimEden: String?
    let teslimatDurumu: Int
    let sevkDurumu: Int
    let urunNotuDurum: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case musteriAdi = "musteri_adi"
        case urunAdi = "urun_adi"
        case urunAdet = "urun_adet"
        case depoAktaran = "depo_aktaran"
        case depoAktaranTarihi = "depo_aktaran_tarihi"
        case mevcutDepo = "mevcut_depo"
        case prosap
        case teslimEden = "teslim_eden"
        case teslimatDurumu = "teslimatdurumu"
        case sevkDurumu = "sevk_durumu"
        case urunNotuDurum = "urun_notu_durum"
    }
}

// MARK: - Response Models
public struct DeliveryResponse: Codable {
    let success: Bool
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
    }
}

public struct ReturnToDepotResponse: Codable {
    let success: Bool
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
    }
}

// MARK: - Helper Extensions
extension VehicleProduct {
    /// Müşteri adına göre gruplandırma için kullanılır
    var customerName: String {
        return musteriAdi
    }
    
    /// Ürün adeti text formatı
    var quantityText: String {
        return "\(urunAdet)"
    }
    
    /// Tarih formatı düzenleme
    var formattedDate: String {
        return depoAktaranTarihi
    }
} 