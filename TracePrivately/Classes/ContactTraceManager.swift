//
//  ContactTraceManager.swift
//  TracePrivately
//

import Foundation
import UserNotifications

class ContactTraceManager: NSObject {
    
    fileprivate let queue = DispatchQueue(label: "ContactTraceManager", qos: .default, attributes: [])

    static let shared = ContactTraceManager()
    
    enum Error: LocalizedError {
        case unknownError
    }
    
    static let backgroundProcessingTaskIdentifier = "ctm.processor"

    fileprivate var exposureDetectionSession: CTExposureDetectionSession?
    
    private var _exposureCheckingEnabled = false
    fileprivate var exposureCheckingEnabled: Bool {
        get {
            return queue.sync {
                return self._exposureCheckingEnabled
            }
        }
        set {
            queue.sync {
                self._exposureCheckingEnabled = newValue
            }
        }
    }
    
    private var _isUpdatingExposures = false
    fileprivate var isUpdatingExposures: Bool {
        get {
            return queue.sync {
                return self._isUpdatingExposures
            }
        }
        set {
            queue.sync {
                self._isUpdatingExposures = newValue
            }
        }
    }

    private override init() {}
    
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
        self.performBackgroundUpdate { _ in

        }
    }
}

extension ContactTraceManager {
    private static let lastReceivedInfectedKeysKey = "lastRecievedInfectedKeysKey"
    
    var lastReceivedInfectedKeys: Date? {
        return UserDefaults.standard.object(forKey: Self.lastReceivedInfectedKeysKey) as? Date
    }

    func saveLastReceivedInfectedKeys(date: Date) {
        UserDefaults.standard.set(date, forKey: Self.lastReceivedInfectedKeysKey)
        UserDefaults.standard.synchronize()
    }

    func performBackgroundUpdate(completion: @escaping (Swift.Error?) -> Void) {
        
        guard !self.isUpdatingExposures else {
            completion(nil)
            return
        }
        
        self.isUpdatingExposures = true
        
        KeyServer.shared.retrieveInfectedKeys(since: self.lastReceivedInfectedKeys) { response, error in
            
            guard let response = response else {
                self.isUpdatingExposures = false
                completion(error ?? Error.unknownError)
                return
            }
            
            self.saveNewInfectedKeys(keys: response.keys) { numNewKeys, error in
                self.saveLastReceivedInfectedKeys(date: response.date)

                guard let session = self.exposureDetectionSession else {
                    self.isUpdatingExposures = false
                    completion(nil)
                    return
                }

                
                session.addPositiveDiagnosisKey(inKeys: response.keys, completion: { error in
                    session.finishedPositiveDiagnosisKeys { summary, error in
                        guard let summary = summary else {
                            self.isUpdatingExposures = false
                            completion(error)
                            return
                        }

                        guard summary.matchedKeyCount > 0 else {
                            DataManager.shared.saveExposures(contacts: []) { error in
                                self.isUpdatingExposures = false
                                completion(error)
                            }
                            
                            return
                        }
                        
                        session.getContactInfoWithHandler { contacts, error in
                            guard let contacts = contacts else {
                                self.isUpdatingExposures = false
                                completion(error)
                                return
                            }
                            
                            DataManager.shared.saveExposures(contacts: contacts) { error in
                                
                                self.sendExposureNotification(contacts: contacts) {
                                    self.isUpdatingExposures = false
                                    completion(error)
                                }
                            }
                        }
                    }
                })
            }
        }
    }
    
    private func saveNewInfectedKeys(keys: [CTDailyTracingKey], completion: @escaping (_ numNewRemoteKeys: Int, Swift.Error?) -> Void) {
        DataManager.shared.saveInfectedKeys(keys: keys) { numNewKeys, error in
            if let error = error {
                completion(0, error)
                return
            }
            
            completion(numNewKeys, nil)
        }
    }
    
    private func sendExposureNotification(contacts: [CTContactInfo], completion: @escaping () -> Void) {
        // TODO: Implement
        completion()
    }
}

extension ContactTraceManager {
    func startTokenExchange(completion: @escaping () -> Void) {
        // TODO: Implement
    }
    
    func stopTokenExchange() {
        // TODO: Implement
    }
    
}

extension ContactTraceManager {
    func startExposureChecking(completion: @escaping (Swift.Error?) -> Void) {
        guard !self.isUpdatingExposures else {
            completion(nil)
            return
        }
        
        guard !self.exposureCheckingEnabled else {
            completion(nil)
            return
        }

        let dispatchGroup = DispatchGroup()
        
        let unc = UNUserNotificationCenter.current()
        
        dispatchGroup.enter()
        unc.requestAuthorization(options: [ .alert, .sound, .badge ]) { success, error in

            dispatchGroup.leave()
        }
        
        let session = CTExposureDetectionSession()
        
        var sessionError: Swift.Error?
        
        dispatchGroup.enter()
        session.activateWithCompletion { error in
            self.exposureCheckingEnabled = true

            sessionError = error

            dispatchGroup.leave()
        }
        
        self.exposureDetectionSession = session
        
        DispatchQueue.main.async {
            let error = sessionError
            completion(error)
        }
    }
    
    func stopExposureChecking() {
        guard !self.isUpdatingExposures else {
            return
        }
        
        self.exposureCheckingEnabled = false
        self.exposureDetectionSession = nil
    }
}
 
extension ContactTraceManager: UNUserNotificationCenterDelegate {
    
}
