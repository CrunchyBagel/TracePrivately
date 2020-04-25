//
//  KeyServerAuthentication.swift
//  TracePrivately
//

import Foundation
import DeviceCheck

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
    
    func buildAuthRequestJsonObject(completion: @escaping ([String: Any]?, Error?) -> Void)
}

class KeyServerBaseAuthentication: KeyServerAuthentication {
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
    
    func buildAuthRequestJsonObject(completion: ([String : Any]?, Error?) -> Void) {
        completion(nil, nil)
    }
}

class KeyServerDeviceCheckAuthentication: KeyServerBaseAuthentication {
    enum AuthError: LocalizedError {
        case notAvailable
    }

    func buildAuthRequestJsonObject(completion: @escaping ([String : Any]?, Error?) -> Void) {
        if #available(iOS 11, *) {
            DCDevice.current.generateToken { data, error in
                if let data = data {
                    completion(["token": data.base64EncodedString()], nil)
                }
                else {
                    completion(nil, error)
                }
            }
        }
        else {
            completion(nil, AuthError.notAvailable)
        }
    }
}

class KeyServerReceiptAuthentication: KeyServerBaseAuthentication {
    enum AuthError: LocalizedError {
        case receiptNotFound
    }
    
    func buildAuthRequestJsonObject(completion: @escaping ([String : Any]?, Error?) -> Void) {
        // TODO: In development there won't be a receipt
        
        let isInDev = true
        
        if isInDev {
            completion(["receipt": UUID().uuidString], nil)
        }
        else {
            guard let url = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: url.path) else {
                completion(nil, AuthError.receiptNotFound)
            }
            
            do {
                let receiptData = try Data(contentsOf: url, options: .alwaysMapped)
                
                let receiptString = receiptData.base64EncodedString(options: [])

                completion(["receipt": receiptString], nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }
}
