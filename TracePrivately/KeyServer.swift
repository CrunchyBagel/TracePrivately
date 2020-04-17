//
//  KeyServer.swift
//  TracePrivately
//

import Foundation

class KeyServer {
    static let shared = KeyServer()
    
    private init() {}
    
    // TODO: Complete server stub
    func submitInfectedKeys(keys: [CTDailyTracingKey], completion: @escaping (Bool, Error?) -> Void) {
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            completion(true, nil)
        }
    }
    
    func retrieveInfectedKeys(since: Date, completion: @escaping ([CTDailyTracingKey]?, Error?) -> Void) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            
            let key = CTDailyTracingKey(keyData: UUID().data)
            
            completion([ key ], nil)
        }

    }
}
