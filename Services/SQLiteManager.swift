import Foundation
import SQLite3

// MARK: - SQLiteManager (Android DatabaseHelper.java iOS port)
class SQLiteManager {
    static let shared = SQLiteManager()
    
    private var db: OpaquePointer?
    private let dbName = "BarkodDB.sqlite"
    
    // Tablo ve kolon isimleri (Android ile aynı)
    static let TABLE_BARKOD_RESIMLER = "barkod_resimler"
    static let TABLE_MUSTERILER = "musteriler"
    
    static let COLUMN_ID = "id"
    static let COLUMN_MUSTERI_ADI = "musteri_adi"
    static let COLUMN_RESIM_YOLU = "resim_yolu"
    static let COLUMN_TARIH = "tarih"
    static let COLUMN_YUKLEYEN = "yukleyen"
    static let COLUMN_YUKLENDI = "yuklendi"
    
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
        // Barkod Resimleri Tablosu
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
        
        // Müşteriler Tablosu
        let createMusterilerTable = """
        CREATE TABLE IF NOT EXISTS \(SQLiteManager.TABLE_MUSTERILER) (
            \(SQLiteManager.COLUMN_ID) INTEGER PRIMARY KEY AUTOINCREMENT,
            \(SQLiteManager.COLUMN_MUSTERI_ADI) TEXT NOT NULL UNIQUE
        )
        """
        
        sqlite3_exec(db, createBarkodTable, nil, nil, nil)
        sqlite3_exec(db, createMusterilerTable, nil, nil, nil)
    }
    
    // MARK: - Barkod Resim İşlemleri (Android uyumlu)
    
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
    
    // MARK: - Müşteri Cache İşlemleri (Android uyumlu)
    
    func cacheMusteriler(_ customers: [String]) {
        // Önce mevcut cache'i temizle
        let deleteSQL = "DELETE FROM \(SQLiteManager.TABLE_MUSTERILER)"
        sqlite3_exec(db, deleteSQL, nil, nil, nil)
        
        // Yeni müşterileri ekle
        let insertSQL = """
        INSERT INTO \(SQLiteManager.TABLE_MUSTERILER) 
        (\(SQLiteManager.COLUMN_MUSTERI_ADI))
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
        SELECT \(SQLiteManager.COLUMN_MUSTERI_ADI)
        FROM \(SQLiteManager.TABLE_MUSTERILER)
        WHERE \(SQLiteManager.COLUMN_MUSTERI_ADI) LIKE ?
        ORDER BY \(SQLiteManager.COLUMN_MUSTERI_ADI) ASC
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
}