//
//  KeyServer.swift
//  TracePrivately
//

import Foundation
import MessagePack

class KeyServer {
    static let shared = KeyServer()
    
    enum Error: LocalizedError {
        case responseDataNotReceived
        case contentTypeMissing
        case contentTypeNotRecognized(String)
        case jsonDecodingError
        case keyDataMissing
        case dateMissing
        case okStatusNotReceived
        case invalidConfig
        case notAuthorized
        
        var errorDescription: String? {
            switch self {
            case .responseDataNotReceived: return NSLocalizedString("keyserver.error.no_response_data", comment: "")
            case .jsonDecodingError: return NSLocalizedString("keyserver.error.response_decoding_error", comment: "")
            case .keyDataMissing: return NSLocalizedString("keyserver.error.key_data_missing", comment: "")
            case .dateMissing: return NSLocalizedString("keyserver.error.date_missing", comment: "")
            case .okStatusNotReceived: return NSLocalizedString("keyserver.error.not_ok", comment: "")
            case .invalidConfig: return NSLocalizedString("keyserver.error.invalid_config", comment: "")
            case .notAuthorized: return NSLocalizedString("keyserver.error.not_authorized", comment: "")
            case .contentTypeMissing: return NSLocalizedString("keyserver.error.content_type_missing", comment: "")
            case .contentTypeNotRecognized(let str): return "Invalid content type: \(str)" // TODO: Use this NSLocalizedString("keyserver.error.content_type_not_recognized", comment: "") + str
            }
        }
        
        var shouldRetryWithAuthRequest: Bool {
            switch self {
            case .notAuthorized:
                return true
            default:
                return false
            }
        }
    }
    
    var config: KeyServerConfig = .empty
    
    lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess     = true
        config.isDiscretionary          = false
        config.sessionSendsLaunchEvents = true
        config.requestCachePolicy       = .reloadIgnoringLocalCacheData

        if #available(iOS 11.0, *) {
            config.waitsForConnectivity     = true
        }
        
        return URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }()

    private init() {}

    private func createRequest(endPoint: KeyServerConfig.EndPoint, authentication: KeyServerAuthentication?, throwIfMissing: Bool = true) throws -> URLRequest {
        
        var request = URLRequest(
            url: endPoint.url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )

        request.httpMethod = endPoint.httpMethod.httpRequestValue

        if let authentication = authentication {
            if let token = authentication.currentAuthenticationToken {
                print("Found token: \(token)")
                request.setValue("Bearer \(token.string)", forHTTPHeaderField: "Authorization")
            }
            else if throwIfMissing {
                throw Error.notAuthorized
            }
        }
        else {
            print("Warning: KeyServer has no authentication")
        }
        
        print("Request: \(request)")
        
        return request
    }
}

extension KeyServer {
    fileprivate func requestAuthorizationToken(completion: @escaping (Bool, Swift.Error?) -> Void) {
        
        guard let authentication = self.config.authentication else {
            completion(false, Error.invalidConfig)
            return
        }
        
        let auth = authentication.authentication
        
        do {
            print("Requesting authorization ...")
            
            auth.buildAuthRequestJsonObject { requestJson, error in
                do {
                    if let error = error {
                        throw error
                    }
                    
                    let requestJson = requestJson ?? [:]

                    var request = try self.createRequest(endPoint: authentication.endpoint, authentication: auth, throwIfMissing: false)

                    let jsonData = try JSONSerialization.data(withJSONObject: requestJson, options: [])
                    
                    request.httpBody = jsonData
                    request.setValue(String(jsonData.count), forHTTPHeaderField: "Content-Length")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let task = self.urlSession.dataTask(with: request) { data, response, error in
                        
                        if let error = error {
                            completion(false, error)
                            return
                        }
                        
                        guard let response = response as? HTTPURLResponse else {
                            completion(false, Error.responseDataNotReceived)
                            return
                        }
                        
                        switch response.statusCode {
                        case 401:
                            completion(false, Error.notAuthorized)
                            return
                        default:
                            break
                        }
                        
                        guard let data = data else {
                            completion(false, Error.responseDataNotReceived)
                            return
                        }
                        
                        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                            if let str = String(data: data, encoding: .utf8) {
                                print("Response: \(str)")
                            }
                            
                            completion(false, Error.jsonDecodingError)
                            return
                        }
                        
                        guard let status = json["status"] as? String, status == "OK" else {
                            completion(false, Error.okStatusNotReceived)
                            return
                        }
                        
                        guard let tokenStr = json["token"] as? String else {
                            completion(false, Error.notAuthorized)
                            return
                        }
                        
                        let expiresAt: Date?
                        
                        if let expiresAtStr = json["expires_at"] as? String {
                            let df = ISO8601DateFormatter()
                            expiresAt = df.date(from: expiresAtStr)
                        }
                        else {
                            expiresAt = nil
                        }
                        
                        let token = AuthenticationToken(string: tokenStr, expiresAt: expiresAt)
                        auth.saveAuthenticationToken(token: token)

                        completion(true, nil)
                    }
                    
                    task.priority = URLSessionTask.highPriority
                    task.resume()
                }
                catch {
                    completion(false, error)
                }
            }
        }
    }
}

extension KeyServer {
    /**
        Sends a JSON packet of the current device's keys. Each key is Base 64 encoded
     
        Refer to `KeyServer.yaml` for expected request and response format.
     */
    
    func submitInfectedKeys(formData: InfectedKeysFormData, keys: [TPTemporaryExposureKey], previousSubmissionId: String?, completion: @escaping (Bool, String?, Swift.Error?) -> Void) {
        
        self._submitInfectedKeys(formData: formData, keys: keys, previousSubmissionId: previousSubmissionId) { success, submissionId, error in
            if let error = error as? KeyServer.Error, error.shouldRetryWithAuthRequest {
                
                self.requestAuthorizationToken { success, authError in
                    guard success else {
                        completion(false, nil, authError)
                        return
                    }
                    
                    self._submitInfectedKeys(formData: formData, keys: keys, previousSubmissionId: previousSubmissionId, completion: completion)
                }
                
                return
            }
            
            completion(success, submissionId, error)
        }
    }

    private func _submitInfectedKeys(formData: InfectedKeysFormData, keys: [TPTemporaryExposureKey], previousSubmissionId: String?, completion: @escaping (Bool, String?, Swift.Error?) -> Void) {
        
        guard let endPoint = self.config.submitInfected else {
            completion(false, nil, Error.invalidConfig)
            return
        }
        
        do {
            var request = try self.createRequest(endPoint: endPoint, authentication: self.config.authentication?.authentication)
            
            let encodedKeys: [[String: Any]] = keys.map { key in
                return [
                    "d": key.keyData.base64EncodedString(),
                    "r": key.rollingStartNumber,
                    "l": key.transmissionRiskLevel.rawValue
                ]
            }
            
            var requestData: [String: Any] = [
                "keys": encodedKeys,
                "form": formData.requestJson
            ]
            
            print("Form Data: \(requestData)")

            // TODO: Ensure this is secure and that identifiers can't be hijacked into false submissions
            if let identifier = previousSubmissionId {
                requestData["identifier"] = identifier
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestData, options: [])

            request.httpBody = jsonData
            request.setValue(String(jsonData.count), forHTTPHeaderField: "Content-Length")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let task = self.urlSession.dataTask(with: request) { data, response, error in
                
                if let error = error {
                    completion(false, nil, error)
                    return
                }
                
                guard let response = response as? HTTPURLResponse else {
                    completion(false, nil, Error.responseDataNotReceived)
                    return
                }
                
                switch response.statusCode {
                case 401:
                    completion(false, nil, Error.notAuthorized)
                    return
                default:
                    break
                }
                
                guard let data = data else {
                    completion(false, nil, Error.responseDataNotReceived)
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    if let str = String(data: data, encoding: .utf8) {
                        print("Response: \(str)")
                    }
                    
                    completion(false, nil, Error.jsonDecodingError)
                    return
                }
                
                guard let status = json["status"] as? String, status == "OK" else {
                    completion(false, nil, Error.okStatusNotReceived)
                    return
                }

                let submissionIdentifier = json["identifier"] as? String
                
                completion(true, submissionIdentifier, nil)
            }
            
            task.priority = URLSessionTask.highPriority
            task.resume()
        }
        catch {
            completion(false, nil, error)
        }
    }
}

extension KeyServer {
    /**
        Accepts an optional date in the `since` parameter (and ISO 8601 formatted date). Only infected keys submitted after this date are returned.
     
        Refer to `KeyServer.yaml` for expected response format.
     */
    
    struct InfectedKeysResponse {
        let date: Date
        let keys: [TPTemporaryExposureKey]
        let deletedKeys: [TPTemporaryExposureKey]
    }
    
    func retrieveInfectedKeys(since date: Date?, completion: @escaping (InfectedKeysResponse?, Swift.Error?) -> Void) {

        self._retrieveInfectedKeys(since: date) { response, error in
            if let error = error as? KeyServer.Error, error.shouldRetryWithAuthRequest {
                self.requestAuthorizationToken { success, authError in
                    guard success else {
                        completion(nil, authError)
                        return
                    }
                    
                    self._retrieveInfectedKeys(since: date, completion: completion)
                }
                
                return
            }
            
            completion(response, error)
        }
    }

    private func _retrieveInfectedKeys(since date: Date?, completion: @escaping (InfectedKeysResponse?, Swift.Error?) -> Void) {

        let date: Date? = nil // TODO: Remove
        
        
        guard var endPoint = self.config.getInfected else {
            completion(nil, Error.invalidConfig)
            return
        }
        
        if let date = date {
            let df = ISO8601DateFormatter()
            let queryItem = URLQueryItem(name: "since", value: df.string(from: date))
            
            if let u = endPoint.url.withQueryItem(item: queryItem) {
                endPoint = endPoint.with(url: u)
            }
        }
        
        do {
            var request = try self.createRequest(endPoint: endPoint, authentication: self.config.authentication?.authentication)
            
            request.setValue("application/x-msgpack", forHTTPHeaderField: "Accept")
//            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let task = self.urlSession.dataTask(with: request) { data, response, error in
                do {
                    if let error = error {
                        throw error
                    }
                
                    guard let response = response as? HTTPURLResponse else {
                        throw Error.responseDataNotReceived
                    }
                
                    switch response.statusCode {
                    case 401:
                        throw Error.notAuthorized
                    default:
                        break
                    }

                    guard let data = data else {
                        throw Error.responseDataNotReceived
                    }
                    
                    guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                        throw Error.contentTypeMissing
                    }
                    
                    let normalized = contentType.lowercased()
                    
                    let decoded: KeyServerMessagePackInfectedKeys
                    
                    if normalized.contains("application/json") {
                        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                        
                        guard let json = jsonObject as? [String: Any] else {
                            if let str = String(data: data, encoding: .utf8) {
                                print("Response: \(str)")
                            }
                            
                            throw Error.jsonDecodingError
                        }
                        
                        decoded = try KeyServerMessagePackInfectedKeys(json: json)
                    }
                    else if normalized.contains("application/x-msgpack") {
                        let decoder = MessagePackDecoder()
                        decoded = try decoder.decode(KeyServerMessagePackInfectedKeys.self, from: data)
                    }
                    else {
                        throw Error.contentTypeNotRecognized(contentType)
                    }

                    let df = ISO8601DateFormatter()

                    guard let date = df.date(from: decoded.date) else {
                        throw Error.dateMissing
                    }

                    let keys: [TPTemporaryExposureKey] = decoded.keys.compactMap { $0.exposureKey }
                    let deletedKeys: [TPTemporaryExposureKey] = decoded.deleted_keys.compactMap { $0.exposureKey }

                    let infectedKeysResponse = InfectedKeysResponse(date: date, keys: keys, deletedKeys: deletedKeys)

                    completion(infectedKeysResponse, nil)
                }
                catch {
                    print("ERROR: \(error.localizedDescription)")
                    completion(nil, error)
                }
            }
            
            task.resume()
        }
        catch {
            completion(nil, error)
        }
    }
}

struct KeyServerMessagePackInfectedKeys: Codable {
    struct Key: Codable {
        let d: Data
        let r: Int
        let l: Int

        var exposureKey: TPTemporaryExposureKey? {
            guard r < TPIntervalNumber.max else {
                return nil
            }
            
            let riskLevel: TPRiskLevel? = TPRiskLevel(rawValue: UInt8(l))
            
            return .init(
                keyData: d,
                rollingStartNumber: TPIntervalNumber(r),
                transmissionRiskLevel: riskLevel ?? .invalid
            )
        }
    }
    
    let status: String
    let date: String
    let keys: [Key]
    let deleted_keys: [Key]
}

extension KeyServerMessagePackInfectedKeys {
    init(json: [String: Any]) throws {
        let statusStr = json["status"] as? String

        guard let keysData = json["keys"] as? [[String: Any]] else {
            throw KeyServer.Error.keyDataMissing
        }
        
        let deletedKeysData: [[String: Any]] = (json["deleted_keys"] as? [[String: Any]] ?? [])
        
        guard let dateStr = json["date"] as? String else {
            throw KeyServer.Error.dateMissing
        }
        
        let keys = keysData.compactMap { KeyServerMessagePackInfectedKeys.Key(jsonData: $0) }
        let deletedKeys = deletedKeysData.compactMap { KeyServerMessagePackInfectedKeys.Key(jsonData: $0) }

        self.init(status: statusStr ?? "", date: dateStr, keys: keys, deleted_keys: deletedKeys)
    }
}

extension KeyServerMessagePackInfectedKeys.Key {
    init?(jsonData: [String: Any]) {
        guard let base64str = jsonData["d"] as? String, let keyData = Data(base64Encoded: base64str) else {
            return nil
        }
        
        guard let rollingStartNumber = jsonData["r"] as? Int else {
            return nil
        }
        
        let riskLevel = jsonData["l"] as? Int ?? 0

        self.init(d: keyData, r: rollingStartNumber, l: riskLevel)
  
      }
}

extension URL {
    func withQueryItem(item: URLQueryItem) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        var queryItems = components.queryItems ?? []
        queryItems.append(item)

        components.queryItems = queryItems
        
        return components.url
    }
}
