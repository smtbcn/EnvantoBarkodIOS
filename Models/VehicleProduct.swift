import Foundation

public struct VehicleProduct: Codable, Identifiable {
    public let id: Int
    public let musteriAdi: String
    public let urunAdi: String
    public let urunAdet: Int
    public let depoAktaran: String
    public let depoAktaranTarihi: String
    public let mevcutDepo: String
    public let prosap: String?
    public let teslimEden: String?
    public let teslimatDurumu: Int
    public let sevkDurumu: Int
    public let urunNotuDurum: Int
    
    public init(id: Int, musteriAdi: String, urunAdi: String, urunAdet: Int, depoAktaran: String, depoAktaranTarihi: String, mevcutDepo: String, prosap: String?, teslimEden: String?, teslimatDurumu: Int, sevkDurumu: Int, urunNotuDurum: Int) {
        self.id = id
        self.musteriAdi = musteriAdi
        self.urunAdi = urunAdi
        self.urunAdet = urunAdet
        self.depoAktaran = depoAktaran
        self.depoAktaranTarihi = depoAktaranTarihi
        self.mevcutDepo = mevcutDepo
        self.prosap = prosap
        self.teslimEden = teslimEden
        self.teslimatDurumu = teslimatDurumu
        self.sevkDurumu = sevkDurumu
        self.urunNotuDurum = urunNotuDurum
    }
    
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
    public let success: Bool
    public let message: String
    
    public init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
    }
}

public struct ReturnToDepotResponse: Codable {
    public let success: Bool
    public let message: String
    
    public init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
    }
}

// MARK: - Helper Extensions
public extension VehicleProduct {
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