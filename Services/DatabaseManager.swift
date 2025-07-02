import Foundation
import SQLite3

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
    
    // MARK: - Singleton Instance
    static func getInstance() -> DatabaseManager {
        if shared == nil {
            shared = DatabaseManager()
        }
        return shared!
    }
    
    // MARK: - Initialization
    private init() {
        print("🔄 \(DatabaseManager.TAG): === DATABASE MANAGER BAŞLATILUYOR ===")
        openDatabase()
        
        // Database açılma kontrol
        if db != nil {
            print("✅ \(DatabaseManager.TAG): Database açıldı, tablolar oluşturuluyor...")
            createTables()
        } else {
            print("❌ \(DatabaseManager.TAG): Database açılamadı, tablolar oluşturulamaz")
        }
        
        print("🔄 \(DatabaseManager.TAG): === DATABASE MANAGER HAZIR ===")
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Operations
    private func openDatabase() {
        print("🔄 \(DatabaseManager.TAG): Database açılıyor...")
        
        guard let dbPath = getDatabasePath() else {
            print("❌ \(DatabaseManager.TAG): Database path alınamadı")
            return
        }
        
        print("📱 \(DatabaseManager.TAG): Database yolu: \(dbPath)")
        
        // Dosya var mı kontrol et
        let fileExists = FileManager.default.fileExists(atPath: dbPath)
        print("📁 \(DatabaseManager.TAG): Database dosyası mevcut: \(fileExists)")
        
        let openResult = sqlite3_open(dbPath, &db)
        if openResult == SQLITE_OK {
            print("✅ \(DatabaseManager.TAG): Database açıldı başarıyla")
            print("🔗 \(DatabaseManager.TAG): DB pointer: \(String(describing: db))")
        } else {
            print("❌ \(DatabaseManager.TAG): Database açılamadı - Result: \(openResult)")
            if let errorMessage = sqlite3_errmsg(db) {
                print("❌ \(DatabaseManager.TAG): SQLite Open Error: \(String(cString: errorMessage))")
            }
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
            print("❌ \(DatabaseManager.TAG): Documents directory alınamadı")
            return nil
        }
        
        let dbPath = documentsDir.appendingPathComponent(DatabaseManager.DATABASE_NAME).path
        print("📁 \(DatabaseManager.TAG): Database path: \(dbPath)")
        
        // Documents klasörüne yazma iznimiz var mı?
        let documentsPath = documentsDir.path
        let isWritable = FileManager.default.isWritableFile(atPath: documentsPath)
        print("✏️ \(DatabaseManager.TAG): Documents yazılabilir: \(isWritable)")
        
        // Database dosyası var mı ve yazılabilir mi?
        let dbExists = FileManager.default.fileExists(atPath: dbPath)
        if dbExists {
            let isDBWritable = FileManager.default.isWritableFile(atPath: dbPath)
            print("📝 \(DatabaseManager.TAG): DB dosyası yazılabilir: \(isDBWritable)")
        }
        
        return dbPath
    }
    
    // MARK: - Create Tables (Android ile aynı yapı)
    private func createTables() {
        print("🔄 \(DatabaseManager.TAG): === TABLO OLUŞTURMA BAŞLIYOR ===")
        
        guard db != nil else {
            print("❌ \(DatabaseManager.TAG): Database connection NULL - tablolar oluşturulamaz")
            return
        }
        
        print("✅ \(DatabaseManager.TAG): Database connection OK - tablolar oluşturuluyor")
        
        createBarkodResimlerTable()
        createCihazYetkiTable()
        
        print("🔄 \(DatabaseManager.TAG): === TABLO OLUŞTURMA BİTTİ ===")
        
        // Tabloların gerçekten oluşup oluşmadığını kontrol et
        checkTableExists()
    }
    
    private func createBarkodResimlerTable() {
        print("🔄 \(DatabaseManager.TAG): barkod_resimler tablosu oluşturuluyor...")
        
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
        
        print("📝 \(DatabaseManager.TAG): SQL: \(createTableSQL)")
        
        let result = sqlite3_exec(db, createTableSQL, nil, nil, nil)
        if result == SQLITE_OK {
            print("✅ \(DatabaseManager.TAG): barkod_resimler tablosu BAŞARIYLA oluşturuldu")
        } else {
            print("❌ \(DatabaseManager.TAG): barkod_resimler tablosu oluşturulamadı - Result: \(result)")
            if let errorMessage = sqlite3_errmsg(db) {
                print("❌ \(DatabaseManager.TAG): SQLite CREATE Error: \(String(cString: errorMessage))")
            }
        }
    }
    
    private func createCihazYetkiTable() {
        print("🔄 \(DatabaseManager.TAG): cihaz_yetki tablosu oluşturuluyor...")
        
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(DatabaseManager.TABLE_CIHAZ_YETKI) (
                \(DatabaseManager.COLUMN_CIHAZ_ID) INTEGER PRIMARY KEY AUTOINCREMENT,
                \(DatabaseManager.COLUMN_CIHAZ_BILGISI) TEXT NOT NULL UNIQUE,
                \(DatabaseManager.COLUMN_CIHAZ_SAHIBI) TEXT NOT NULL,
                \(DatabaseManager.COLUMN_CIHAZ_ONAY) INTEGER DEFAULT 0,
                \(DatabaseManager.COLUMN_CIHAZ_SON_KONTROL) TEXT NOT NULL
            )
        """
        
        print("📝 \(DatabaseManager.TAG): SQL: \(createTableSQL)")
        
        let result = sqlite3_exec(db, createTableSQL, nil, nil, nil)
        if result == SQLITE_OK {
            print("✅ \(DatabaseManager.TAG): cihaz_yetki tablosu BAŞARIYLA oluşturuldu")
        } else {
            print("❌ \(DatabaseManager.TAG): cihaz_yetki tablosu oluşturulamadı - Result: \(result)")
            if let errorMessage = sqlite3_errmsg(db) {
                print("❌ \(DatabaseManager.TAG): SQLite CREATE Error: \(String(cString: errorMessage))")
            }
        }
    }
    
    // MARK: - Insert Barkod Resim (Android metoduna benzer)
    func insertBarkodResim(musteriAdi: String, resimYolu: String, yukleyen: String) -> Bool {
        print("🔄 \(DatabaseManager.TAG): insertBarkodResim başlatıldı")
        print("   📝 Müşteri: \(musteriAdi)")
        print("   📁 Yol: \(resimYolu)")
        print("   👤 Yukleyen: \(yukleyen)")
        
        guard db != nil else {
            print("❌ \(DatabaseManager.TAG): Database bağlantısı yok - db pointer nil")
            return false
        }
        
        print("✅ \(DatabaseManager.TAG): Database bağlantısı OK")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let tarih = dateFormatter.string(from: Date())
        
        print("📅 \(DatabaseManager.TAG): Tarih: \(tarih)")
        
        let insertSQL = """
            INSERT INTO \(DatabaseManager.TABLE_BARKOD_RESIMLER) 
            (\(DatabaseManager.COLUMN_MUSTERI_ADI), \(DatabaseManager.COLUMN_RESIM_YOLU), 
             \(DatabaseManager.COLUMN_TARIH), \(DatabaseManager.COLUMN_YUKLEYEN), \(DatabaseManager.COLUMN_YUKLENDI)) 
            VALUES (?, ?, ?, ?, 0)
        """
        
        print("🗃️ \(DatabaseManager.TAG): SQL hazırlanıyor...")
        
        var statement: OpaquePointer?
        
        let prepareResult = sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil)
        if prepareResult == SQLITE_OK {
            print("✅ \(DatabaseManager.TAG): SQL prepare başarılı")
            
            sqlite3_bind_text(statement, 1, musteriAdi, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, resimYolu, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, tarih, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, yukleyen, -1, SQLITE_TRANSIENT)
            
            print("🔗 \(DatabaseManager.TAG): Parametreler bind edildi")
            
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE {
                print("✅ \(DatabaseManager.TAG): Barkod resim kaydedildi - Müşteri: \(musteriAdi)")
                print("🎉 \(DatabaseManager.TAG): Database kayıt işlemi BAŞARILI!")
                sqlite3_finalize(statement)
                return true
            } else {
                print("❌ \(DatabaseManager.TAG): sqlite3_step başarısız - Result: \(stepResult)")
                if let errorMessage = sqlite3_errmsg(db) {
                    print("❌ \(DatabaseManager.TAG): SQLite Error: \(String(cString: errorMessage))")
                }
            }
        } else {
            print("❌ \(DatabaseManager.TAG): sqlite3_prepare_v2 başarısız - Result: \(prepareResult)")
            if let errorMessage = sqlite3_errmsg(db) {
                print("❌ \(DatabaseManager.TAG): SQLite Prepare Error: \(String(cString: errorMessage))")
            }
        }
        
        sqlite3_finalize(statement)
        print("❌ \(DatabaseManager.TAG): insertBarkodResim BAŞARISIZ!")
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
        
        // ÖNCE TÜM MÜŞTERİLERİ LİSTELE (DEBUG)
        print("🔍 DEBUG: Önce database'deki tüm müşterileri görelim:")
        let allCustomersSQL = "SELECT DISTINCT \(DatabaseManager.COLUMN_MUSTERI_ADI) FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER)"
        var allStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, allCustomersSQL, -1, &allStatement, nil) == SQLITE_OK {
            var customerIndex = 0
            while sqlite3_step(allStatement) == SQLITE_ROW {
                customerIndex += 1
                let customerPtr = sqlite3_column_text(allStatement, 0)
                let customerName = customerPtr != nil ? String(cString: customerPtr!) : "NULL"
                print("   \(customerIndex). DB'deki müşteri: '\(customerName)'")
                
                // Aranan müşteriyle karşılaştır
                if customerName == musteriAdi {
                    print("   ✅ EŞLEŞTİ!")
                } else {
                    print("   ❌ Farklı: '\(customerName)' != '\(musteriAdi)'")
                }
            }
        }
        sqlite3_finalize(allStatement)
        
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
            
            print("🔍 getCustomerImages: Aranan müşteri: '\(musteriAdi)'")
            
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
                
                print("🔍 getCustomerImages DEBUG: ID=\(id), Customer='\(musteriAdiResult)', Path='\(resimYolu)', Uploaded=\(yuklendi)")
                
                // Boş kayıtları atla
                if musteriAdiResult.isEmpty || resimYolu.isEmpty {
                    print("   ⚠️ Boş kayıt atlanıyor: Customer='\(musteriAdiResult)', Path='\(resimYolu)'")
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
        } else {
            print("❌ getCustomerImages: SQL prepare hatası")
        }
        
        sqlite3_finalize(statement)
        print("📊 getCustomerImages: '\(musteriAdi)' için \(results.count) kayıt bulundu")
        return results
    }
    
    // MARK: - Get All Pending Images (yüklenmemiş tüm resimler)
    func getAllPendingImages() -> [BarkodResim] {
        guard db != nil else { return [] }
        
        print("🔍 \(DatabaseManager.TAG): === DATABASE READ DEBUG ===")
        
        let selectSQL = """
            SELECT \(DatabaseManager.COLUMN_ID), \(DatabaseManager.COLUMN_MUSTERI_ADI), 
                   \(DatabaseManager.COLUMN_RESIM_YOLU), \(DatabaseManager.COLUMN_TARIH), 
                   \(DatabaseManager.COLUMN_YUKLEYEN), \(DatabaseManager.COLUMN_YUKLENDI)
            FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) 
            WHERE \(DatabaseManager.COLUMN_YUKLENDI) = 0 
            ORDER BY \(DatabaseManager.COLUMN_TARIH) ASC
        """
        
        print("📝 \(DatabaseManager.TAG): SQL: \(selectSQL)")
        
        var statement: OpaquePointer?
        var results: [BarkodResim] = []
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            var rowCount = 0
            while sqlite3_step(statement) == SQLITE_ROW {
                rowCount += 1
                
                let id = Int(sqlite3_column_int(statement, 0))
                
                // Güvenli string okuma (NULL kontrol)
                let musteriAdiPtr = sqlite3_column_text(statement, 1)
                let musteriAdi = musteriAdiPtr != nil ? String(cString: musteriAdiPtr!) : {
                    print("   ⚠️ Column 1 (musteriAdi) is NULL")
                    return ""
                }()
                
                let resimYoluPtr = sqlite3_column_text(statement, 2)
                let resimYolu = resimYoluPtr != nil ? String(cString: resimYoluPtr!) : {
                    print("   ⚠️ Column 2 (resimYolu) is NULL")
                    return ""
                }()
                
                let tarihPtr = sqlite3_column_text(statement, 3)
                let tarih = tarihPtr != nil ? String(cString: tarihPtr!) : {
                    print("   ⚠️ Column 3 (tarih) is NULL")
                    return ""
                }()
                
                let yukleyenPtr = sqlite3_column_text(statement, 4)
                let yukleyen = yukleyenPtr != nil ? String(cString: yukleyenPtr!) : {
                    print("   ⚠️ Column 4 (yukleyen) is NULL")
                    return ""
                }()
                
                let yuklendi = Int(sqlite3_column_int(statement, 5))
                
                print("📋 \(DatabaseManager.TAG): === ROW \(rowCount) DEBUG ===")
                print("   🆔 ID: \(id)")
                print("   👤 Müşteri: '\(musteriAdi)'")
                print("   📁 Path: '\(resimYolu)' (uzunluk: \(resimYolu.count))")
                print("   📅 Tarih: '\(tarih)'")
                print("   👨‍💼 Yükleyen: '\(yukleyen)'")
                print("   🏷️ Yuklendi: \(yuklendi)")
                
                // Path boş mu kontrol et
                if resimYolu.isEmpty {
                    print("   ❌ PATH BOŞ!")
                } else {
                    print("   ✅ Path dolu")
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
        } else {
            print("❌ \(DatabaseManager.TAG): SQL prepare hatası")
        }
        
        sqlite3_finalize(statement)
        print("📊 \(DatabaseManager.TAG): TOPLAM \(results.count) adet yüklenmemiş resim bulundu")
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
    
    // MARK: - Import Existing Images (Mevcut dosyaları database'e aktar)
    func importExistingImages() {
        print("🔄 \(DatabaseManager.TAG): Mevcut resimler database'e aktarılıyor...")
        
        // App Documents'tan müşteri klasörlerini bul
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ \(DatabaseManager.TAG): Documents directory bulunamadı")
            return
        }
        
        let envantoDir = documentsDir.appendingPathComponent("Envanto")
        
        do {
            let customerFolders = try FileManager.default.contentsOfDirectory(at: envantoDir, includingPropertiesForKeys: nil)
            var importedCount = 0
            
            for customerFolder in customerFolders {
                if customerFolder.hasDirectoryPath {
                    let customerName = customerFolder.lastPathComponent.replacingOccurrences(of: "_", with: " ")
                    
                    // Müşteri klasöründeki resimleri bul
                    let imageFiles = try FileManager.default.contentsOfDirectory(at: customerFolder, includingPropertiesForKeys: nil)
                    
                    for imageFile in imageFiles {
                        let fileName = imageFile.lastPathComponent
                        if fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") || fileName.hasSuffix(".png") {
                            
                            // Bu dosya database'de var mı kontrol et
                            if !isImageInDatabase(imagePath: imageFile.path) {
                                
                                // Dosya adından yukleyen bilgisini çıkar (varsayılan cihaz sahibi)
                                let currentDeviceOwner = UserDefaults.standard.string(forKey: "device_owner") ?? 
                                                       UserDefaults.standard.string(forKey: Constants.UserDefaults.deviceOwner) ?? 
                                                       "Bilinmeyen Cihaz"
                                
                                // Database'e ekle
                                let success = insertBarkodResim(
                                    musteriAdi: customerName,
                                    resimYolu: imageFile.path,
                                    yukleyen: currentDeviceOwner
                                )
                                
                                if success {
                                    importedCount += 1
                                    print("📥 \(DatabaseManager.TAG): Import edildi - \(customerName): \(fileName)")
                                } else {
                                    print("❌ \(DatabaseManager.TAG): Import başarısız - \(customerName): \(fileName)")
                                }
                            }
                        }
                    }
                }
            }
            
            print("✅ \(DatabaseManager.TAG): Import tamamlandı - \(importedCount) resim eklendi")
            
            if importedCount > 0 {
                printDatabaseInfo()
            }
            
        } catch {
            print("❌ \(DatabaseManager.TAG): Import hatası: \(error.localizedDescription)")
        }
    }
    
    // Resmin database'de olup olmadığını kontrol et
    private func isImageInDatabase(imagePath: String) -> Bool {
        guard db != nil else { return false }
        
        let selectSQL = "SELECT COUNT(*) FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) WHERE \(DatabaseManager.COLUMN_RESIM_YOLU) = ?"
        var statement: OpaquePointer?
        var exists = false
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, imagePath, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let count = Int(sqlite3_column_int(statement, 0))
                exists = count > 0
            }
        }
        
        sqlite3_finalize(statement)
        return exists
    }

    // MARK: - Manual Database Test (Debug için)
    func testDatabaseOperations() {
        print("🧪 \(DatabaseManager.TAG): === DATABASE TEST BAŞLIYOR ===")
        
        // 1. Connection test
        print("🧪 \(DatabaseManager.TAG): 1. Connection Test")
        if db != nil {
            print("✅ \(DatabaseManager.TAG): Database connection ACTIVE")
        } else {
            print("❌ \(DatabaseManager.TAG): Database connection NULL")
            return
        }
        
        // 2. Simple SQL test
        print("🧪 \(DatabaseManager.TAG): 2. Simple SQL Test")
        let testSQL = "SELECT 1"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, testSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let result = sqlite3_column_int(statement, 0)
                print("✅ \(DatabaseManager.TAG): Simple SQL çalıştı - Result: \(result)")
            } else {
                print("❌ \(DatabaseManager.TAG): Simple SQL step başarısız")
            }
        } else {
            print("❌ \(DatabaseManager.TAG): Simple SQL prepare başarısız")
        }
        sqlite3_finalize(statement)
        
        // 3. Database info
        print("🧪 \(DatabaseManager.TAG): 3. Database Info")
        if let dbPath = getDatabasePath() {
            let fileExists = FileManager.default.fileExists(atPath: dbPath)
            print("📁 \(DatabaseManager.TAG): DB File exists: \(fileExists)")
            
            if fileExists {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: dbPath),
                   let fileSize = attributes[.size] as? Int64 {
                    print("📏 \(DatabaseManager.TAG): DB File size: \(fileSize) bytes")
                }
            }
        }
        
        // 4. Table creation test
        print("🧪 \(DatabaseManager.TAG): 4. Manual Table Creation Test")
        let createTestTableSQL = "CREATE TABLE IF NOT EXISTS test_table (id INTEGER PRIMARY KEY, name TEXT)"
        if sqlite3_exec(db, createTestTableSQL, nil, nil, nil) == SQLITE_OK {
            print("✅ \(DatabaseManager.TAG): Test table oluşturuldu")
            
            // Test insert
            let insertTestSQL = "INSERT INTO test_table (name) VALUES ('test')"
            if sqlite3_exec(db, insertTestSQL, nil, nil, nil) == SQLITE_OK {
                print("✅ \(DatabaseManager.TAG): Test insert başarılı")
                
                // Test select
                let selectTestSQL = "SELECT COUNT(*) FROM test_table"
                var selectStatement: OpaquePointer?
                if sqlite3_prepare_v2(db, selectTestSQL, -1, &selectStatement, nil) == SQLITE_OK {
                    if sqlite3_step(selectStatement) == SQLITE_ROW {
                        let count = sqlite3_column_int(selectStatement, 0)
                        print("✅ \(DatabaseManager.TAG): Test select başarılı - Count: \(count)")
                    }
                }
                sqlite3_finalize(selectStatement)
                
                // Test table'ı temizle
                sqlite3_exec(db, "DROP TABLE test_table", nil, nil, nil)
            } else {
                print("❌ \(DatabaseManager.TAG): Test insert başarısız")
            }
        } else {
            print("❌ \(DatabaseManager.TAG): Test table oluşturulamadı")
            if let errorMessage = sqlite3_errmsg(db) {
                print("❌ \(DatabaseManager.TAG): Error: \(String(cString: errorMessage))")
            }
        }
        
        print("🧪 \(DatabaseManager.TAG): === DATABASE TEST BİTTİ ===")
    }

    // MARK: - Debug Methods
    func printDatabaseInfo() {
        print("🔍 \(DatabaseManager.TAG): === DATABASE INFO START ===")
        
        // Database connection durumu
        print("🔗 \(DatabaseManager.TAG): DB Connection: \(db != nil ? "ACTIVE" : "NULL")")
        if let dbPtr = db {
            print("🔗 \(DatabaseManager.TAG): DB Pointer: \(String(describing: dbPtr))")
        }
        
        // Database dosya durumu
        if let dbPath = getDatabasePath() {
            print("📁 \(DatabaseManager.TAG): Database dosyası: \(dbPath)")
            let fileExists = FileManager.default.fileExists(atPath: dbPath)
            print("📁 \(DatabaseManager.TAG): Dosya mevcut: \(fileExists)")
            
            if fileExists {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: dbPath),
                   let fileSize = attributes[.size] as? Int64 {
                    print("📏 \(DatabaseManager.TAG): Dosya boyutu: \(fileSize) bytes")
                }
            }
        }
        
        // Database tablo kontrolü
        print("🗃️ \(DatabaseManager.TAG): Tablo durumları kontrol ediliyor...")
        checkTableExists()
        
        let totalCount = getUploadedImagesCount()
        let pendingCount = getPendingUploadCount()
        
        print("📊 \(DatabaseManager.TAG): Toplam resim: \(totalCount)")
        print("📊 \(DatabaseManager.TAG): Bekleyen yükleme: \(pendingCount)")
        print("📊 \(DatabaseManager.TAG): Tamamlanan yükleme: \(totalCount - pendingCount)")
        
        // Son kayıtları göster
        if totalCount > 0 {
            print("📋 \(DatabaseManager.TAG): Son 3 kayıt:")
            let recentImages = getRecentImages(limit: 3)
            for (index, image) in recentImages.enumerated() {
                print("   \(index + 1). \(image.musteriAdi) - \(image.tarih) - \(image.uploadStatusText)")
            }
        }
        
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
        
        print("🔍 \(DatabaseManager.TAG): === DATABASE INFO END ===")
    }
    
    // Tabloların var olup olmadığını kontrol et
    private func checkTableExists() {
        guard db != nil else {
            print("❌ \(DatabaseManager.TAG): DB connection yok, tablo kontrolü yapılamadı")
            return
        }
        
        print("🔍 \(DatabaseManager.TAG): === TABLO KONTROL BAŞLIYOR ===")
        
        // Önce tüm tabloları listele
        print("📋 \(DatabaseManager.TAG): Mevcut tüm tablolar:")
        let listTablesSQL = "SELECT name FROM sqlite_master WHERE type='table'"
        var listStatement: OpaquePointer?
        var foundTables: [String] = []
        
        if sqlite3_prepare_v2(db, listTablesSQL, -1, &listStatement, nil) == SQLITE_OK {
            while sqlite3_step(listStatement) == SQLITE_ROW {
                let tableName = String(cString: sqlite3_column_text(listStatement, 0))
                foundTables.append(tableName)
                print("   📄 \(DatabaseManager.TAG): Tablo: '\(tableName)'")
            }
        } else {
            print("❌ \(DatabaseManager.TAG): Tablo listesi alınamadı")
        }
        sqlite3_finalize(listStatement)
        
        // Basit string karşılaştırması ile kontrol et
        let hasBarkodResimler = foundTables.contains(DatabaseManager.TABLE_BARKOD_RESIMLER)
        let hasCihazYetki = foundTables.contains(DatabaseManager.TABLE_CIHAZ_YETKI)
        
        if hasBarkodResimler {
            print("✅ \(DatabaseManager.TAG): barkod_resimler tablosu MEVCUT")
        } else {
            print("❌ \(DatabaseManager.TAG): barkod_resimler tablosu BULUNAMADI")
        }
        
        if hasCihazYetki {
            print("✅ \(DatabaseManager.TAG): cihaz_yetki tablosu MEVCUT")
        } else {
            print("❌ \(DatabaseManager.TAG): cihaz_yetki tablosu BULUNAMADI")
        }
        
        print("🔍 \(DatabaseManager.TAG): === TABLO KONTROL BİTTİ ===")
    }
    
    // Son kayıtları getir
    private func getRecentImages(limit: Int) -> [BarkodResim] {
        guard db != nil else { return [] }
        
        let selectSQL = """
            SELECT \(DatabaseManager.COLUMN_ID), \(DatabaseManager.COLUMN_MUSTERI_ADI), 
                   \(DatabaseManager.COLUMN_RESIM_YOLU), \(DatabaseManager.COLUMN_TARIH), 
                   \(DatabaseManager.COLUMN_YUKLEYEN), \(DatabaseManager.COLUMN_YUKLENDI)
            FROM \(DatabaseManager.TABLE_BARKOD_RESIMLER) 
            ORDER BY \(DatabaseManager.COLUMN_ID) DESC 
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        var results: [BarkodResim] = []
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(limit))
            
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