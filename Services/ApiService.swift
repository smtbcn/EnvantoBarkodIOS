import Foundation

struct UploadResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success = "basari"
        case message = "mesaj"
        case error = "hata"
    }
}

struct Customer: Codable {
    let musteriAdi: String
    
    enum CodingKeys: String, CodingKey {
        case musteriAdi = "musteri_adi"
    }
}

class ApiService {
    static let shared = ApiService()
    private let baseURL = "https://envanto.app/barkod_yukle_android"
    
    private init() {}
    
    func uploadImage(
        customerName: String,
        imagePath: String,
        uploader: String,
        completion: @escaping (Result<UploadResponse, Error>) -> Void
    ) {
        let url = URL(string: baseURL + "/upload.asp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // Add action parameter (Android: upload_file)
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"action\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: text/plain; charset=utf-8\r\n\r\n".data(using: .utf8)!)
        data.append("upload_file\r\n".data(using: .utf8)!)
        
        // Add musteri_adi parameter with UTF-8 encoding
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"musteri_adi\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: text/plain; charset=utf-8\r\n\r\n".data(using: .utf8)!)
        data.append(customerName.data(using: .utf8)!)
        data.append("\r\n".data(using: .utf8)!)
        
        // Add yukleyen parameter with UTF-8 encoding
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"yukleyen\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: text/plain; charset=utf-8\r\n\r\n".data(using: .utf8)!)
        data.append(uploader.data(using: .utf8)!)
        data.append("\r\n".data(using: .utf8)!)
        
        // Add image file
        if let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)) {
            let fileName = (imagePath as NSString).lastPathComponent
            
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"resim\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            data.append(imageData)
            data.append("\r\n".data(using: .utf8)!)
        }
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = data
        
        // Log request details (Android behavior)
        print("=== SENDING REQUEST ===")
        print("Customer Name: \(customerName)")
        print("Uploader: \(uploader)")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Upload error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Log response (Android behavior)
            print("=== RESPONSE ===")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response data: \(responseString)")
                
                // Check if response is HTML (Android behavior)
                if responseString.contains("<html>") || responseString.contains("<!DOCTYPE") {
                    print("❌ Server returned HTML error page")
                    completion(.failure(NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "Server component error"])))
                    return
                }
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(UploadResponse.self, from: data)
                
                // Log response details (Android behavior)
                print("Success: \(response.success)")
                print("Message: \(response.message ?? "nil")")
                print("Error: \(response.error ?? "nil")")
                
                completion(.success(response))
            } catch {
                print("❌ JSON decode error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    func searchCustomers(query: String, completion: @escaping (Result<[Customer], Error>) -> Void) {
        var urlComponents = URLComponents(string: baseURL + "/customers.asp")!
        urlComponents.queryItems = [
            URLQueryItem(name: "action", value: "search"),
            URLQueryItem(name: "query", value: query)
        ]
        
        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Customer search error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let customers = try JSONDecoder().decode([Customer].self, from: data)
                completion(.success(customers))
            } catch {
                print("❌ JSON decode error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    func checkDeviceAuth(deviceId: String, completion: @escaping (Result<DeviceAuthResponse, Error>) -> Void) {
        let url = URL(string: baseURL + "/usersperm.asp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 3.0 // Android'deki gibi 3 saniye timeout
        
        let parameters = "action=check&cihaz_bilgisi=\(deviceId)"
        request.httpBody = parameters.data(using: .utf8)
        
        print("🔐 Device auth request - Device ID: \(deviceId)")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Device auth error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ No auth data received")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Log response (Android behavior)
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔐 Device auth response: \(responseString)")
            }
            
            do {
                let response = try JSONDecoder().decode(DeviceAuthResponse.self, from: data)
                print("✅ Device auth success: \(response.success), Message: \(response.message), Owner: \(response.deviceOwner ?? "nil")")
                completion(.success(response))
            } catch {
                print("❌ Auth JSON decode error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
} 