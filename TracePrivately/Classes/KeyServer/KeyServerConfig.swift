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
        
        func with(url: URL) -> Self {
            return Self(url: url, httpMethod: httpMethod)
        }
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
    static func createAdapter(plistUrl: URL) -> KeyServerAdapter? {
        guard let dict = NSDictionary(contentsOf: plistUrl) else {
            return nil
        }
        
        guard let config = KeyServerConfig(dict: dict) else {
            return nil
        }
        
        return KeyServerTracePrivatelyAdapter(config: config)
    }

    init?(dict: NSDictionary) {
        let prefix = dict["BaseUrl"] as? String ?? ""
        
        guard let endpoints = dict["EndPoints"] as? [String: String] else {
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
            if let authConfig = dict["Authentication"] as? [String: Any] {
                if let typeStr = authConfig["Type"] as? String {
                    switch typeStr {
                    case "receipt":
                        authentication = Authentication(
                            endpoint: authUrl,
                            authentication: KeyServerReceiptAuthentication()
                        )
                        
                    case "deviceCheck":
                        authentication = Authentication(
                            endpoint: authUrl,
                            authentication: KeyServerDeviceCheckAuthentication()
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
