import Foundation
import SQLite3

// MARK: - SQLiteManager (Android DatabaseHelper.java iOS port)
class SQLiteManager {
    static let shared = SQLiteManager()
    
    private var db: OpaquePointer?
    
    // MARK: - Constants
    private static let DATABASE_NAME = "BarkodDB"
    
    // Table Names
    private static let TABLE_BARKOD_RESIMLER = "barkod_resimler"
    private static let TABLE_MUSTERILER = "musteriler"
    
    // Column Names
    private static let COLUMN_ID = "id"
    private static let COLUMN_MUSTERI_ADI = "musteri_adi"
    private static let COLUMN_RESIM_YOLU = "resim_yolu"
    private static let COLUMN_TARIH = "tarih"
    private static let COLUMN_YUKLEYEN = "yukleyen"
    private static let COLUMN_YUKLENDI = "yuklendi"
    
    private init() {
        // Documents/EnvantoBarkod/database.db
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let appDirectory = documentsPath.appendingPathComponent("EnvantoBarkod")
        let dbPath = appDirectory.appendingPathComponent("database.db")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        
        print("📱 Database path: \(dbPath.path)")
        
        if sqlite3_open(dbPath.path, &db) == SQLITE_OK {
            print("✅ Database opened successfully")
            createTables()
        } else {
            print("❌ Error opening database")
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func createTables() {
        // Android'deki gibi barkod_resimler tablosu
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS barkod_resimler (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            musteri_adi TEXT,
            resim_yolu TEXT,
            tarih DATETIME DEFAULT CURRENT_TIMESTAMP,
            yukleyen TEXT,
            yuklendi INTEGER DEFAULT 0
        );
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Table created successfully")
            } else {
                print("❌ Error creating table")
            }
        } else {
            print("❌ Error preparing create table statement")
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Barkod Resim İşlemleri
    func addBarkodResim(musteriAdi: String, resimYolu: String, yukleyen: String) -> Int64 {
        let insertSQL = """
        INSERT INTO barkod_resimler (musteri_adi, resim_yolu, yukleyen)
        VALUES (?, ?, ?);
        """
        
        var statement: OpaquePointer?
        var lastId: Int64 = 0
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (musteriAdi as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (resimYolu as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (yukleyen as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                lastId = sqlite3_last_insert_rowid(db)
                print("✅ Image record added successfully: \(lastId)")
            } else {
                print("❌ Error adding image record")
            }
        } else {
            print("❌ Error preparing insert statement")
        }
        
        sqlite3_finalize(statement)
        return lastId
    }
    
    func updateBarkodResimStatus(resimYolu: String, yuklendi: Bool) {
        let updateSQL = """
        UPDATE barkod_resimler
        SET yuklendi = ?
        WHERE resim_yolu = ?;
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, yuklendi ? 1 : 0)
            sqlite3_bind_text(statement, 2, (resimYolu as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Image status updated successfully")
            } else {
                print("❌ Error updating image status")
            }
        } else {
            print("❌ Error preparing update statement")
        }
        
        sqlite3_finalize(statement)
    }
    
    func getUnuploadedImages() -> [(id: Int64, musteriAdi: String, resimYolu: String, yukleyen: String)] {
        var images: [(id: Int64, musteriAdi: String, resimYolu: String, yukleyen: String)] = []
        
        let selectSQL = """
        SELECT id, musteri_adi, resim_yolu, yukleyen
        FROM barkod_resimler
        WHERE yuklendi = 0
        ORDER BY tarih ASC;
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int64(statement, 0)
                let musteriAdi = String(cString: sqlite3_column_text(statement, 1))
                let resimYolu = String(cString: sqlite3_column_text(statement, 2))
                let yukleyen = String(cString: sqlite3_column_text(statement, 3))
                
                images.append((id: id, musteriAdi: musteriAdi, resimYolu: resimYolu, yukleyen: yukleyen))
            }
        }
        
        sqlite3_finalize(statement)
        return images
    }
    
    func getCustomerImages(musteriAdi: String) -> [(resimYolu: String, yuklendi: Bool)] {
        var images: [(resimYolu: String, yuklendi: Bool)] = []
        
        let selectSQL = """
        SELECT resim_yolu, yuklendi
        FROM barkod_resimler
        WHERE musteri_adi = ?
        ORDER BY tarih DESC;
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (musteriAdi as NSString).utf8String, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let resimYolu = String(cString: sqlite3_column_text(statement, 0))
                let yuklendi = sqlite3_column_int(statement, 1) == 1
                
                images.append((resimYolu: resimYolu, yuklendi: yuklendi))
            }
        }
        
        sqlite3_finalize(statement)
        return images
    }
    
    func deleteImage(resimYolu: String) {
        let deleteSQL = """
        DELETE FROM barkod_resimler
        WHERE resim_yolu = ?;
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (resimYolu as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Image record deleted successfully")
                // Also delete the file
                try? FileManager.default.removeItem(atPath: resimYolu)
            } else {
                print("❌ Error deleting image record")
            }
        } else {
            print("❌ Error preparing delete statement")
        }
        
        sqlite3_finalize(statement)
    }
    
    func getCustomerList() -> [String] {
        var customers: [String] = []
        
        let selectSQL = """
        SELECT DISTINCT musteri_adi
        FROM barkod_resimler
        ORDER BY musteri_adi;
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let musteriAdi = String(cString: sqlite3_column_text(statement, 0))
                customers.append(musteriAdi)
            }
        }
        
        sqlite3_finalize(statement)
        return customers
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
                sqlite3_bind_text(statement, 1, (customer as NSString).utf8String, -1, nil)
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
            sqlite3_bind_text(statement, 1, (searchPattern as NSString).utf8String, -1, nil)
            
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
}