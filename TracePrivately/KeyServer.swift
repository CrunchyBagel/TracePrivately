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
    }
    
    lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess     = true
        config.isDiscretionary          = false
        config.sessionSendsLaunchEvents = true
        config.waitsForConnectivity     = true
        config.requestCachePolicy       = .reloadIgnoringLocalCacheData
        
        return URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }()

    private init() {}
    
    enum RequestEndpoint {
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
        
        var urlRequest: URLRequest {
            var request = URLRequest(
                url: self.url,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 30
            )

            request.httpMethod = self.httpMethod
            
            return request
        }
    }
    
    // TODO: Complete server stub
    func submitInfectedKeys(keys: [CTDailyTracingKey], completion: @escaping (Bool, Swift.Error?) -> Void) {
        
        let endPoint: RequestEndpoint = .submitInfectedKeys
        
        var request = endPoint.urlRequest
        let requestData: [String] = []

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
                
                // TODO: Validate the response
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
            Expects a json response like the following. Each key is a Base 64 encoded string.
     
            {
                "status":"OK",
                "keys":[
                    "Base64-Encoded-String-1",
                    "Base64-Encoded-String-2",
                    ...
                ]
            }
     */
    func retrieveInfectedKeys(since: Date, completion: @escaping ([CTDailyTracingKey]?, Swift.Error?) -> Void) {

        let endPoint: RequestEndpoint = .retrieveInfectedKeys

        let request = endPoint.urlRequest
        
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

