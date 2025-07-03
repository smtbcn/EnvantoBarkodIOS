import Foundation
import SQLite3

// MARK: - Thread Safety Note
// DatabaseManager tüm database işlemlerini serial queue (databaseQueue) üzerinden yapar.
// Bu sayede SQLite multi-threaded access hatalarının önüne geçilir.
// BackgroundUploadManager, UploadService ve UI thread'leri güvenle database'e erişebilir.

// SQLITE_TRANSIENT macro tanımı
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
    
    // MARK: - Thread Safety
    private let databaseQueue = DispatchQueue(label: "com.envanto.database", qos: .utility)
    
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
        
        // Database açılma kontrol
        if db != nil {
            createTables()
        } else {
        }
        
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Operations
    private func openDatabase() {
        
        guard let dbPath = getDatabasePath() else {
            return
        }
        
        
        // Dosya var mı kontrol et
        let fileExists = FileManager.default.fileExists(atPath: dbPath)
        
        let openResult = sqlite3_open(dbPath, &db)
        if openResult == SQLITE_OK {
        } else {
            if let errorMessage = sqlite3_errmsg(db) {
            }
            db = nil
        }
    }
    
    private func closeDatabase() {
        if sqlite3_close(db) == SQLITE_OK {
        } else {
        }
        db = nil
    }
    
    private func getDatabasePath() -> String? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, 
                                                          in: .userDomainMask).first else {
            return nil
        }
        
        let dbPath = documentsDir.appendingPathComponent(DatabaseManager.DATABASE_NAME).path
        
        // Documents klasörüne yazma iznimiz var mı?
        let documentsPath = documentsDir.path
        let isWritable = FileManager.default.isWritableFile(atPath: documentsPath)
        
        // Database dosyası var mı ve yazılabilir mi?
        let dbExists = FileManager.default.fileExists(atPath: dbPath)
        if dbExists {
            let isDBWritable = FileManager.default.isWritableFile(atPath: dbPath)
        }
        
        return dbPath
    }
    
    // MARK: - Create Tables (Android ile aynı yapı)
    private func createTables() {
        
        guard db != nil else {
            return
        }
        
        
        createBarkodResimlerTable()
        createCihazYetkiTable()
        
        
        // Tabloların gerçekten oluşup oluşmadığını kontrol et
        checkTableExists()
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
        
        
        let result = sqlite3_exec(db, createTableSQL, nil, nil, nil)
        if result == SQLITE_OK {
        } else {
            if let errorMessage = sqlite3_errmsg(db) {
            }
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
        
        
        let result = sqlite3_exec(db, createTableSQL, nil, nil, nil)
        if result == SQLITE_OK {
        } else {
            if let errorMessage = sqlite3_errmsg(db) {
            }
        }
    }
    
    // MARK: - Insert Barkod Resim (Android metoduna benzer)
    func insertBarkodResim(musteriAdi: String, resimYolu: String, yukleyen: String) -> Bool {
        
        guard db != nil else {
            return false
        }
        
        // 🚫 MÜKERRER KAYIT KONTROLÜ
        if isImageAlreadyInDatabase(resimYolu: resimYolu, musteriAdi: musteriAdi) {
            return true  // Zaten var, başarılı kabul et
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
        
        let prepareResult = sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil)
        if prepareResult == SQLITE_OK {
            
            sqlite3_bind_text(statement, 1, musteriAdi, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, resimYolu, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, tarih, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, yukleyen, -1, SQLITE_TRANSIENT)
            
            
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            } else {
                if let errorMessage = sqlite3_errmsg(db) {
                }
            }
        } else {
            if let errorMessage = sqlite3_errmsg(db) {
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    // MARK: - Mükerrer Kayıt Kontrolü
    private func isImageAlreadyInDatabase(resimYolu: String, musteriAdi: String) -> Bool {
        guard db != nil else { return false }
        
        // Hem path hem de dosya adı bazlı kontrol yapalım
        let fileName = URL(fileURLWithPath: resimYolu).lastPathComponent
        
        
        // 1. Tam path kontrolü
        let pathCheckSQL = """
            SELECT COUNT(*) FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) 
            WHERE \(DatabaseManager.COLUMN_RESIM_YOLU) = ? AND \(DatabaseManager.COLUMN_MUSTERI_ADI) = ?
        """
        
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, pathCheckSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, resimYolu, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, musteriAdi, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)
        
        if count > 0 {
            return true
        }
        
        // 2. Dosya adı kontrolü (path format farklı olabilir)
        let fileCheckSQL = """
            SELECT COUNT(*) FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) 
            WHERE \(DatabaseManager.COLUMN_RESIM_YOLU) LIKE '%' || ? AND \(DatabaseManager.COLUMN_MUSTERI_ADI) = ?
        """
        
        if sqlite3_prepare_v2(db, fileCheckSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, fileName, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, musteriAdi, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)
        
        if count > 0 {
            return true
        }
        
        return false
    }
    
    // MARK: - Get Uploaded Images Count (Thread-safe)
    func getUploadedImagesCount() -> Int {
        guard db != nil else { return 0 }
        
        return databaseQueue.sync {
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
    }
    
    // MARK: - Get Pending Upload Count (yuklendi = 0) (Thread-safe)
    func getPendingUploadCount() -> Int {
        guard db != nil else { return 0 }
        
        return databaseQueue.sync {
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
    }
    
    // MARK: - Get Customer Images (belirli müşterinin resimlerini getir - Thread-safe)
    func getCustomerImages(musteriAdi: String) -> [BarkodResim] {
        guard db != nil else { return [] }
        
        return databaseQueue.sync {
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
                sqlite3_bind_text(statement, 1, musteriAdi, -1, SQLITE_TRANSIENT)
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int(statement, 0))
                    
                    // Güvenli string okuma (NULL kontrol)
                    let musteriAdiPtr = sqlite3_column_text(statement, 1)
                    let musteriAdiResult = musteriAdiPtr != nil ? String(cString: musteriAdiPtr!) : ""
                    
                    let resimYoluPtr = sqlite3_column_text(statement, 2)
                    let resimYolu = resimYoluPtr != nil ? String(cString: resimYoluPtr!) : ""
                    
                    let tarihPtr = sqlite3_column_text(statement, 3)
                    let tarih = tarihPtr != nil ? String(cString: tarihPtr!) : ""
                    
                    let yukleyenPtr = sqlite3_column_text(statement, 4)
                    let yukleyen = yukleyenPtr != nil ? String(cString: yukleyenPtr!) : ""
                    
                    let yuklendi = Int(sqlite3_column_int(statement, 5))
                    
                    // Boş kayıtları atla
                    if musteriAdiResult.isEmpty || resimYolu.isEmpty {
                        continue
                    }
                    
                    let barkodResim = BarkodResim(
                        id: id,
                        musteriAdi: musteriAdiResult,
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
    }
    
    // MARK: - Get All Pending Images (yüklenmemiş tüm resimler - Thread-safe)
    func getAllPendingImages() -> [BarkodResim] {
        guard db != nil else { return [] }
        
        return databaseQueue.sync {
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
                    
                    // Güvenli string okuma (NULL kontrol)
                    let musteriAdiPtr = sqlite3_column_text(statement, 1)
                    let musteriAdi = musteriAdiPtr != nil ? String(cString: musteriAdiPtr!) : ""
                    
                    let resimYoluPtr = sqlite3_column_text(statement, 2)
                    let resimYolu = resimYoluPtr != nil ? String(cString: resimYoluPtr!) : ""
                    
                    let tarihPtr = sqlite3_column_text(statement, 3)
                    let tarih = tarihPtr != nil ? String(cString: tarihPtr!) : ""
                    
                    let yukleyenPtr = sqlite3_column_text(statement, 4)
                    let yukleyen = yukleyenPtr != nil ? String(cString: yukleyenPtr!) : ""
                    
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
    }
    
    // MARK: - Clear All Barkod Resimler (Database temizleme)
    func clearAllBarkodResimler() -> Bool {
        guard db != nil else { return false }
        
        let deleteSQL = "DELETE FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER)"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                let deletedCount = sqlite3_changes(db)
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    // MARK: - Clear Invalid Records (Kaldırıldı - Gereksiz karmaşıklık)
    // clearInvalidImageRecords() kaldırıldı
    
    // MARK: - Update Image Path (Kaldırıldı - Gereksiz)
    // updateImagePath() kaldırıldı
    
    // MARK: - Delete Image Record
    func deleteBarkodResim(id: Int) -> Bool {
        guard db != nil else { return false }
        
        let deleteSQL = "DELETE FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) WHERE \(DatabaseManager.COLUMN_ID) = ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            
            if sqlite3_step(statement) == SQLITE_DONE {
                let deletedCount = sqlite3_changes(db)
                sqlite3_finalize(statement)
                return deletedCount > 0  // Gerçekten silinip silinmediğini kontrol et
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    // MARK: - Delete Customer Images (Müşterinin tüm resim kayıtlarını sil)
    func deleteCustomerImages(musteriAdi: String) -> Bool {
        guard db != nil else { return false }
        
        // Direkt SQL DELETE kullan (tekli silme yerine)
        let deleteSQL = "DELETE FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) WHERE \(DatabaseManager.COLUMN_MUSTERI_ADI) = ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, musteriAdi, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                let deletedCount = sqlite3_changes(db)
                sqlite3_finalize(statement)
                return deletedCount > 0
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    // MARK: - Delete Images By IDs (ID listesi ile toplu silme - Thread-safe)
    func deleteImagesByIds(_ ids: [Int]) -> Bool {
        guard db != nil, !ids.isEmpty else { return false }
        
        return databaseQueue.sync {
            var totalDeleted = 0
            
            // Her ID için ayrı DELETE işlemi (güvenilir yaklaşım)
            for id in ids {
                let deleteSQL = "DELETE FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) WHERE \(DatabaseManager.COLUMN_ID) = ?"
                var statement: OpaquePointer?
                
                if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_int(statement, 1, Int32(id))
                    
                    if sqlite3_step(statement) == SQLITE_DONE {
                        totalDeleted += Int(sqlite3_changes(db))
                    }
                }
                sqlite3_finalize(statement)
            }
            
            return totalDeleted > 0
        }
    }
    
    // MARK: - Update Upload Status (Thread-safe)
    func updateUploadStatus(id: Int, yuklendi: Int) -> Bool {
        guard db != nil else { return false }
        
        return databaseQueue.sync {
            let updateSQL = "UPDATE \(DatabaseManager.TABLE_BARKOD_RESIMLER) SET \(DatabaseManager.COLUMN_YUKLENDI) = ? WHERE \(DatabaseManager.COLUMN_ID) = ?"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int(statement, 1, Int32(yuklendi))
                sqlite3_bind_int(statement, 2, Int32(id))
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    let affectedRows = sqlite3_changes(db)
                    sqlite3_finalize(statement)
                    return affectedRows > 0
                }
            }
            
            sqlite3_finalize(statement)
            return false
        }
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
        
        return databaseQueue.sync {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let sonKontrol = dateFormatter.string(from: Date())
            
            // Önce mevcut kaydı kontrol et (nested sync'ten kaçın)
            let existsSQL = "SELECT COUNT(*) FROM \(DatabaseManager.TABLE_CIHAZ_YETKI) WHERE \(DatabaseManager.COLUMN_CIHAZ_BILGISI) = ?"
            var existsStatement: OpaquePointer?
            var recordExists = false
            
            if sqlite3_prepare_v2(db, existsSQL, -1, &existsStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(existsStatement, 1, cihazBilgisi, -1, nil)
                
                if sqlite3_step(existsStatement) == SQLITE_ROW {
                    let count = Int(sqlite3_column_int(existsStatement, 0))
                    recordExists = (count > 0)
                }
            }
            sqlite3_finalize(existsStatement)
            
            if recordExists {
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
                        sqlite3_finalize(statement)
                        return true
                    }
                }
                sqlite3_finalize(statement)
            }
            
            return false
        }
    }
    
    func getCihazYetki(cihazBilgisi: String) -> CihazYetki? {
        guard db != nil else { return nil }
        
        return databaseQueue.sync {
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
    }
    
    func getCihazSahibi(cihazBilgisi: String) -> String {
        guard db != nil else { return "" }
        
        return databaseQueue.sync {
            // getCihazYetki kodunu doğrudan burada çalıştır (nested sync'ten kaçın)
            let selectSQL = """
                SELECT \(DatabaseManager.COLUMN_CIHAZ_SAHIBI)
                FROM \(DatabaseManager.TABLE_CIHAZ_YETKI) 
                WHERE \(DatabaseManager.COLUMN_CIHAZ_BILGISI) = ? 
                LIMIT 1
            """
            
            var statement: OpaquePointer?
            var result = ""
            
            if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, cihazBilgisi, -1, nil)
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    let cihazSahibiPtr = sqlite3_column_text(statement, 0)
                    result = cihazSahibiPtr != nil ? String(cString: cihazSahibiPtr!) : ""
                }
            }
            
            sqlite3_finalize(statement)
            return result
        }
    }
    
    func isCihazYetkili(cihazBilgisi: String) -> Bool {
        guard db != nil else { return false }
        
        return databaseQueue.sync {
            // getCihazYetki kodunu doğrudan burada çalıştır (nested sync'ten kaçın)
            let selectSQL = """
                SELECT \(DatabaseManager.COLUMN_CIHAZ_ONAY)
                FROM \(DatabaseManager.TABLE_CIHAZ_YETKI) 
                WHERE \(DatabaseManager.COLUMN_CIHAZ_BILGISI) = ? 
                LIMIT 1
            """
            
            var statement: OpaquePointer?
            var isAuthorized = false
            
            if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, cihazBilgisi, -1, nil)
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    let cihazOnay = Int(sqlite3_column_int(statement, 0))
                    isAuthorized = (cihazOnay == 1)
                }
            }
            
            sqlite3_finalize(statement)
            return isAuthorized
        }
    }
    

    





    
    // MARK: - Get All Images (pending + uploaded)
    func getAllImages() -> [BarkodResim] {
        guard db != nil else { return [] }
        
        let selectSQL = """
            SELECT \(DatabaseManager.COLUMN_ID), \(DatabaseManager.COLUMN_MUSTERI_ADI), 
                   \(DatabaseManager.COLUMN_RESIM_YOLU), \(DatabaseManager.COLUMN_TARIH), 
                   \(DatabaseManager.COLUMN_YUKLEYEN), \(DatabaseManager.COLUMN_YUKLENDI)
            FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) 
            ORDER BY \(DatabaseManager.COLUMN_TARIH) DESC
        """
        
        var statement: OpaquePointer?
        var results: [BarkodResim] = []
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                
                // Güvenli string okuma (NULL kontrol)
                let musteriAdiPtr = sqlite3_column_text(statement, 1)
                let musteriAdi = musteriAdiPtr != nil ? String(cString: musteriAdiPtr!) : ""
                
                let resimYoluPtr = sqlite3_column_text(statement, 2)
                let resimYolu = resimYoluPtr != nil ? String(cString: resimYoluPtr!) : ""
                
                let tarihPtr = sqlite3_column_text(statement, 3)
                let tarih = tarihPtr != nil ? String(cString: tarihPtr!) : ""
                
                let yukleyenPtr = sqlite3_column_text(statement, 4)
                let yukleyen = yukleyenPtr != nil ? String(cString: yukleyenPtr!) : ""
                
                let yuklendi = Int(sqlite3_column_int(statement, 5))
                
                // Boş kayıtları atla
                if musteriAdi.isEmpty || resimYolu.isEmpty {
                    continue
                }
                
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
    
    // MARK: - Clear All Pending Uploads (Security Cleanup - Android benzeri)
    func clearAllPendingUploads() -> Bool {
        guard db != nil else { return false }
        
        
        // Önce silinecek resimlerin bilgilerini al
        let pendingImages = getAllPendingImages()
        
        if pendingImages.isEmpty {
            return true
        }
        
        
        var deletedFiles = 0
        var deletedFolders = 0
        let customerNames = Set(pendingImages.map { $0.musteriAdi })
        
        // 1. DOSYALARI SİL
        for imageRecord in pendingImages {
            let filePath = imageRecord.resimYolu
            
            // Dosya var mı kontrol et ve sil
            if FileManager.default.fileExists(atPath: filePath) {
                do {
                    try FileManager.default.removeItem(atPath: filePath)
                    deletedFiles += 1
                } catch {
                }
            }
        }
        
        // 2. BOŞ MÜŞTERİ KLASÖRLER İNİ KONTROL ET VE SİL
        if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let envantoDir = documentsDir.appendingPathComponent("Envanto")
            
            for customerName in customerNames {
                let customerDir = envantoDir.appendingPathComponent(customerName)
                
                // Müşteri klasörü var mı ve boş mu kontrol et
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: customerDir.path)
                    if contents.isEmpty {
                        try FileManager.default.removeItem(at: customerDir)
                        deletedFolders += 1
                    }
                } catch {
                }
            }
        }
        
        // 3. DATABASE KAYITLARINI SİL
        let deleteSQL = "DELETE FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) WHERE \(DatabaseManager.COLUMN_YUKLENDI) = 0"
        var statement: OpaquePointer?
        var deletedRows = 0
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                deletedRows = Int(sqlite3_changes(db))
            }
        }
        
        sqlite3_finalize(statement)
        
        return deletedRows > 0
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
