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
        case contentTypeNotRecognized(String?)
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
            case .contentTypeNotRecognized(let str): return String(format: NSLocalizedString("keyserver.error.content_type_not_recognized", comment: ""), str ?? "none")
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
    
    var adapter: KeyServerAdapter = KeyServerTracePrivatelyAdapter(config: .empty)
    
    lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess     = true
        config.isDiscretionary          = false
        
        #if !os(macOS)
        config.sessionSendsLaunchEvents = true
        #endif
        
        config.requestCachePolicy       = .reloadIgnoringLocalCacheData

        if #available(iOS 11.0, *) {
            config.waitsForConnectivity     = true
        }
        
        return URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }()

    private init() {}
}

extension KeyServer {
    private static let methodIdentifierKey = "t"
    
    fileprivate func requestAuthorizationToken(completion: @escaping (Bool, Swift.Error?) -> Void) {
        
        self.adapter.buildRequestAuthorizationRequest { request, error in
            guard let request = request else {
                completion(false, error)
                return
            }
            
            // TODO: DNS error doesn't seem to timeout very quickly
            let task = self.urlSession.dataTask(with: request) { data, response, error in
                
                if let error = error {
                    completion(false, error)
                    return
                }
                
                guard let response = response as? HTTPURLResponse else {
                    completion(false, Error.responseDataNotReceived)
                    return
                }

                guard let data = data else {
                    completion(false, Error.responseDataNotReceived)
                    return
                }

                do {
                    try self.adapter.handleRequestAuthorizationResponse(data: data, response: response)
                    completion(true, nil)
                }
                catch {
                    completion(false, error)
                }
            }
            
            task.priority = URLSessionTask.highPriority
            task.resume()
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
        
        do {
            let request = try self.adapter.buildSubmitInfectedKeysRequest(formData: formData, keys: keys, previousSubmissionId: previousSubmissionId)
            
            let task = self.urlSession.dataTask(with: request) { data, response, error in
                
                if let error = error {
                    completion(false, nil, error)
                    return
                }
                
                guard let response = response as? HTTPURLResponse else {
                    completion(false, nil, Error.responseDataNotReceived)
                    return
                }

                guard let data = data else {
                    completion(false, nil, Error.responseDataNotReceived)
                    return
                }

                do {
                    let submissionIdentifier = try self.adapter.handleSubmitInfectedKeysResponse(data: data, response: response)

                    completion(true, submissionIdentifier, nil)
                }
                catch {
                    completion(false, nil, error)
                }
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
    
    struct InfectedKeysResponse: CustomDebugStringConvertible {
        enum ListType {
            case partialList
            case fullList
        }
        
        let listType: ListType
        let date: Date
        let earliestRetryDate: Date?
        let keys: [TPTemporaryExposureKey]
        let deletedKeys: [TPTemporaryExposureKey]
        
        /// If the server provides a config for exposure notifications it will be held here so it can be subsequently stored and used
        let enConfig: ExposureNotificationConfig?
        
        var debugDescription: String {
            return "listType=\(listType) date=\(date) earliestRetryDate=\(String(describing: earliestRetryDate)) keys.count=\(keys.count) deletedKeys.count=\(deletedKeys.count)"
        }
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

        do {
            let request = try self.adapter.buildRetrieveInfectedKeysRequest(since: date)

            let task = self.urlSession.dataTask(with: request) { data, response, error in
                do {
                    if let error = error {
                        throw error
                    }
                
                    guard let response = response as? HTTPURLResponse else {
                        throw Error.responseDataNotReceived
                    }
                    
                    guard let data = data else {
                        throw Error.responseDataNotReceived
                    }

                    let infectedKeysResponse = try self.adapter.handleRetrieveInfectedKeysResponse(data: data, response: response)
                
                    print("Response: \(infectedKeysResponse)")

                    completion(infectedKeysResponse, nil)
                }
                catch {
                    print("ERROR: \(error)")
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

