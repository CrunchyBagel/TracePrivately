//
//  KeyServerTracePrivatelyAdapter.swift
//  TracePrivately
//

import Foundation
import MessagePack

class KeyServerTracePrivatelyAdapter: KeyServerBaseAdapter, KeyServerAdapter {

    private static let methodIdentifierKey = "t"

    func buildRequestAuthorizationRequest(completion: @escaping (URLRequest?, Swift.Error?) -> Void) {
        
        guard let authentication = self.config.authentication else {
            completion(nil, KeyServer.Error.invalidConfig)
            return
        }
        
        let auth = authentication.authentication
        
        auth.buildAuthRequestJsonObject { requestJson, error in
            do {
                if let error = error {
                    throw error
                }
                
                var requestJson = requestJson ?? [:]
                
                if requestJson[Self.methodIdentifierKey] == nil, let identifier = auth.identifier {
                    requestJson[Self.methodIdentifierKey] = identifier
                }

                var request = try self.createRequest(endPoint: authentication.endpoint, authentication: auth, throwIfMissing: false)

                let jsonData = try JSONSerialization.data(withJSONObject: requestJson, options: [])
                
                
                request.httpBody = jsonData
                request.setValue(String(jsonData.count), forHTTPHeaderField: "Content-Length")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                completion(request, nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }
    
    func handleRequestAuthorizationResponse(data: Data, response: HTTPURLResponse) throws {
        guard let authentication = self.config.authentication else {
            throw KeyServer.Error.invalidConfig
        }

        switch response.statusCode {
        case 401:
            throw KeyServer.Error.notAuthorized
        default:
            break
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            if let str = String(data: data, encoding: .utf8) {
                print("Response: \(str)")
            }
            
            throw KeyServer.Error.jsonDecodingError
        }
        
        guard let status = json["status"] as? String, status == "OK" else {
            throw KeyServer.Error.okStatusNotReceived
        }
        
        guard let tokenStr = json["token"] as? String else {
            throw KeyServer.Error.notAuthorized
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
        authentication.authentication.saveAuthenticationToken(token: token)
    }
    
    
    func buildRetrieveInfectedKeysRequest(since date: Date?) throws -> URLRequest {
        guard var endPoint = self.config.getInfected else {
            throw KeyServer.Error.invalidConfig
        }
                
        if let date = date {
            let df = ISO8601DateFormatter()
            let queryItem = URLQueryItem(name: "since", value: df.string(from: date))
            
            if let u = endPoint.url.withQueryItem(item: queryItem) {
                endPoint = endPoint.with(url: u)
            }
        }
                
        var request = try self.createRequest(endPoint: endPoint, authentication: self.config.authentication?.authentication)
        
        request.setValue("application/x-msgpack", forHTTPHeaderField: "Accept")
//            request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    func handleRetrieveInfectedKeysResponse(data: Data, response: HTTPURLResponse) throws -> KeyServer.InfectedKeysResponse {

        switch response.statusCode {
        case 401:
            throw KeyServer.Error.notAuthorized
        default:
            break
        }

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw KeyServer.Error.contentTypeNotRecognized(nil)
        }
        
        let normalized = contentType.lowercased()
        
        let decoded: KeyServerMessagePackInfectedKeys
        
        if normalized.contains("application/json") {
            print("Handling JSON response")
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard let json = jsonObject as? [String: Any] else {
                if let str = String(data: data, encoding: .utf8) {
                    print("Response: \(str)")
                }
                
                throw KeyServer.Error.jsonDecodingError
            }
            
            decoded = try KeyServerMessagePackInfectedKeys(json: json)
        }
        else if normalized.contains("application/x-msgpack") {
            print("Handling Binary response")

            let decoder = MessagePackDecoder()
            decoded = try decoder.decode(KeyServerMessagePackInfectedKeys.self, from: data)
        }
        else {
            throw KeyServer.Error.contentTypeNotRecognized(contentType)
        }

        let df = ISO8601DateFormatter()

        guard let date = df.date(from: decoded.date) else {
            throw KeyServer.Error.dateMissing
        }
        
        let listType: KeyServer.InfectedKeysResponse.ListType
        
        
        if let str = decoded.list_type {
            listType = str == "FULL" ? .fullList : .partialList
        }
        else {
            listType = .partialList
        }
        
        let minRetryDate: Date?

        if let str = decoded.min_retry_date {
            minRetryDate = df.date(from: str)
        }
        else {
            minRetryDate = nil
        }

        let keys: [TPTemporaryExposureKey] = decoded.keys.compactMap { $0.exposureKey }
        let deletedKeys: [TPTemporaryExposureKey] = decoded.deleted_keys.compactMap { $0.exposureKey }

        return KeyServer.InfectedKeysResponse(
            listType: listType,
            date: date,
            earliestRetryDate: minRetryDate,
            keys: keys,
            deletedKeys: deletedKeys
        )
    }

    func buildSubmitInfectedKeysRequest(formData: InfectedKeysFormData, keys: [TPTemporaryExposureKey], previousSubmissionId: String?) throws -> URLRequest {
        
        guard let endPoint = self.config.submitInfected else {
            throw KeyServer.Error.invalidConfig
        }
        
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
        
//            print("Form Data: \(requestData)")

        // TODO: Ensure this is secure and that identifiers can't be hijacked into false submissions
        if let identifier = previousSubmissionId {
            requestData["identifier"] = identifier
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestData, options: [])

        request.httpBody = jsonData
        request.setValue(String(jsonData.count), forHTTPHeaderField: "Content-Length")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return request
    }
    
    func handleSubmitInfectedKeysResponse(data: Data, response: HTTPURLResponse) throws -> String? {
        
        switch response.statusCode {
        case 401:
            throw KeyServer.Error.notAuthorized
        default:
            break
        }

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            if let str = String(data: data, encoding: .utf8) {
                print("Response: \(str)")
            }
            
            throw KeyServer.Error.jsonDecodingError
        }
        
        guard let status = json["status"] as? String, status == "OK" else {
            throw KeyServer.Error.okStatusNotReceived
        }

        return json["identifier"] as? String
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
    let min_retry_date: String?
    let list_type: String?
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
        
        let listType = json["list_type"] as? String
        let minRetryDate = json["min_retry_date"] as? String

        self.init(
            status: statusStr ?? "",
            date: dateStr,
            keys: keys,
            deleted_keys: deletedKeys,
            min_retry_date: minRetryDate,
            list_type: listType
        )
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
