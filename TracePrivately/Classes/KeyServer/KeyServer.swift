//
//  KeyServer.swift
//  TracePrivately
//

import Foundation



class KeyServer {
    static let shared = KeyServer()
    
    enum Error: LocalizedError {
        case responseDataNotReceived
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
            }
        }
        
        var shouldRetryWithAuthRequest: Bool {
            return self == .notAuthorized
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
            
            var request = try self.createRequest(endPoint: authentication.endpoint, authentication: auth, throwIfMissing: false)
            
            let requestJson = try auth.buildAuthRequestJsonObject()
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
                
                let token = AuthenticationToken(string: tokenStr)
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

extension KeyServer {
    /**
        Sends a JSON packet of the current device's keys. Each key is Base 64 encoded
     
        Refer to `KeyServer.yaml` for expected request and response format.
     */
    
    func submitInfectedKeys(keys: [CTDailyTracingKey], completion: @escaping (Bool, Swift.Error?) -> Void) {
        
        self._submitInfectedKeys(keys: keys) { success, error in
            if let error = error as? KeyServer.Error, error.shouldRetryWithAuthRequest {
                
                self.requestAuthorizationToken { success, authError in
                    guard success else {
                        completion(false, authError)
                        return
                    }
                    
                    self._submitInfectedKeys(keys: keys, completion: completion)
                }
                
                return
            }
            
            completion(success, error)
        }
    }

    private func _submitInfectedKeys(keys: [CTDailyTracingKey], completion: @escaping (Bool, Swift.Error?) -> Void) {
        
        guard let endPoint = self.config.submitInfected else {
            completion(false, Error.invalidConfig)
            return
        }
        
        do {
            var request = try self.createRequest(endPoint: endPoint, authentication: self.config.authentication?.authentication)
            
            let encodedKeys: [String] = keys.map { $0.keyData.base64EncodedString() }
            
            let requestData: [String: Any] = [
                "keys": encodedKeys
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: requestData, options: [])

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

extension KeyServer {
    /**
        Accepts an optional date in the `since` parameter (and ISO 8601 formatted date). Only infected keys submitted after this date are returned.
     
        Refer to `KeyServer.yaml` for expected response format.
     */
    
    struct InfectedKeysResponse {
        let date: Date
        let keys: [CTDailyTracingKey]
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

        guard let endPoint = self.config.getInfected else {
            completion(nil, Error.invalidConfig)
            return
        }
        
        var url = endPoint.url

        if let date = date {
            let df = ISO8601DateFormatter()
            let queryItem = URLQueryItem(name: "since", value: df.string(from: date))
            
            if let u = url.withQueryItem(item: queryItem) {
                url = u
            }
        }
        
        do {
            let request = try self.createRequest(endPoint: endPoint, authentication: self.config.authentication?.authentication)
            
            let task = self.urlSession.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let response = response as? HTTPURLResponse else {
                    completion(nil, Error.responseDataNotReceived)
                    return
                }
                
                switch response.statusCode {
                case 401:
                    completion(nil, Error.notAuthorized)
                    return
                default:
                    break
                }

                guard let data = data else {
                    completion(nil, Error.responseDataNotReceived)
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    if let str = String(data: data, encoding: .utf8) {
                        print("Response: \(str)")
                    }
                    
                    completion(nil, Error.jsonDecodingError)
                    return
                }
                
                guard let keyData = json["keys"] as? [String] else {
                    completion(nil, Error.keyDataMissing)
                    return
                }
                
                let df = ISO8601DateFormatter()

                guard let dateStr = json["date"] as? String, let date = df.date(from: dateStr) else {
                    completion(nil, Error.dateMissing)
                    return
                }
                
                let keysData = keyData.compactMap { Data(base64Encoded: $0) }
                
                let tracingKeys = keysData.map { CTDailyTracingKey(keyData: $0) }
                
                let infectedKeys = InfectedKeysResponse(date: date, keys: tracingKeys)
                
                completion(infectedKeys, nil)
            }
            
            task.resume()
        }
        catch {
            completion(nil, error)
        }
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
