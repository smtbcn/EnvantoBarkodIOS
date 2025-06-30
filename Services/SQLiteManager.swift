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
            print("❌ Database open error: \(String(cString: sqlite3_errmsg(db)))")
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func createTables() {
        // Android'deki gibi barkod_resimler tablosu
        let barcodeImagesSQL = """
            CREATE TABLE IF NOT EXISTS barkod_resimler (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                musteri_adi TEXT NOT NULL,
                resim_yolu TEXT NOT NULL,
                tarih DATETIME DEFAULT CURRENT_TIMESTAMP,
                yukleyen TEXT NOT NULL,
                yuklendi INTEGER DEFAULT 0
            );
        """
        
        // Android'deki gibi cihaz_yetki tablosu
        let deviceAuthSQL = """
            CREATE TABLE IF NOT EXISTS cihaz_yetki (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cihaz_bilgisi TEXT NOT NULL UNIQUE,
                cihaz_sahibi TEXT,
                onaylanmis INTEGER DEFAULT 0,
                son_kontrol DATETIME DEFAULT CURRENT_TIMESTAMP
            );
        """
        
        if sqlite3_exec(db, barcodeImagesSQL, nil, nil, nil) == SQLITE_OK {
            print("✅ barkod_resimler table created successfully")
        } else {
            print("❌ barkod_resimler table creation error: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        if sqlite3_exec(db, deviceAuthSQL, nil, nil, nil) == SQLITE_OK {
            print("✅ cihaz_yetki table created successfully")
        } else {
            print("❌ cihaz_yetki table creation error: \(String(cString: sqlite3_errmsg(db)))")
        }
    }
    
    // MARK: - Cihaz Yetki İşlemleri (Android uyumlu)
    
    func saveCihazYetki(deviceId: String, deviceOwner: String, isAuthorized: Bool) {
        let sql = """
            INSERT OR REPLACE INTO cihaz_yetki (cihaz_bilgisi, cihaz_sahibi, onaylanmis, son_kontrol)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (deviceId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (deviceOwner as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 3, isAuthorized ? 1 : 0)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Device auth saved successfully")
            } else {
                print("❌ Device auth save error: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("❌ Device auth prepare error: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        sqlite3_finalize(statement)
    }
    
    func isCihazOnaylanmis(_ deviceId: String) -> Bool {
        let sql = "SELECT onaylanmis FROM cihaz_yetki WHERE cihaz_bilgisi = ? LIMIT 1;"
        var statement: OpaquePointer?
        var isAuthorized = false
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (deviceId as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                isAuthorized = sqlite3_column_int(statement, 0) == 1
                print("📱 Device auth status from local DB: \(isAuthorized)")
            } else {
                print("❌ Device not found in local DB")
            }
        } else {
            print("❌ Device auth check error: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        sqlite3_finalize(statement)
        return isAuthorized
    }
    
    func getCihazSahibi(_ deviceId: String) -> String? {
        let sql = "SELECT cihaz_sahibi FROM cihaz_yetki WHERE cihaz_bilgisi = ? LIMIT 1;"
        var statement: OpaquePointer?
        var deviceOwner: String?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (deviceId as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    deviceOwner = String(cString: cString)
                    print("📱 Device owner from local DB: \(deviceOwner ?? "nil")")
                }
            } else {
                print("❌ Device owner not found in local DB")
            }
        } else {
            print("❌ Device owner check error: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        sqlite3_finalize(statement)
        return deviceOwner
    }
    
    // MARK: - Barkod Resim İşlemleri
    
    func saveImage(customerName: String, imagePath: String, uploader: String) -> Bool {
        let sql = """
            INSERT INTO barkod_resimler (musteri_adi, resim_yolu, yukleyen)
            VALUES (?, ?, ?);
        """
        
        var statement: OpaquePointer?
        var success = false
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (customerName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (imagePath as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (uploader as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Image saved successfully")
                success = true
            } else {
                print("❌ Image save error: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("❌ Image save prepare error: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        sqlite3_finalize(statement)
        return success
    }
    
    func markImageAsUploaded(imagePath: String) -> Bool {
        let sql = "UPDATE barkod_resimler SET yuklendi = 1 WHERE resim_yolu = ?;"
        var statement: OpaquePointer?
        var success = false
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (imagePath as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Image marked as uploaded")
                success = true
            } else {
                print("❌ Image update error: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("❌ Image update prepare error: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        sqlite3_finalize(statement)
        return success
    }
    
    func getUnuploadedImages() -> [(id: Int64, customerName: String, imagePath: String, date: String, uploader: String)] {
        let sql = """
            SELECT id, musteri_adi, resim_yolu, datetime(tarih, 'localtime'), yukleyen
            FROM barkod_resimler
            WHERE yuklendi = 0
            ORDER BY tarih DESC;
        """
        
        var statement: OpaquePointer?
        var results: [(id: Int64, customerName: String, imagePath: String, date: String, uploader: String)] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int64(statement, 0)
                
                let customerName = String(cString: sqlite3_column_text(statement, 1))
                let imagePath = String(cString: sqlite3_column_text(statement, 2))
                let date = String(cString: sqlite3_column_text(statement, 3))
                let uploader = String(cString: sqlite3_column_text(statement, 4))
                
                results.append((id: id, customerName: customerName, imagePath: imagePath, date: date, uploader: uploader))
            }
        } else {
            print("❌ Get unuploaded images error: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    func getUploadedImages() -> [(id: Int64, customerName: String, imagePath: String, date: String, uploader: String)] {
        let sql = """
            SELECT id, musteri_adi, resim_yolu, datetime(tarih, 'localtime'), yukleyen
            FROM barkod_resimler
            WHERE yuklendi = 1
            ORDER BY tarih DESC;
        """
        
        var statement: OpaquePointer?
        var results: [(id: Int64, customerName: String, imagePath: String, date: String, uploader: String)] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int64(statement, 0)
                
                let customerName = String(cString: sqlite3_column_text(statement, 1))
                let imagePath = String(cString: sqlite3_column_text(statement, 2))
                let date = String(cString: sqlite3_column_text(statement, 3))
                let uploader = String(cString: sqlite3_column_text(statement, 4))
                
                results.append((id: id, customerName: customerName, imagePath: imagePath, date: date, uploader: uploader))
            }
        } else {
            print("❌ Get uploaded images error: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    func deleteImage(id: Int64) -> Bool {
        let sql = "DELETE FROM barkod_resimler WHERE id = ?;"
        var statement: OpaquePointer?
        var success = false
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, id)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Image deleted successfully")
                success = true
            } else {
                print("❌ Image delete error: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("❌ Image delete prepare error: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        sqlite3_finalize(statement)
        return success
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