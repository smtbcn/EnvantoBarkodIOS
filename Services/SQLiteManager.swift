import Foundation
import SQLite3

// MARK: - SQLiteManager (Android DatabaseHelper.java birebir iOS port)
class SQLiteManager {
    static let shared = SQLiteManager()
    
    private var db: OpaquePointer?
    private let dbName = "BarkodDB.sqlite" // Android ile aynı
    private let dbVersion = 5 // Android ile aynı DATABASE_VERSION
    
    // Tablo ve kolon isimleri (Android DatabaseHelper ile birebir aynı)
    static let TABLE_BARKOD_RESIMLER = "barkod_resimler"
    static let TABLE_MUSTERI_RESIMLER = "musteri_resimler" // Android'de yeni eklenen
    static let TABLE_MUSTERILER = "musteriler"
    static let TABLE_CIHAZ_YETKI = "cihaz_yetki" // Android'deki cihaz yetkilendirme tablosu
    
    // Ortak kolonlar
    static let COLUMN_ID = "id"
    static let COLUMN_MUSTERI_ADI = "musteri_adi"
    static let COLUMN_RESIM_YOLU = "resim_yolu"
    static let COLUMN_TARIH = "tarih"
    static let COLUMN_YUKLEYEN = "yukleyen"
    static let COLUMN_YUKLENDI = "yuklendi"
    
    // Müşteriler tablosu kolonları
    static let COLUMN_MUSTERI_ID = "id"
    static let COLUMN_MUSTERI = "musteri_adi"
    static let COLUMN_SON_GUNCELLEME = "son_guncelleme"
    
    // Cihaz yetkilendirme tablosu kolonları (Android ile aynı)
    static let COLUMN_CIHAZ_ID = "id"
    static let COLUMN_CIHAZ_BILGISI = "cihaz_bilgisi"
    static let COLUMN_CIHAZ_SAHIBI = "cihaz_sahibi"
    static let COLUMN_CIHAZ_ONAY = "cihaz_onay"
    static let COLUMN_CIHAZ_SON_KONTROL = "son_kontrol"
    
    private init() {
        openDatabase()
        createTables()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - Database Setup
    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(dbName)
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Unable to open database")
        }
    }
    
    private func createTables() {
        // Android CREATE_TABLE_BARKOD_RESIMLER ile birebir aynı
        let createBarkodTable = """
        CREATE TABLE IF NOT EXISTS \(SQLiteManager.TABLE_BARKOD_RESIMLER) (
            \(SQLiteManager.COLUMN_ID) INTEGER PRIMARY KEY AUTOINCREMENT,
            \(SQLiteManager.COLUMN_MUSTERI_ADI) TEXT NOT NULL,
            \(SQLiteManager.COLUMN_RESIM_YOLU) TEXT NOT NULL,
            \(SQLiteManager.COLUMN_TARIH) DATETIME DEFAULT CURRENT_TIMESTAMP,
            \(SQLiteManager.COLUMN_YUKLEYEN) TEXT,
            \(SQLiteManager.COLUMN_YUKLENDI) INTEGER DEFAULT 0
        )
        """
        
        // Android CREATE_TABLE_MUSTERI_RESIMLER ile birebir aynı (barkod_resimler'in kopyası)
        let createMusteriResimlerTable = """
        CREATE TABLE IF NOT EXISTS \(SQLiteManager.TABLE_MUSTERI_RESIMLER) (
            \(SQLiteManager.COLUMN_ID) INTEGER PRIMARY KEY AUTOINCREMENT,
            \(SQLiteManager.COLUMN_MUSTERI_ADI) TEXT NOT NULL,
            \(SQLiteManager.COLUMN_RESIM_YOLU) TEXT NOT NULL,
            \(SQLiteManager.COLUMN_TARIH) DATETIME DEFAULT CURRENT_TIMESTAMP,
            \(SQLiteManager.COLUMN_YUKLEYEN) TEXT,
            \(SQLiteManager.COLUMN_YUKLENDI) INTEGER DEFAULT 0
        )
        """
        
        // Android CREATE_TABLE_MUSTERILER ile birebir aynı
        let createMusterilerTable = """
        CREATE TABLE IF NOT EXISTS \(SQLiteManager.TABLE_MUSTERILER) (
            \(SQLiteManager.COLUMN_MUSTERI_ID) INTEGER PRIMARY KEY AUTOINCREMENT,
            \(SQLiteManager.COLUMN_MUSTERI) TEXT NOT NULL UNIQUE,
            \(SQLiteManager.COLUMN_SON_GUNCELLEME) DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        """
        
        // Android CREATE_TABLE_CIHAZ_YETKI ile birebir aynı
        let createCihazYetkiTable = """
        CREATE TABLE IF NOT EXISTS \(SQLiteManager.TABLE_CIHAZ_YETKI) (
            \(SQLiteManager.COLUMN_CIHAZ_ID) INTEGER PRIMARY KEY AUTOINCREMENT,
            \(SQLiteManager.COLUMN_CIHAZ_BILGISI) TEXT NOT NULL UNIQUE,
            \(SQLiteManager.COLUMN_CIHAZ_SAHIBI) TEXT,
            \(SQLiteManager.COLUMN_CIHAZ_ONAY) INTEGER DEFAULT 0,
            \(SQLiteManager.COLUMN_CIHAZ_SON_KONTROL) DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        """
        
        sqlite3_exec(db, createBarkodTable, nil, nil, nil)
        sqlite3_exec(db, createMusteriResimlerTable, nil, nil, nil)
        sqlite3_exec(db, createMusterilerTable, nil, nil, nil)
        sqlite3_exec(db, createCihazYetkiTable, nil, nil, nil)
    }
    
    // MARK: - Barkod Resim İşlemleri (Android DatabaseHelper ile birebir aynı)
    
    func addBarkodResim(musteriAdi: String, resimYolu: String, yukleyen: String) -> Int64 {
        let insertSQL = """
        INSERT INTO \(SQLiteManager.TABLE_BARKOD_RESIMLER) 
        (\(SQLiteManager.COLUMN_MUSTERI_ADI), \(SQLiteManager.COLUMN_RESIM_YOLU), \(SQLiteManager.COLUMN_YUKLEYEN), \(SQLiteManager.COLUMN_YUKLENDI))
        VALUES (?, ?, ?, 0)
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, musteriAdi, -1, nil)
            sqlite3_bind_text(statement, 2, resimYolu, -1, nil)
            sqlite3_bind_text(statement, 3, yukleyen, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                let rowID = sqlite3_last_insert_rowid(db)
                sqlite3_finalize(statement)
                return rowID
            }
        }
        
        sqlite3_finalize(statement)
        return -1
    }
    
    func updateUploadStatus(resimYolu: String, yuklendi: Bool) -> Bool {
        let updateSQL = """
        UPDATE \(SQLiteManager.TABLE_BARKOD_RESIMLER)
        SET \(SQLiteManager.COLUMN_YUKLENDI) = ?
        WHERE \(SQLiteManager.COLUMN_RESIM_YOLU) = ?
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, yuklendi ? 1 : 0)
            sqlite3_bind_text(statement, 2, resimYolu, -1, nil)
            
            let result = sqlite3_step(statement) == SQLITE_DONE
            sqlite3_finalize(statement)
            return result
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    func getAllPendingUploads() -> [(id: Int, musteriAdi: String, resimYolu: String, tarih: String, yukleyen: String)] {
        let querySQL = """
        SELECT \(SQLiteManager.COLUMN_ID), \(SQLiteManager.COLUMN_MUSTERI_ADI), \(SQLiteManager.COLUMN_RESIM_YOLU), 
               \(SQLiteManager.COLUMN_TARIH), \(SQLiteManager.COLUMN_YUKLEYEN)
        FROM \(SQLiteManager.TABLE_BARKOD_RESIMLER)
        WHERE \(SQLiteManager.COLUMN_YUKLENDI) = 0
        ORDER BY \(SQLiteManager.COLUMN_TARIH) ASC
        """
        
        var statement: OpaquePointer?
        var results: [(id: Int, musteriAdi: String, resimYolu: String, tarih: String, yukleyen: String)] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let musteriAdi = String(cString: sqlite3_column_text(statement, 1))
                let resimYolu = String(cString: sqlite3_column_text(statement, 2))
                let tarih = String(cString: sqlite3_column_text(statement, 3))
                let yukleyen = sqlite3_column_text(statement, 4) != nil ? String(cString: sqlite3_column_text(statement, 4)) : ""
                
                results.append((id: id, musteriAdi: musteriAdi, resimYolu: resimYolu, tarih: tarih, yukleyen: yukleyen))
            }
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    // MARK: - Müşteri Cache İşlemleri (Android DatabaseHelper ile birebir aynı)
    
    func cacheMusteriler(_ customers: [String]) {
        // Önce mevcut cache'i temizle
        let deleteSQL = "DELETE FROM \(SQLiteManager.TABLE_MUSTERILER)"
        sqlite3_exec(db, deleteSQL, nil, nil, nil)
        
        // Yeni müşterileri ekle
        let insertSQL = """
        INSERT INTO \(SQLiteManager.TABLE_MUSTERILER) 
        (\(SQLiteManager.COLUMN_MUSTERI))
        VALUES (?)
        """
        
        for customer in customers {
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, customer, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
        
        // Son güncelleme zamanını kaydet
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "last_customer_update")
    }
    
    func searchCachedMusteriler(query: String) -> [String] {
        let querySQL = """
        SELECT \(SQLiteManager.COLUMN_MUSTERI)
        FROM \(SQLiteManager.TABLE_MUSTERILER)
        WHERE \(SQLiteManager.COLUMN_MUSTERI) LIKE ?
        ORDER BY \(SQLiteManager.COLUMN_MUSTERI) ASC
        LIMIT 50
        """
        
        var statement: OpaquePointer?
        var results: [String] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            let searchPattern = "%\(query)%"
            sqlite3_bind_text(statement, 1, searchPattern, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let musteriAdi = sqlite3_column_text(statement, 0) {
                    results.append(String(cString: musteriAdi))
                }
            }
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    func getCachedMusteriCount() -> Int {
        let querySQL = "SELECT COUNT(*) FROM \(SQLiteManager.TABLE_MUSTERILER)"
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return count
    }
    
    func getUploadedCustomers() -> [String] {
        let querySQL = """
        SELECT DISTINCT \(SQLiteManager.COLUMN_MUSTERI_ADI)
        FROM \(SQLiteManager.TABLE_BARKOD_RESIMLER)
        ORDER BY \(SQLiteManager.COLUMN_MUSTERI_ADI) ASC
        """
        
        var statement: OpaquePointer?
        var results: [String] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let musteriAdi = sqlite3_column_text(statement, 0) {
                    results.append(String(cString: musteriAdi))
                }
            }
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    func getCustomerImageCount(musteriAdi: String) -> Int {
        let querySQL = """
        SELECT COUNT(*)
        FROM \(SQLiteManager.TABLE_BARKOD_RESIMLER)
        WHERE \(SQLiteManager.COLUMN_MUSTERI_ADI) = ?
        """
        
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, musteriAdi, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return count
    }
    
    // MARK: - Cihaz Yetkilendirme İşlemleri (Android DatabaseHelper ile birebir aynı)
    
    func saveCihazYetki(cihazBilgisi: String, cihazSahibi: String, cihazOnay: Int) -> Bool {
        // Önce var mı kontrol et
        let checkSQL = """
        SELECT \(SQLiteManager.COLUMN_CIHAZ_ID)
        FROM \(SQLiteManager.TABLE_CIHAZ_YETKI)
        WHERE \(SQLiteManager.COLUMN_CIHAZ_BILGISI) = ?
        """
        
        var checkStatement: OpaquePointer?
        var exists = false
        
        if sqlite3_prepare_v2(db, checkSQL, -1, &checkStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(checkStatement, 1, cihazBilgisi, -1, nil)
            if sqlite3_step(checkStatement) == SQLITE_ROW {
                exists = true
            }
        }
        sqlite3_finalize(checkStatement)
        
        let currentTimestamp = getCurrentTimestamp()
        
        if exists {
            // Varsa güncelle
            let updateSQL = """
            UPDATE \(SQLiteManager.TABLE_CIHAZ_YETKI)
            SET \(SQLiteManager.COLUMN_CIHAZ_SAHIBI) = ?, 
                \(SQLiteManager.COLUMN_CIHAZ_ONAY) = ?,
                \(SQLiteManager.COLUMN_CIHAZ_SON_KONTROL) = ?
            WHERE \(SQLiteManager.COLUMN_CIHAZ_BILGISI) = ?
            """
            
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, cihazSahibi, -1, nil)
                sqlite3_bind_int(statement, 2, Int32(cihazOnay))
                sqlite3_bind_text(statement, 3, currentTimestamp, -1, nil)
                sqlite3_bind_text(statement, 4, cihazBilgisi, -1, nil)
                
                let result = sqlite3_step(statement) == SQLITE_DONE
                sqlite3_finalize(statement)
                return result
            }
            sqlite3_finalize(statement)
        } else {
            // Yoksa ekle
            let insertSQL = """
            INSERT INTO \(SQLiteManager.TABLE_CIHAZ_YETKI)
            (\(SQLiteManager.COLUMN_CIHAZ_BILGISI), \(SQLiteManager.COLUMN_CIHAZ_SAHIBI), \(SQLiteManager.COLUMN_CIHAZ_ONAY), \(SQLiteManager.COLUMN_CIHAZ_SON_KONTROL))
            VALUES (?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, cihazBilgisi, -1, nil)
                sqlite3_bind_text(statement, 2, cihazSahibi, -1, nil)
                sqlite3_bind_int(statement, 3, Int32(cihazOnay))
                sqlite3_bind_text(statement, 4, currentTimestamp, -1, nil)
                
                let result = sqlite3_step(statement) == SQLITE_DONE
                sqlite3_finalize(statement)
                return result
            }
            sqlite3_finalize(statement)
        }
        
        return false
    }
    
    func getCihazYetki(cihazBilgisi: String) -> (cihazSahibi: String, cihazOnay: Int, sonKontrol: String)? {
        let querySQL = """
        SELECT \(SQLiteManager.COLUMN_CIHAZ_SAHIBI), \(SQLiteManager.COLUMN_CIHAZ_ONAY), \(SQLiteManager.COLUMN_CIHAZ_SON_KONTROL)
        FROM \(SQLiteManager.TABLE_CIHAZ_YETKI)
        WHERE \(SQLiteManager.COLUMN_CIHAZ_BILGISI) = ?
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, cihazBilgisi, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let cihazSahibi = sqlite3_column_text(statement, 0) != nil ? String(cString: sqlite3_column_text(statement, 0)) : ""
                let cihazOnay = Int(sqlite3_column_int(statement, 1))
                let sonKontrol = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)) : ""
                
                sqlite3_finalize(statement)
                return (cihazSahibi: cihazSahibi, cihazOnay: cihazOnay, sonKontrol: sonKontrol)
            }
        }
        
        sqlite3_finalize(statement)
        return nil
    }
    
    func isCihazOnaylanmis(cihazBilgisi: String) -> Bool {
        if let cihazYetki = getCihazYetki(cihazBilgisi: cihazBilgisi) {
            return cihazYetki.cihazOnay == 1
        }
        return false
    }
    
    func getCihazSahibi(cihazBilgisi: String) -> String {
        if let cihazYetki = getCihazYetki(cihazBilgisi: cihazBilgisi) {
            return cihazYetki.cihazSahibi
        }
        return ""
    }
    
    // MARK: - Müşteri Resimleri İşlemleri (Android DatabaseHelper ile birebir aynı)
    
    func addMusteriResim(musteriAdi: String, resimYolu: String, yukleyen: String) -> Int64 {
        let insertSQL = """
        INSERT INTO \(SQLiteManager.TABLE_MUSTERI_RESIMLER) 
        (\(SQLiteManager.COLUMN_MUSTERI_ADI), \(SQLiteManager.COLUMN_RESIM_YOLU), \(SQLiteManager.COLUMN_YUKLEYEN), \(SQLiteManager.COLUMN_YUKLENDI))
        VALUES (?, ?, ?, 0)
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, musteriAdi, -1, nil)
            sqlite3_bind_text(statement, 2, resimYolu, -1, nil)
            sqlite3_bind_text(statement, 3, yukleyen, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                let rowID = sqlite3_last_insert_rowid(db)
                sqlite3_finalize(statement)
                return rowID
            }
        }
        
        sqlite3_finalize(statement)
        return -1
    }
    
    func getMusteriResimleriByCustomer(musteriAdi: String) -> [(id: Int, resimYolu: String, tarih: String)] {
        let querySQL = """
        SELECT \(SQLiteManager.COLUMN_ID), \(SQLiteManager.COLUMN_RESIM_YOLU), \(SQLiteManager.COLUMN_TARIH)
        FROM \(SQLiteManager.TABLE_MUSTERI_RESIMLER)
        WHERE \(SQLiteManager.COLUMN_MUSTERI_ADI) = ?
        ORDER BY \(SQLiteManager.COLUMN_TARIH) DESC
        """
        
        var statement: OpaquePointer?
        var results: [(id: Int, resimYolu: String, tarih: String)] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, musteriAdi, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let resimYolu = String(cString: sqlite3_column_text(statement, 1))
                let tarih = String(cString: sqlite3_column_text(statement, 2))
                
                results.append((id: id, resimYolu: resimYolu, tarih: tarih))
            }
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    func getMusteriResimCount(musteriAdi: String) -> Int {
        let querySQL = """
        SELECT COUNT(*)
        FROM \(SQLiteManager.TABLE_MUSTERI_RESIMLER)
        WHERE \(SQLiteManager.COLUMN_MUSTERI_ADI) = ?
        """
        
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, musteriAdi, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return count
    }
    
    func getUploadedMusteriCustomers() -> [String] {
        let querySQL = """
        SELECT DISTINCT \(SQLiteManager.COLUMN_MUSTERI_ADI)
        FROM \(SQLiteManager.TABLE_MUSTERI_RESIMLER)
        ORDER BY \(SQLiteManager.COLUMN_MUSTERI_ADI) ASC
        """
        
        var statement: OpaquePointer?
        var results: [String] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let musteriAdi = sqlite3_column_text(statement, 0) {
                    results.append(String(cString: musteriAdi))
                }
            }
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}