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
        
        var errorDescription: String? {
            switch self {
            case .responseDataNotReceived: return NSLocalizedString("keyserver.error.no_response_data", comment: "")
            case .jsonDecodingError: return NSLocalizedString("keyserver.error.response_decoding_error", comment: "")
            case .keyDataMissing: return NSLocalizedString("keyserver.error.key_data_missing", comment: "")
            case .dateMissing: return NSLocalizedString("keyserver.error.date_missing", comment: "")
            case .okStatusNotReceived: return NSLocalizedString("keyserver.error.not_ok", comment: "")
            case .invalidConfig: return NSLocalizedString("keyserver.error.invalid_config", comment: "")
            }
        }
    }
    
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
    
    lazy var configDictionary: NSDictionary? = {
        guard let configUrl = Bundle.main.url(forResource: "KeyServer", withExtension: "plist") else {
            return nil
        }
        
        return NSDictionary(contentsOf: configUrl)
    }()
    
    fileprivate enum RequestEndpoint {
        case submitInfectedKeys
        case getInfectedKeys
        
        func url(config: NSDictionary) -> URL? {
            
            let prefix = config.object(forKey: "BaseUrl") as? String ?? ""
            
            guard let endpoints = config.object(forKey: "EndPoints") as? [String: String] else {
                return nil
            }

            let endPointKey: String
            
            switch self {
            case .getInfectedKeys:
                endPointKey = "GetInfectedKeys"
            case .submitInfectedKeys:
                endPointKey = "SubmitInfectedKeys"
            }
            
            guard let endpoint = endpoints[endPointKey] else {
                return nil
            }
            
            return URL(string: prefix + endpoint)
        }
        
        var httpMethod: String {
            switch self {
            case .getInfectedKeys:
                return "GET"
            case .submitInfectedKeys:
                return "POST"
            }
        }
    }
    
    /**
        Sends a JSON packet of the current device's keys. Each key is Base 64 encoded
     
        Refer to `KeyServer.yaml` for expected request and response format.
     */
    func submitInfectedKeys(keys: [CTDailyTracingKey], completion: @escaping (Bool, Swift.Error?) -> Void) {
        
        let endPoint: RequestEndpoint = .submitInfectedKeys

        guard let config = self.configDictionary, let url = endPoint.url(config: config) else {
            completion(false, Error.invalidConfig)
            return
        }
        
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )

        request.httpMethod = endPoint.httpMethod

        let encodedKeys: [String] = keys.map { $0.keyData.base64EncodedString() }
        
        let requestData: [String: Any] = [
            "keys": encodedKeys
        ]

        do {
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
    
    /**
        Accepts an optional date in the `since` parameter (and ISO 8601 formatted date). Only infected keys submitted after this date are returned.
     
        Refer to `KeyServer.yaml` for expected response format.
     */
    
    struct InfectedKeysResponse {
        let date: Date
        let keys: [CTDailyTracingKey]
    }
    
    func retrieveInfectedKeys(since date: Date?, completion: @escaping (InfectedKeysResponse?, Swift.Error?) -> Void) {

        let endPoint: RequestEndpoint = .getInfectedKeys

        guard let config = self.configDictionary, var url = endPoint.url(config: config) else {
            completion(nil, Error.invalidConfig)
            return
        }

        if let date = date, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            
            let df = ISO8601DateFormatter()

            var queryItems = components.queryItems ?? []

            let queryItem = URLQueryItem(name: "since", value: df.string(from: date))
            queryItems.append(queryItem)

            components.queryItems = queryItems
            
            if let u = components.url {
                url = u
            }
        }
        
        print("Retrieving \(url)")

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )

        request.httpMethod = endPoint.httpMethod

        let task = self.urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
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
            
            let response = InfectedKeysResponse(date: date, keys: tracingKeys)
            
            completion(response, nil)
        }
        
        task.resume()
    }
}

