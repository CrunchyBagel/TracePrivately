//
//  KeyServerAdapter.swift
//  TracePrivately
//

import Foundation

protocol KeyServerAdapter {
    var config: KeyServerConfig { get }
    
    func buildRequestAuthorizationRequest(completion: @escaping (URLRequest?, Swift.Error?) -> Void)
    func handleRequestAuthorizationResponse(data: Data, response: HTTPURLResponse) throws

    func buildRetrieveInfectedKeysRequest(since date: Date?) throws -> URLRequest
    func handleRetrieveInfectedKeysResponse(data: Data, response: HTTPURLResponse) throws -> KeyServer.InfectedKeysResponse
    
    func buildSubmitInfectedKeysRequest(formData: InfectedKeysFormData, keys: [TPTemporaryExposureKey], previousSubmissionId: String?) throws -> URLRequest
    func handleSubmitInfectedKeysResponse(data: Data, response: HTTPURLResponse) throws -> String?
}

class KeyServerBaseAdapter: KeyServerAdapter {
    let config: KeyServerConfig
    
    init(config: KeyServerConfig) {
        self.config = config
    }
    
    func createRequest(endPoint: KeyServerConfig.EndPoint, authentication: KeyServerAuthentication?, throwIfMissing: Bool = true) throws -> URLRequest {
        
        var request = URLRequest(
            url: endPoint.url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )

        request.httpMethod = endPoint.httpMethod.httpRequestValue

        if let authentication = authentication {
            if let token = authentication.currentAuthenticationToken {
//                print("Found token: \(token)")
                request.setValue("Bearer \(token.string)", forHTTPHeaderField: "Authorization")
            }
            else if throwIfMissing {
                throw KeyServer.Error.notAuthorized
            }
        }
        else {
            print("Warning: KeyServer has no authentication")
        }
        
        print("Request: \(request)")
        
        return request
    }
    
    func buildRequestAuthorizationRequest(completion: @escaping (URLRequest?, Error?) -> Void) {
        completion(nil, KeyServer.Error.invalidConfig)
    }
    
    func handleRequestAuthorizationResponse(data: Data, response: HTTPURLResponse) throws {
        throw KeyServer.Error.invalidConfig
    }

    func buildRetrieveInfectedKeysRequest(since date: Date?) throws -> URLRequest {
        throw KeyServer.Error.invalidConfig
    }
    
    func handleRetrieveInfectedKeysResponse(data: Data, response: HTTPURLResponse) throws -> KeyServer.InfectedKeysResponse {
        throw KeyServer.Error.invalidConfig
    }
    
    func buildSubmitInfectedKeysRequest(formData: InfectedKeysFormData, keys: [TPTemporaryExposureKey], previousSubmissionId: String?) throws -> URLRequest {
        throw KeyServer.Error.invalidConfig
    }

    func handleSubmitInfectedKeysResponse(data: Data, response: HTTPURLResponse) throws -> String? {
        throw KeyServer.Error.invalidConfig
    }
}

