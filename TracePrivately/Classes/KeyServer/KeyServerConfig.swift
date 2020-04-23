//
//  KeyServerConfig.swift
//  TracePrivately
//

import Foundation

struct KeyServerConfig {
    enum HttpMethod {
        case get
        case post
        
        var httpRequestValue: String {
            switch self {
            case .get: return "GET"
            case .post: return "POST"
            }
        }
    }
    
    struct EndPoint {
        let url: URL
        let httpMethod: HttpMethod
    }
    
    struct Authentication {
        let endpoint: EndPoint
        let authentication: KeyServerAuthentication
    }
    
    let submitInfected: EndPoint?
    let getInfected: EndPoint?
    let authentication: Authentication?
    
    static let empty = KeyServerConfig(submitInfected: nil, getInfected: nil, authentication: nil)
}

extension KeyServerConfig {
    init?(plistUrl: URL) {
        guard let config = NSDictionary(contentsOf: plistUrl) else {
            return nil
        }

        let prefix = config.object(forKey: "BaseUrl") as? String ?? ""
        
        guard let endpoints = config.object(forKey: "EndPoints") as? [String: String] else {
            return nil
        }
        
        if let str = endpoints["GetInfectedKeys"], let url = URL(string: prefix + str) {
            self.getInfected = EndPoint(url: url, httpMethod: .get)
        }
        else {
            self.getInfected = nil
        }
        
        if let str = endpoints["SubmitInfectedKeys"], let url = URL(string: prefix + str) {
            self.submitInfected = EndPoint(url: url, httpMethod: .post)
        }
        else {
            self.submitInfected = nil
        }
        
        var authentication: Authentication?

        let authUrl: EndPoint?
        
        if let str = endpoints["Authentication"], let url = URL(string: prefix + str) {
            authUrl = EndPoint(url: url, httpMethod: .post)
        }
        else {
            authUrl = nil
        }

        if let authUrl = authUrl {
            if let authConfig = config["Authentication"] as? [String: Any] {
                if let typeStr = authConfig["Type"] as? String {
                    switch typeStr {
                    case "receipt":
                        authentication = Authentication(
                            endpoint: authUrl,
                            authentication: KeyServerReceiptAuthentication()
                        )
                        
                    default:
                        break
                    }
                }
            }
        }
        
        self.authentication = authentication
    }
}
