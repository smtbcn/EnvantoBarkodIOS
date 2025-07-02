import Foundation
import SQLite3

class DatabaseManager {
    
    // MARK: - Constants
    private static let TAG = "DatabaseManager"
    private static let DATABASE_NAME = "envanto_barcode.db"
    private static let DATABASE_VERSION = 1
    
    // Tablo ve kolon isimleri (Android ile aynı)
    public static let TABLE_BARKOD_RESIMLER = "barkod_resimler"
    public static let COLUMN_ID = "id"
    public static let COLUMN_MUSTERI_ADI = "musteri_adi"
    public static let COLUMN_RESIM_YOLU = "resim_yolu"
    public static let COLUMN_TARIH = "tarih"
    public static let COLUMN_YUKLEYEN = "yukleyen"
    public static let COLUMN_YUKLENDI = "yuklendi"
    
    // Cihaz yetkilendirme tablosu (Android ile aynı)
    public static let TABLE_CIHAZ_YETKI = "cihaz_yetki"
    public static let COLUMN_CIHAZ_ID = "id"
    public static let COLUMN_CIHAZ_BILGISI = "cihaz_bilgisi"
    public static let COLUMN_CIHAZ_SAHIBI = "cihaz_sahibi"
    public static let COLUMN_CIHAZ_ONAY = "cihaz_onay"
    public static let COLUMN_CIHAZ_SON_KONTROL = "son_kontrol"
    
    // MARK: - Database Properties
    private var db: OpaquePointer?
    private static var shared: DatabaseManager?
    
    // MARK: - Singleton Instance
    static func getInstance() -> DatabaseManager {
        if shared == nil {
            shared = DatabaseManager()
        }
        return shared!
    }
    
    // MARK: - Initialization
    private init() {
        openDatabase()
        createTables()
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Operations
    private func openDatabase() {
        guard let dbPath = getDatabasePath() else {
            print("❌ \(DatabaseManager.TAG): Database path alınamadı")
            return
        }
        
        print("📱 \(DatabaseManager.TAG): Database yolu: \(dbPath)")
        
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            print("✅ \(DatabaseManager.TAG): Database açıldı")
        } else {
            print("❌ \(DatabaseManager.TAG): Database açılamadı")
            db = nil
        }
    }
    
    private func closeDatabase() {
        if sqlite3_close(db) == SQLITE_OK {
            print("✅ \(DatabaseManager.TAG): Database kapatıldı")
        } else {
            print("❌ \(DatabaseManager.TAG): Database kapatılamadı")
        }
        db = nil
    }
    
    private func getDatabasePath() -> String? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, 
                                                          in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDir.appendingPathComponent(DatabaseManager.DATABASE_NAME).path
    }
    
    // MARK: - Create Tables (Android ile aynı yapı)
    private func createTables() {
        createBarkodResimlerTable()
        createCihazYetkiTable()
    }
    
    private func createBarkodResimlerTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(DatabaseManager.TABLE_BARKOD_RESIMLER) (
                \(DatabaseManager.COLUMN_ID) INTEGER PRIMARY KEY AUTOINCREMENT,
                \(DatabaseManager.COLUMN_MUSTERI_ADI) TEXT NOT NULL,
                \(DatabaseManager.COLUMN_RESIM_YOLU) TEXT NOT NULL,
                \(DatabaseManager.COLUMN_TARIH) TEXT NOT NULL,
                \(DatabaseManager.COLUMN_YUKLEYEN) TEXT NOT NULL,
                \(DatabaseManager.COLUMN_YUKLENDI) INTEGER DEFAULT 0
            )
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) == SQLITE_OK {
            print("✅ \(DatabaseManager.TAG): barkod_resimler tablosu oluşturuldu")
        } else {
            print("❌ \(DatabaseManager.TAG): barkod_resimler tablosu oluşturulamadı")
        }
    }
    
    private func createCihazYetkiTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(DatabaseManager.TABLE_CIHAZ_YETKI) (
                \(DatabaseManager.COLUMN_CIHAZ_ID) INTEGER PRIMARY KEY AUTOINCREMENT,
                \(DatabaseManager.COLUMN_CIHAZ_BILGISI) TEXT NOT NULL UNIQUE,
                \(DatabaseManager.COLUMN_CIHAZ_SAHIBI) TEXT NOT NULL,
                \(DatabaseManager.COLUMN_CIHAZ_ONAY) INTEGER DEFAULT 0,
                \(DatabaseManager.COLUMN_CIHAZ_SON_KONTROL) TEXT NOT NULL
            )
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) == SQLITE_OK {
            print("✅ \(DatabaseManager.TAG): cihaz_yetki tablosu oluşturuldu")
        } else {
            print("❌ \(DatabaseManager.TAG): cihaz_yetki tablosu oluşturulamadı")
        }
    }
    
    // MARK: - Insert Barkod Resim (Android metoduna benzer)
    func insertBarkodResim(musteriAdi: String, resimYolu: String, yukleyen: String) -> Bool {
        guard db != nil else {
            print("❌ \(DatabaseManager.TAG): Database bağlantısı yok")
            return false
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let tarih = dateFormatter.string(from: Date())
        
        let insertSQL = """
            INSERT INTO \(DatabaseManager.TABLE_BARKOD_RESIMLER) 
            (\(DatabaseManager.COLUMN_MUSTERI_ADI), \(DatabaseManager.COLUMN_RESIM_YOLU), 
             \(DatabaseManager.COLUMN_TARIH), \(DatabaseManager.COLUMN_YUKLEYEN), \(DatabaseManager.COLUMN_YUKLENDI)) 
            VALUES (?, ?, ?, ?, 0)
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, musteriAdi, -1, nil)
            sqlite3_bind_text(statement, 2, resimYolu, -1, nil)
            sqlite3_bind_text(statement, 3, tarih, -1, nil)
            sqlite3_bind_text(statement, 4, yukleyen, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ \(DatabaseManager.TAG): Barkod resim kaydedildi - Müşteri: \(musteriAdi)")
                sqlite3_finalize(statement)
                return true
            } else {
                print("❌ \(DatabaseManager.TAG): Barkod resim kaydedilemedi")
            }
        } else {
            print("❌ \(DatabaseManager.TAG): Insert sorgusu hazırlanamadı")
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    // MARK: - Get Uploaded Images Count
    func getUploadedImagesCount() -> Int {
        guard db != nil else { return 0 }
        
        let countSQL = "SELECT COUNT(*) FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER)"
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, countSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return count
    }
    
    // MARK: - Get Pending Upload Count (yuklendi = 0)
    func getPendingUploadCount() -> Int {
        guard db != nil else { return 0 }
        
        let countSQL = "SELECT COUNT(*) FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) WHERE \(DatabaseManager.COLUMN_YUKLENDI) = 0"
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, countSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return count
    }
    
    // MARK: - Get Customer Images (belirli müşterinin resimlerini getir)
    func getCustomerImages(musteriAdi: String) -> [BarkodResim] {
        guard db != nil else { return [] }
        
        let selectSQL = """
            SELECT \(DatabaseManager.COLUMN_ID), \(DatabaseManager.COLUMN_MUSTERI_ADI), 
                   \(DatabaseManager.COLUMN_RESIM_YOLU), \(DatabaseManager.COLUMN_TARIH), 
                   \(DatabaseManager.COLUMN_YUKLEYEN), \(DatabaseManager.COLUMN_YUKLENDI)
            FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) 
            WHERE \(DatabaseManager.COLUMN_MUSTERI_ADI) = ? 
            ORDER BY \(DatabaseManager.COLUMN_TARIH) DESC
        """
        
        var statement: OpaquePointer?
        var results: [BarkodResim] = []
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, musteriAdi, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let musteriAdi = String(cString: sqlite3_column_text(statement, 1))
                let resimYolu = String(cString: sqlite3_column_text(statement, 2))
                let tarih = String(cString: sqlite3_column_text(statement, 3))
                let yukleyen = String(cString: sqlite3_column_text(statement, 4))
                let yuklendi = Int(sqlite3_column_int(statement, 5))
                
                let barkodResim = BarkodResim(
                    id: id,
                    musteriAdi: musteriAdi,
                    resimYolu: resimYolu,
                    tarih: tarih,
                    yukleyen: yukleyen,
                    yuklendi: yuklendi
                )
                
                results.append(barkodResim)
            }
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    // MARK: - Get All Pending Images (yüklenmemiş tüm resimler)
    func getAllPendingImages() -> [BarkodResim] {
        guard db != nil else { return [] }
        
        let selectSQL = """
            SELECT \(DatabaseManager.COLUMN_ID), \(DatabaseManager.COLUMN_MUSTERI_ADI), 
                   \(DatabaseManager.COLUMN_RESIM_YOLU), \(DatabaseManager.COLUMN_TARIH), 
                   \(DatabaseManager.COLUMN_YUKLEYEN), \(DatabaseManager.COLUMN_YUKLENDI)
            FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) 
            WHERE \(DatabaseManager.COLUMN_YUKLENDI) = 0 
            ORDER BY \(DatabaseManager.COLUMN_TARIH) ASC
        """
        
        var statement: OpaquePointer?
        var results: [BarkodResim] = []
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let musteriAdi = String(cString: sqlite3_column_text(statement, 1))
                let resimYolu = String(cString: sqlite3_column_text(statement, 2))
                let tarih = String(cString: sqlite3_column_text(statement, 3))
                let yukleyen = String(cString: sqlite3_column_text(statement, 4))
                let yuklendi = Int(sqlite3_column_int(statement, 5))
                
                let barkodResim = BarkodResim(
                    id: id,
                    musteriAdi: musteriAdi,
                    resimYolu: resimYolu,
                    tarih: tarih,
                    yukleyen: yukleyen,
                    yuklendi: yuklendi
                )
                
                results.append(barkodResim)
            }
        }
        
        sqlite3_finalize(statement)
        print("📊 \(DatabaseManager.TAG): \(results.count) adet yüklenmemiş resim bulundu")
        return results
    }
    
    // MARK: - Clear All Barkod Resimler (Database temizleme)
    func clearAllBarkodResimler() -> Bool {
        guard db != nil else { return false }
        
        let deleteSQL = "DELETE FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER)"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                let deletedCount = sqlite3_changes(db)
                print("🗑️ \(DatabaseManager.TAG): \(deletedCount) adet barkod resim kaydı silindi")
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        print("❌ \(DatabaseManager.TAG): Barkod resim kayıtları silinemedi")
        return false
    }
    
    // MARK: - Clear Invalid Image Records (Dosyası olmayan kayıtları temizle)
    func clearInvalidImageRecords() -> Int {
        guard db != nil else { return 0 }
        
        let selectSQL = """
            SELECT \(DatabaseManager.COLUMN_ID), \(DatabaseManager.COLUMN_RESIM_YOLU)
            FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER)
        """
        
        var statement: OpaquePointer?
        var invalidIds: [Int] = []
        
        // Önce geçersiz kayıtları bul
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let resimYolu = String(cString: sqlite3_column_text(statement, 1))
                
                // Dosya mevcut mu kontrol et
                if !FileManager.default.fileExists(atPath: resimYolu) {
                    invalidIds.append(id)
                }
            }
        }
        sqlite3_finalize(statement)
        
        // Geçersiz kayıtları sil
        for id in invalidIds {
            let deleteSQL = "DELETE FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) WHERE \(DatabaseManager.COLUMN_ID) = ?"
            var deleteStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStatement, nil) == SQLITE_OK {
                sqlite3_bind_int(deleteStatement, 1, Int32(id))
                sqlite3_step(deleteStatement)
            }
            sqlite3_finalize(deleteStatement)
        }
        
        print("🧹 \(DatabaseManager.TAG): \(invalidIds.count) adet geçersiz resim kaydı temizlendi")
        return invalidIds.count
    }
    
    // MARK: - Update Image Path (Path güncelleme)
    func updateImagePath(id: Int, newPath: String) -> Bool {
        guard db != nil else { return false }
        
        let updateSQL = "UPDATE \(DatabaseManager.TABLE_BARKOD_RESIMLER) SET \(DatabaseManager.COLUMN_RESIM_YOLU) = ? WHERE \(DatabaseManager.COLUMN_ID) = ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, newPath, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(id))
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("🔄 \(DatabaseManager.TAG): Resim yolu güncellendi - ID: \(id)")
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    // MARK: - Delete Image Record
    func deleteBarkodResim(id: Int) -> Bool {
        guard db != nil else { return false }
        
        let deleteSQL = "DELETE FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) WHERE \(DatabaseManager.COLUMN_ID) = ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ \(DatabaseManager.TAG): Barkod resim kaydı silindi - ID: \(id)")
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    // MARK: - Update Upload Status
    func updateUploadStatus(id: Int, yuklendi: Int) -> Bool {
        guard db != nil else { return false }
        
        let updateSQL = "UPDATE \(DatabaseManager.TABLE_BARKOD_RESIMLER) SET \(DatabaseManager.COLUMN_YUKLENDI) = ? WHERE \(DatabaseManager.COLUMN_ID) = ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(yuklendi))
            sqlite3_bind_int(statement, 2, Int32(id))
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ \(DatabaseManager.TAG): Upload durumu güncellendi - ID: \(id), Durum: \(yuklendi)")
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    // MARK: - Update Yukleyen (Cihaz sahibi bilgisi güncellendiğinde)
    func updateYukleyenInfo(oldYukleyen: String, newYukleyen: String) -> Bool {
        guard db != nil, !newYukleyen.isEmpty else { return false }
        
        let updateSQL = "UPDATE \(DatabaseManager.TABLE_BARKOD_RESIMLER) SET \(DatabaseManager.COLUMN_YUKLEYEN) = ? WHERE \(DatabaseManager.COLUMN_YUKLEYEN) = ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, newYukleyen, -1, nil)
            sqlite3_bind_text(statement, 2, oldYukleyen, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                let changedRows = sqlite3_changes(db)
                print("✅ \(DatabaseManager.TAG): \(changedRows) kayıtta yukleyen bilgisi güncellendi")
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    // MARK: - Get Device Uploads (Belirli cihazın yüklediği resimler)
    func getDeviceUploads(yukleyen: String) -> [BarkodResim] {
        guard db != nil else { return [] }
        
        let selectSQL = """
            SELECT \(DatabaseManager.COLUMN_ID), \(DatabaseManager.COLUMN_MUSTERI_ADI), 
                   \(DatabaseManager.COLUMN_RESIM_YOLU), \(DatabaseManager.COLUMN_TARIH), 
                   \(DatabaseManager.COLUMN_YUKLEYEN), \(DatabaseManager.COLUMN_YUKLENDI)
            FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) 
            WHERE \(DatabaseManager.COLUMN_YUKLEYEN) = ? 
            ORDER BY \(DatabaseManager.COLUMN_TARIH) DESC
        """
        
        var statement: OpaquePointer?
        var results: [BarkodResim] = []
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, yukleyen, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let musteriAdi = String(cString: sqlite3_column_text(statement, 1))
                let resimYolu = String(cString: sqlite3_column_text(statement, 2))
                let tarih = String(cString: sqlite3_column_text(statement, 3))
                let yukleyen = String(cString: sqlite3_column_text(statement, 4))
                let yuklendi = Int(sqlite3_column_int(statement, 5))
                
                let barkodResim = BarkodResim(
                    id: id,
                    musteriAdi: musteriAdi,
                    resimYolu: resimYolu,
                    tarih: tarih,
                    yukleyen: yukleyen,
                    yuklendi: yuklendi
                )
                
                results.append(barkodResim)
            }
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    // MARK: - Cihaz Yetki Yönetimi (Android ile aynı)
    func saveCihazYetki(cihazBilgisi: String, cihazSahibi: String, cihazOnay: Int) -> Bool {
        guard db != nil else { return false }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let sonKontrol = dateFormatter.string(from: Date())
        
        // Önce mevcut kaydı kontrol et
        if var existingRecord = getCihazYetki(cihazBilgisi: cihazBilgisi) {
            // Güncelle
            let updateSQL = """
                UPDATE \(DatabaseManager.TABLE_CIHAZ_YETKI) 
                SET \(DatabaseManager.COLUMN_CIHAZ_SAHIBI) = ?, 
                    \(DatabaseManager.COLUMN_CIHAZ_ONAY) = ?, 
                    \(DatabaseManager.COLUMN_CIHAZ_SON_KONTROL) = ?
                WHERE \(DatabaseManager.COLUMN_CIHAZ_BILGISI) = ?
            """
            
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, cihazSahibi, -1, nil)
                sqlite3_bind_int(statement, 2, Int32(cihazOnay))
                sqlite3_bind_text(statement, 3, sonKontrol, -1, nil)
                sqlite3_bind_text(statement, 4, cihazBilgisi, -1, nil)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    print("✅ \(DatabaseManager.TAG): Cihaz yetki güncellendi - \(cihazBilgisi)")
                    sqlite3_finalize(statement)
                    return true
                }
            }
            sqlite3_finalize(statement)
        } else {
            // Yeni kayıt ekle
            let insertSQL = """
                INSERT INTO \(DatabaseManager.TABLE_CIHAZ_YETKI) 
                (\(DatabaseManager.COLUMN_CIHAZ_BILGISI), \(DatabaseManager.COLUMN_CIHAZ_SAHIBI), 
                 \(DatabaseManager.COLUMN_CIHAZ_ONAY), \(DatabaseManager.COLUMN_CIHAZ_SON_KONTROL)) 
                VALUES (?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, cihazBilgisi, -1, nil)
                sqlite3_bind_text(statement, 2, cihazSahibi, -1, nil)
                sqlite3_bind_int(statement, 3, Int32(cihazOnay))
                sqlite3_bind_text(statement, 4, sonKontrol, -1, nil)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    print("✅ \(DatabaseManager.TAG): Yeni cihaz yetki kaydı eklendi - \(cihazBilgisi)")
                    sqlite3_finalize(statement)
                    return true
                }
            }
            sqlite3_finalize(statement)
        }
        
        return false
    }
    
    func getCihazYetki(cihazBilgisi: String) -> CihazYetki? {
        guard db != nil else { return nil }
        
        let selectSQL = """
            SELECT \(DatabaseManager.COLUMN_CIHAZ_ID), \(DatabaseManager.COLUMN_CIHAZ_BILGISI), 
                   \(DatabaseManager.COLUMN_CIHAZ_SAHIBI), \(DatabaseManager.COLUMN_CIHAZ_ONAY), 
                   \(DatabaseManager.COLUMN_CIHAZ_SON_KONTROL)
            FROM \(DatabaseManager.TABLE_CIHAZ_YETKI) 
            WHERE \(DatabaseManager.COLUMN_CIHAZ_BILGISI) = ? 
            LIMIT 1
        """
        
        var statement: OpaquePointer?
        var result: CihazYetki?
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, cihazBilgisi, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let cihazBilgisi = String(cString: sqlite3_column_text(statement, 1))
                let cihazSahibi = String(cString: sqlite3_column_text(statement, 2))
                let cihazOnay = Int(sqlite3_column_int(statement, 3))
                let sonKontrol = String(cString: sqlite3_column_text(statement, 4))
                
                result = CihazYetki(
                    id: id,
                    cihazBilgisi: cihazBilgisi,
                    cihazSahibi: cihazSahibi,
                    cihazOnay: cihazOnay,
                    sonKontrol: sonKontrol
                )
            }
        }
        
        sqlite3_finalize(statement)
        return result
    }
    
    func getCihazSahibi(cihazBilgisi: String) -> String {
        if let cihazYetki = getCihazYetki(cihazBilgisi: cihazBilgisi) {
            return cihazYetki.cihazSahibi
        }
        return ""
    }
    
    func isCihazYetkili(cihazBilgisi: String) -> Bool {
        if let cihazYetki = getCihazYetki(cihazBilgisi: cihazBilgisi) {
            return cihazYetki.cihazOnay == 1
        }
        return false
    }
    
    // MARK: - Debug Methods
    func printDatabaseInfo() {
        let totalCount = getUploadedImagesCount()
        let pendingCount = getPendingUploadCount()
        
        print("📊 \(DatabaseManager.TAG): Toplam resim: \(totalCount)")
        print("📊 \(DatabaseManager.TAG): Bekleyen yükleme: \(pendingCount)")
        print("📊 \(DatabaseManager.TAG): Tamamlanan yükleme: \(totalCount - pendingCount)")
        
        // Cihaz sahibi bilgisini de göster
        let currentDeviceOwner = UserDefaults.standard.string(forKey: "device_owner") ?? "Belirtilmemiş"
        print("👤 \(DatabaseManager.TAG): Aktif cihaz sahibi: \(currentDeviceOwner)")
        
        // Cihaz yetki durumunu da göster
        let deviceId = DeviceIdentifier.getUniqueDeviceId()
        if let cihazYetki = getCihazYetki(cihazBilgisi: deviceId) {
            print("🔐 \(DatabaseManager.TAG): Cihaz onay durumu: \(cihazYetki.cihazOnay == 1 ? "Yetkili" : "Yetkisiz")")
        } else {
            print("🔐 \(DatabaseManager.TAG): Cihaz yetki kaydı bulunamadı")
        }
        
        if let dbPath = getDatabasePath() {
            print("📁 \(DatabaseManager.TAG): Database dosyası: \(dbPath)")
        }
    }
}

// MARK: - BarkodResim Model (Android'deki model ile aynı)
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

// MARK: - CihazYetki Model (Android'deki model ile aynı)
struct CihazYetki: Identifiable {
    let id: Int
    let cihazBilgisi: String
    let cihazSahibi: String
    let cihazOnay: Int
    let sonKontrol: String
    
    var isAuthorized: Bool {
        return cihazOnay == 1
    }
    
    var statusText: String {
        return isAuthorized ? "Yetkili" : "Yetkisiz"
    }
} 