//
//  ContactTraceManager.swift
//  TracePrivately
//

import Foundation
import UserNotifications
import UIKit
#if canImport(ExposureNotification)
import ExposureNotification
#endif

class ContactTraceManager: NSObject {
    
    fileprivate let queue = DispatchQueue(label: "ContactTraceManager", qos: .default, attributes: [])

    static let shared = ContactTraceManager()
    
    var config: ExposureNotificationConfig?
    
    enum Error: LocalizedError {
        case unknownError
    }
    
    static let backgroundProcessingTaskIdentifier = "ctm.processor"

    fileprivate var enManager: ENManager?
    fileprivate var enDetectionSession: ENExposureDetectionSession?
    
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
    @objc dynamic var isContactTracingEnabled: Bool {
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
    
    private var _isBootStrapping = false
    private var isBootStrapping: Bool {
        get {
            return queue.sync {
                return self._isBootStrapping
            }
        }
        set {
            queue.sync {
                self._isBootStrapping = newValue
            }
        }
    }

    private override init() {}
    
    static let backgroundProcessingInterval: TimeInterval = 3600

    func applicationDidFinishLaunching() {
        
        let request = ExposureFetchRequest(includeStatuses: [ .detected ], includeNotificationStatuses: [], sortDirection: .timestampAsc)
        
        let context = DataManager.shared.persistentContainer.viewContext
        
        let count = (try? context.count(for: request.fetchRequest)) ?? 0

        UIApplication.shared.applicationIconBadgeNumber = count == 0 ? -1 : count
        
        UNUserNotificationCenter.current().delegate = self
        
        // It's not clear how new keys will automatically be submitted, since the documentation indicates auth is required every time you retrieve keys. Maybe need to prompt the user with a notification.
        
        let manager = ENManager()
        self.enManager = manager
        
        self.isBootStrapping = true
        
        manager.activate { error in
            
            guard error == nil else {
                self.isBootStrapping = false
                return
            }
            
            if manager.exposureNotificationStatus == .active {
                self.startTracing { _ in
                    self.performBackgroundUpdate { _ in
                        self.scheduleNextBackgroundUpdate()
                        self.isBootStrapping = false
                    }
                }
            }
            else {
                self.performBackgroundUpdate { _ in
                    self.scheduleNextBackgroundUpdate()
                    self.isBootStrapping = false
                }
            }
        }
    }
    
    func applicationDidBecomeActive() {
        guard !self.isBootStrapping else {
            return
        }
        
        ContactTraceManager.shared.performBackgroundUpdate { _ in
            self.scheduleNextBackgroundUpdate()
        }
    }
    
    func scheduleNextBackgroundUpdate() {
        DispatchQueue.main.async {
            guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
                return
            }
            
            delegate.scheduleNextBackgroundProcess(minimumDate: Date().addingTimeInterval(Self.backgroundProcessingInterval))
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
        
        print("Updating exposures....")
        self.isUpdatingExposures = true
        
        KeyServer.shared.retrieveInfectedKeys(since: self.lastReceivedInfectedKeys) { response, error in
            guard let response = response else {
                self.isUpdatingExposures = false
                completion(error ?? Error.unknownError)
                return
            }
            
            self.saveNewInfectedKeys(keys: response.keys, deletedKeys: response.deletedKeys) { keyCount, error in
                guard let keyCount = keyCount else {
                    self.isUpdatingExposures = false
                    completion(error)
                    return
                }

                self.saveLastReceivedInfectedKeys(date: response.date)

                guard let session = self.enDetectionSession else {
                    self.isUpdatingExposures = false
                    completion(nil)
                    return
                }
                
                if keyCount.deleted > 0 || keyCount.updated > 0 {
                    // TODO: Rebuild the detection session
                }
                
                self.addAndFinalizeKeys(session: session, keys: response.keys) { error in
                    self.isUpdatingExposures = false
                    completion(error)
                }
            }
        }
    }
    
    fileprivate func addAndFinalizeKeys(session: ENExposureDetectionSession, keys: [TPTemporaryExposureKey], completion: @escaping (Swift.Error?) -> Void) {
        
        guard keys.count > 0 else {
            completion(nil)
            return
        }

        let k: [ENTemporaryExposureKey] = keys.map { $0.enExposureKey }
        
        session.batchAddDiagnosisKeys(k) { error in
            session.finishedDiagnosisKeys { summary, error in
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
                let maximumCount: Int = 100
                
                
                print(">>>> FINALIZING")
                
                self.getExposures(session: session, maximumCount: maximumCount, exposures: []) { exposures, error in
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
    private func getExposures(session: ENExposureDetectionSession, maximumCount: Int, exposures: [TPExposureInfo], completion: @escaping ([TPExposureInfo]?, Swift.Error?) -> Void) {
        
        session.getExposureInfo(withMaximumCount: maximumCount) { newExposures, done, error in
            
            guard let newExposures = newExposures else {
                completion(exposures, error)
                return
            }

            let allExposures = exposures + newExposures.map { $0.tpExposureInfo }
            
            if done {
                completion(allExposures, nil)
            }
            else {
                self.getExposures(session: session, maximumCount: maximumCount, exposures: allExposures, completion: completion)
            }
        }
    }
    
    private func saveNewInfectedKeys(keys: [TPTemporaryExposureKey], deletedKeys: [TPTemporaryExposureKey], completion: @escaping (DataManager.KeyUpdateCount?, Swift.Error?) -> Void) {
        
        DataManager.shared.saveInfectedKeys(keys: keys, deletedKeys: deletedKeys) { keyCount, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            completion(keyCount, nil)
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

        guard let manager = self.enManager else {
            completion(nil)
            return
        }
        
        self.isUpdatingEnabledState = true
        
        manager.setExposureNotificationEnabled(true) { error in
            if let error = error {
                manager.invalidate()

                print("ERROR: \(error)")
                
                self.isUpdatingEnabledState = false
                self.isContactTracingEnabled = false
                completion(error)
                return
            }

            self.startExposureChecking { error in
                
                if error != nil {
                    manager.invalidate()

                    self.isUpdatingEnabledState = false
                    self.isContactTracingEnabled = false
                    completion(error)
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
        
        self.enManager?.setExposureNotificationEnabled(false) { _ in
            
        }
        
        self.isContactTracingEnabled = false
        self.isUpdatingEnabledState = false
    }
}

extension ContactTraceManager {
    fileprivate func startExposureChecking(completion: @escaping (Swift.Error?) -> Void) {
        let dispatchGroup = DispatchGroup()
        
        let session = ENExposureDetectionSession()
        
        if let config = self.config {
            session.configuration = config.exposureConfig
        }
        
        var sessionError: Swift.Error?
        
        dispatchGroup.enter()
        
        session.activate { error in
            
            if let error = error {
                sessionError = error
                dispatchGroup.leave()
                return
            }

            let unc = UNUserNotificationCenter.current()
            
            unc.requestAuthorization(options: [ .alert, .sound, .badge ]) { success, error in

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
                
                // TODO: Perhaps this shouldn't be done in the "turn on" phase, but in the background afterwards. This way it won't slow down the app as much.
                self.addAndFinalizeKeys(session: session, keys: keys) { error in
                    sessionError = error
                    dispatchGroup.leave()
                }
            }
        }
        
        self.enDetectionSession = session
        
        dispatchGroup.notify(queue: .main) {
            let error = sessionError
            completion(error)
        }
    }
    
    fileprivate func stopExposureChecking() {
        self.enDetectionSession?.invalidate()
        self.enDetectionSession = nil
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
    func batchAddDiagnosisKeys(_ keys: [ENTemporaryExposureKey], completion: @escaping ENErrorHandler) {
        
        guard !keys.isEmpty else {
            completion(nil)
            return
        }
        
        guard maximumKeyCount > 0 else {
            completion(nil)
            return
        }

        let cursor = keys.index(keys.startIndex, offsetBy: maximumKeyCount, limitedBy: keys.endIndex) ?? keys.endIndex
        let batch = Array(keys.prefix(upTo: cursor))
        let remaining = Array(keys.suffix(from: cursor))
        
        print("Adding: \(batch)")

//        withoutActuallyEscaping(completion) { escapingCompletion in
            addDiagnosisKeys(batch) { error in
                if let error = error {
                    completion(error)
                } else {
                    self.batchAddDiagnosisKeys(remaining, completion: completion)
                }
            }
//        }
    }
}

extension ContactTraceManager {
    func retrieveSelfDiagnosisKeys(completion: @escaping ([TPTemporaryExposureKey]?, Swift.Error?) -> Void) {
        
        guard let manager = self.enManager else {
            // XXX: Shouldn't get here, but handle this error better
            completion(nil, nil)
            return
        }
        
        manager.getDiagnosisKeys { keys, error in
            guard let keys = keys else {
                completion(nil, error)
                return
            }
            
            let k: [TPTemporaryExposureKey] = keys.map { $0.tpExposureKey }
            
            completion(k, nil)
        }
    }
}

extension ContactTraceManager {
    func resetAllData(completion: @escaping (Swift.Error?) -> Void) {
        guard let manager = self.enManager else {
            completion(nil)
            return
        }
        
        manager.resetAllData { error in
            completion(error)
        }
    }
}
