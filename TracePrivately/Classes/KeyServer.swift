//
//  KeyServer.swift
//  TracePrivately
//

import Foundation

// TODO: The server needs to be appropriately secured. Perhaps use receipt validation to determine the requester is a validly downloaded app from the App Store.

class KeyServer {
    static let shared = KeyServer()
    
    enum Error: LocalizedError {
        case responseDataNotReceived
        case jsonDecodingError
        case keyDataMissing
        case okStatusNotReceived
        
        var errorDescription: String? {
            switch self {
            case .responseDataNotReceived: return NSLocalizedString("keyserver.error.no_response_data", comment: "")
            case .jsonDecodingError: return NSLocalizedString("keyserver.error.response_decoding_error", comment: "")
            case .keyDataMissing: return NSLocalizedString("keyserver.error.key_data_missing", comment: "")
            case .okStatusNotReceived: return NSLocalizedString("keyserver.error.not_ok", comment: "")
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
    
    fileprivate enum RequestEndpoint {
        case submitInfectedKeys
        case retrieveInfectedKeys
        
        var host: String {
            return "https://example.com"
        }
        
        var url: URL {
            switch self {
            case .retrieveInfectedKeys:
                return URL(string: self.host + "/api/infected")!
            case .submitInfectedKeys:
                return URL(string: self.host + "/api/submit")!
            }
        }
        
        var httpMethod: String {
            switch self {
            case .retrieveInfectedKeys:
                return "GET"
            case .submitInfectedKeys:
                return "POST"
            }
        }
    }
    
    /**
        Sends a JSON packet of the current device's keys. Each key is Base 64 encoded

            {
                "keys": [
                     "Base64-Encoded-String-1",
                     "Base64-Encoded-String-2",
                     ...
                ]
            }
     
        If successful, the following response is expected:
     
             {
                 "status" : "OK"
             }

     */
    func submitInfectedKeys(keys: [CTDailyTracingKey], completion: @escaping (Bool, Swift.Error?) -> Void) {
        
        let endPoint: RequestEndpoint = .submitInfectedKeys
        
        var request = URLRequest(
            url: endPoint.url,
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
        Expects a JSON response like the following. Each key is a Base 64 encoded string.
     
            {
                "status" : "OK",
                "since": "2020-04-18T12:00:00"
                "keys" : [
                    "Base64-Encoded-String-1",
                    "Base64-Encoded-String-2",
                    ...
                ]
            }
     */
    
    func retrieveInfectedKeys(since date: Date?, completion: @escaping ([CTDailyTracingKey]?, Swift.Error?) -> Void) {

        let endPoint: RequestEndpoint = .retrieveInfectedKeys

        var url = endPoint.url
        
        if let date = date, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

            var queryItems = components.queryItems ?? []

            let queryItem = URLQueryItem(name: "since", value: df.string(from: date))
            queryItems.append(queryItem)

            components.queryItems = queryItems
            
            if let u = components.url {
                url = u
            }
        }

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
            
            let keysData = keyData.compactMap { Data(base64Encoded: $0) }
            
            let tracingKeys = keysData.map { CTDailyTracingKey(keyData: $0) }
            
            completion(tracingKeys, nil)
        }
        
        task.resume()
    }
}

