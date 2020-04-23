//
//  KeyServerAuthentication.swift
//  TracePrivately
//

import Foundation

struct AuthenticationToken: CustomDebugStringConvertible, CustomStringConvertible {
    let string: String
    
    var debugDescription: String {
        return "token=\(string)"
    }
    
    var description: String {
        return self.string
    }
}

protocol KeyServerAuthentication {
    func saveAuthenticationToken(token: AuthenticationToken)
    var currentAuthenticationToken: AuthenticationToken? { get }
    
    func buildAuthRequestJsonObject() throws -> [String: Any]
}

class KeyServerReceiptAuthentication: KeyServerAuthentication {
    
    enum AuthError: LocalizedError {
        case receiptNotFound
    }
    
    static let storageKey = "KeyServer_AuthToken"
    
    func saveAuthenticationToken(token: AuthenticationToken) {
        print("Saving token: \(token)")
        UserDefaults.standard.set(token.string, forKey: Self.storageKey)
        UserDefaults.standard.synchronize()
    }
    
    var currentAuthenticationToken: AuthenticationToken? {
        guard let str = UserDefaults.standard.string(forKey: Self.storageKey) else {
            return nil
        }
        
        return .init(string: str)
    }
    
    func buildAuthRequestJsonObject() throws -> [String : Any] {
        // TODO: In development there won't be a receipt
        
        let isInDev = true
        
        if isInDev {
            return [
                "receipt": UUID().uuidString
            ]
        }
        else {
            guard let url = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: url.path) else {
                throw AuthError.receiptNotFound
            }
            
            let receiptData = try Data(contentsOf: url, options: .alwaysMapped)
            
            let receiptString = receiptData.base64EncodedString(options: [])

            return [
                "receipt": receiptString
            ]
        }
    }
}
