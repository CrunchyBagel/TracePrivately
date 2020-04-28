//
//  KeyServerAuthentication.swift
//  TracePrivately
//

import Foundation
import DeviceCheck

struct AuthenticationToken: CustomDebugStringConvertible, CustomStringConvertible {
    let string: String
    let expiresAt: Date?
    
    var debugDescription: String {
        return "token=\(string) expiresAt=\(String(describing: expiresAt))"
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
    // TODO: Consider saving this to the keychain
    static let tokenStorageKey = "KeyServer_AuthToken"
    static let expiryStorageKey = "KeyServer_AuthTokenExpiry"

    func saveAuthenticationToken(token: AuthenticationToken) {
        print("Saving token: \(token)")
        
        let defaults = UserDefaults.standard
        defaults.set(token.string, forKey: Self.tokenStorageKey)
        
        if let date = token.expiresAt {
            defaults.set(date, forKey: Self.expiryStorageKey)
        }
        else {
            defaults.removeObject(forKey: Self.expiryStorageKey)
        }
        
        defaults.synchronize()
    }
    
    var currentAuthenticationToken: AuthenticationToken? {
        guard let str = UserDefaults.standard.string(forKey: Self.tokenStorageKey) else {
            return nil
        }
        
        let expiresAt = UserDefaults.standard.object(forKey: Self.expiryStorageKey) as? Date
        
        return .init(string: str, expiresAt: expiresAt)
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
    
    private var isInDev: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    func buildAuthRequestJsonObject(completion: @escaping ([String : Any]?, Error?) -> Void) {
        if self.isInDev {
            completion(["receipt": UUID().uuidString], nil)
        }
        else {
            do {
                guard let url = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: url.path) else {
                    throw AuthError.receiptNotFound
                }

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
