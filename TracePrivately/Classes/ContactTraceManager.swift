//
//  ContactTraceManager.swift
//  TracePrivately
//

import Foundation
import UserNotifications
import UIKit

class ContactTraceManager: NSObject {
    
    fileprivate let queue = DispatchQueue(label: "ContactTraceManager", qos: .default, attributes: [])

    static let shared = ContactTraceManager()
    
    var config: ExposureNotificationConfig = .defaultConfig
    
    enum Error: LocalizedError {
        case unknownError
    }
    
    static let backgroundProcessingTaskIdentifier = "ctm.processor"

    fileprivate var exposureDetectionSession: ENExposureDetectionSession?
    
    private var _isUpdatingEnabledState = false
    @objc dynamic var isUpdatingEnabledState: Bool {
        get {
            return queue.sync {
                return self._isUpdatingEnabledState
            }
        }
        set {
            self.willChangeValue(for: \.isUpdatingEnabledState)
            queue.sync {
                self._isUpdatingEnabledState = newValue
            }
            self.didChangeValue(for: \.isUpdatingEnabledState)
        }
    }
    
    private var _isContactTracingEnabled = false
    @objc dynamic  var isContactTracingEnabled: Bool {
        get {
            return queue.sync {
                return self._isContactTracingEnabled
            }
        }
        set {
            self.willChangeValue(for: \.isContactTracingEnabled)
            queue.sync {
                self._isContactTracingEnabled = newValue
            }
            self.didChangeValue(for: \.isContactTracingEnabled)
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
        
        let request = ExposureFetchRequest(includeStatuses: [ .detected ], includeNotificationStatuses: [], sortDirection: .timestampAsc)
        
        let context = DataManager.shared.persistentContainer.viewContext
        
        let count = (try? context.count(for: request.fetchRequest)) ?? 0

        UIApplication.shared.applicationIconBadgeNumber = count == 0 ? -1 : count
        
        UNUserNotificationCenter.current().delegate = self
        
        // Not called here since it's called in applicationDidBecomeActive
//        self.performBackgroundUpdate { _ in
//
//        }
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

                self.addAndFinalizeKeys(session: session, keys: response.keys) { error in
                    self.isUpdatingExposures = false
                    completion(error)
                }
            }
        }
    }
    
    fileprivate func addAndFinalizeKeys(session: ENExposureDetectionSession, keys: [ENTemporaryExposureKey], completion: @escaping (Swift.Error?) -> Void) {

        session.batchAddDiagnosisKeys(inKeys: keys) { error in
            session.finishedDiagnosisKeysWithCompletion { summary, error in
                guard let summary = summary else {
                    completion(error)
                    return
                }

                guard summary.matchedKeyCount > 0 else {
                    DataManager.shared.saveExposures(exposures: []) { error in
                        completion(error)
                    }
                    
                    return
                }
                
                // Documentation says use a reasonable number, such as 100
                let maxCount: UInt32 = 100
                
                self.getExposures(session: session, maxCount: maxCount, exposures: []) { exposures, error in
                    guard let exposures = exposures else {
                        completion(error)
                        return
                    }
                    
                    DataManager.shared.saveExposures(exposures: exposures) { error in
                        
                        DispatchQueue.main.sync {
                            UIApplication.shared.applicationIconBadgeNumber = exposures.count == 0 ? -1 : exposures.count
                        }
                        
                        self.sendExposureNotificationForPendingContacts { notificationError in
                            completion(error ?? notificationError)
                        }
                    }
                }
            }
        }
    }
    
    // Recursively retrieves exposures until all are received
    private func getExposures(session: ENExposureDetectionSession, maxCount: UInt32, exposures: [ENExposureInfo], completion: @escaping ([ENExposureInfo]?, Swift.Error?) -> Void) {
        session.getExposureInfoWithMaxCount(maxCount: maxCount) { newExposures, inDone, error in
            
            if let error = error {
                completion(exposures, error)
                return
            }

            let allExposures = exposures + (newExposures ?? [])
            
            if inDone {
                completion(allExposures, nil)
            }
            else {
                self.getExposures(session: session, maxCount: maxCount, exposures: allExposures, completion: completion)
            }
        }
    }
    
    private func saveNewInfectedKeys(keys: [ENTemporaryExposureKey], completion: @escaping (_ numNewRemoteKeys: Int, Swift.Error?) -> Void) {
        DataManager.shared.saveInfectedKeys(keys: keys) { numNewKeys, error in
            if let error = error {
                completion(0, error)
                return
            }
            
            completion(numNewKeys, nil)
        }
    }
    
    private func sendExposureNotificationForPendingContacts(completion: @escaping (Swift.Error?) -> Void) {
        
        let request = ExposureFetchRequest(includeStatuses: [.detected], includeNotificationStatuses: [.notSent], sortDirection: nil)
        
        let context = DataManager.shared.persistentContainer.newBackgroundContext()
        
        context.perform {
            do {
                let entities = try context.fetch(request.fetchRequest)
                
                self.sendLocalNotification(entities: entities) { error in
                    context.perform {
                        entities.forEach { $0.localNotificationStatus = DataManager.ExposureLocalNotificationStatus.sent.rawValue }
                    
                        do {
                            try context.save()
                            completion(nil)
                        }
                        catch {
                            completion(error)
                        }
                    }
                }
            }
            catch {
                completion(nil)
            }
            
        }
        

    }
    
    private func sendLocalNotification(entities: [ExposureContactInfoEntity], completion: @escaping (Swift.Error?) -> Void) {
        
        let contacts = entities.compactMap { $0.contactInfo }
        
        guard contacts.count > 0 else {
            completion(nil)
            return
        }

        let content = UNMutableNotificationContent()
        content.badge = entities.count as NSNumber
        
        content.title = String(format: NSLocalizedString("notification.exposure_detected.title", comment: ""), Disease.current.localizedTitle)
        
        if contacts.count > 1 {
            content.body = NSLocalizedString("notification.exposure_detected.multiple.body", comment: "")
        }
        else {
            let contact = contacts[0]
            
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .medium

            let dcf = DateComponentsFormatter()
            dcf.allowedUnits = [ .day, .hour, .minute ]
            dcf.unitsStyle = .abbreviated
            dcf.zeroFormattingBehavior = .dropLeading
            dcf.maximumUnitCount = 2

            let formattedTimestamp = df.string(from: contact.date)
            let formattedDuration: String
                
            if let str = dcf.string(from: contact.duration) {
                formattedDuration = str
            }
            else {
                // Fallback for formatter, although I doubt this can be reached
                let numMinutes = max(1, Int(contact.duration / 60))
                formattedDuration = "\(numMinutes)m"
            }
                
            content.body = String(
                format: NSLocalizedString("notification.exposure_detected.single.body", comment: ""),
                formattedTimestamp,
                formattedDuration
            )
        }
        
        let request = UNNotificationRequest(
            identifier: "exposure",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            completion(error)
        }
    }
}

extension ContactTraceManager {
    func startTracing(completion: @escaping (Swift.Error?) -> Void) {
        
        guard !self.isUpdatingEnabledState else {
            completion(nil)
            return
        }
        
        guard !self.isUpdatingEnabledState else {
            completion(nil)
            return
        }
        
        guard !self.isUpdatingExposures else {
            completion(nil)
            return
        }

        self.isUpdatingEnabledState = true
        
        let settings = ENSettings(enableState: true)
        
        let request = ENSettingsChangeRequest(settings: settings)
        request.activateWithCompletion { error in
            defer {
                request.invalidate()
            }
            
            if let error = error {
                self.isUpdatingEnabledState = false
                self.isContactTracingEnabled = false
                completion(error)
                return
            }
            
            self.startExposureChecking { error in
                
                if error != nil {
                    let settings = ENSettings(enableState: false)
                    let request = ENSettingsChangeRequest(settings: settings)
                    request.activateWithCompletion { _ in
                        defer {
                            request.invalidate()
                        }

                        self.isUpdatingEnabledState = false
                        self.isContactTracingEnabled = false
                        completion(error)
                    }

                    return
                }
                
                self.isContactTracingEnabled = true
                self.isUpdatingEnabledState = false
                
                completion(error)
            }
        }
    }
    
    func stopTracing() {
        guard self.isContactTracingEnabled && !self.isUpdatingEnabledState else {
            return
        }

        self.isUpdatingEnabledState = true
        self.stopExposureChecking()

        let settings = ENSettings(enableState: false)
        let request = ENSettingsChangeRequest(settings: settings)
        request.activateWithCompletion { _ in
            defer {
                request.invalidate()
            }

            self.isContactTracingEnabled = false
            self.isUpdatingEnabledState = false
        }
    }
}

extension ContactTraceManager {
    fileprivate func startExposureChecking(completion: @escaping (Swift.Error?) -> Void) {
        let dispatchGroup = DispatchGroup()
        
        let session = ENExposureDetectionSession()
        session.attenuationThreshold = self.config.session.attenuationThreshold
        session.durationThreshold = self.config.session.durationThreshold
        
        var sessionError: Swift.Error?
        
        dispatchGroup.enter()
        
        // TODO: This session is never invalidated, but it likely should be somewhere
        session.activateWithCompletion { error in
            
            if let error = error {
                sessionError = error
                dispatchGroup.leave()
                return
            }

            let unc = UNUserNotificationCenter.current()
            
            dispatchGroup.enter()
            unc.requestAuthorization(options: [ .alert, .sound, .badge ]) { success, error in
                dispatchGroup.leave()
            }

            DataManager.shared.allInfectedKeys { keys, error in
                guard let keys = keys else {
                    sessionError = error
                    dispatchGroup.leave()
                    return
                }
                
                guard keys.count > 0 else {
                    dispatchGroup.leave()
                    return
                }
                
                self.addAndFinalizeKeys(session: session, keys: keys) { error in
                    sessionError = error
                    dispatchGroup.leave()
                }
            }
        }
        
        self.exposureDetectionSession = session
        
        dispatchGroup.notify(queue: .main) {
            let error = sessionError
            completion(error)
        }
    }
    
    fileprivate func stopExposureChecking() {
        self.exposureDetectionSession = nil
    }
}
 
extension ContactTraceManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // This prevents the notification from appearing when in the foreground
        completionHandler([ .alert, .badge, .sound ])
        
    }
}

extension ENExposureDetectionSession {
    // Modified from https://gist.github.com/mattt/17c880d64c362b923e13c765f5b1c75a
    func batchAddDiagnosisKeys(inKeys keys: [ENTemporaryExposureKey], completion: @escaping ENErrorHandler) {
        
        guard !keys.isEmpty else {
            completion(nil)
            return
        }
        
        guard maxKeyCount > 0 else {
            completion(nil)
            return
        }

        let cursor = keys.index(keys.startIndex, offsetBy: maxKeyCount, limitedBy: keys.endIndex) ?? keys.endIndex
        let batch = Array(keys.prefix(upTo: cursor))
        let remaining = Array(keys.suffix(from: cursor))
        
        print("Adding: \(batch)")

//        withoutActuallyEscaping(completion) { escapingCompletion in
            addDiagnosisKeys(inKeys: batch) { error in
                if let error = error {
                    completion(error)
                } else {
                    self.batchAddDiagnosisKeys(inKeys: remaining, completion: completion)
                }
            }
//        }
    }
}
