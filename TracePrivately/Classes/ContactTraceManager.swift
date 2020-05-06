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
    
    var defaultConfiguration: ExposureNotificationConfig?
    
    enum Error: LocalizedError {
        case unknownError
    }
    
    static let backgroundProcessingTaskIdentifier = "ctm.processor"

    fileprivate var enManager = ENManager()
    
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

    private override init() {
    }
    
    deinit {
        enManager.invalidate()
    }

    static let backgroundProcessingMinimumInterval: TimeInterval = 3600

    func applicationDidFinishLaunching() {
        
        self.updateBadgeCount()

        
        UNUserNotificationCenter.current().delegate = self
        
        // It's not clear how new keys will automatically be submitted, since the documentation indicates auth is required every time you retrieve keys. Maybe need to prompt the user with a notification.
        
        self.isBootStrapping = true
        
        self.enManager.activate { error in
            
            guard error == nil else {
                self.isBootStrapping = false
                return
            }
            
            if self.shouldAutoStartIfPossible && self.enManager.exposureNotificationStatus == .active {
                self.startTracing { _ in
                    self.isBootStrapping = false
                }
            }
            else {
                self.performBackgroundUpdate { _ in
                    self.isBootStrapping = false
                }
            }
        }
    }
    
    func updateBadgeCount() {
        
        DispatchQueue.main.async {
            let request = ExposureFetchRequest(includeStatuses: [ .unread ], includeNotificationStatuses: [], sortDirection: .timestampAsc)
            let context = DataManager.shared.persistentContainer.viewContext

            let count = (try? context.count(for: request.fetchRequest)) ?? 0
            print("Updating applicationIconBadgeNumber to \(count)")
            UIApplication.shared.applicationIconBadgeNumber = count == 0 ? -1 : count
        }
    }
    
    func applicationDidBecomeActive() {
        guard !self.isBootStrapping else {
            return
        }
        
        print("Did become active, performing background update.")
        ContactTraceManager.shared.performBackgroundUpdate { _ in

        }
    }
    
    func scheduleNextBackgroundUpdate() {
        DispatchQueue.main.async {
            guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
                return
            }
        
            let minimumDate: Date = self.minimumNextRetryDate ?? Date().addingTimeInterval(Self.backgroundProcessingMinimumInterval)
            delegate.scheduleNextBackgroundProcess(minimumDate: minimumDate)
        }
    }
}

extension ContactTraceManager {
    private static let enConfigKey = "ctm_enConfig"

    func saveConfiguration(config: ExposureNotificationConfig?) {
        
        if let config = config {
            guard config.isValid else {
                print("Config to save is not valid: \(config)")
                return
            }

            let encoder = JSONEncoder()

            if let encoded = try? encoder.encode(config) {
                UserDefaults.standard.set(encoded, forKey: Self.enConfigKey)
                UserDefaults.standard.synchronize()
            }
        }
        else {
            UserDefaults.standard.removeObject(forKey: Self.enConfigKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    var savedConfiguration: ExposureNotificationConfig? {
        guard let encoded = UserDefaults.standard.data(forKey: Self.enConfigKey) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(ExposureNotificationConfig.self, from: encoded)
    }
}

extension ContactTraceManager {
    private static let autostartKey = "ctm_autoStart"
    
    fileprivate func setAutoStartIfPossible(flag: Bool) {
        UserDefaults.standard.set(flag, forKey: Self.autostartKey)
        UserDefaults.standard.synchronize()
    }

    fileprivate var shouldAutoStartIfPossible: Bool {
        return UserDefaults.standard.bool(forKey: Self.autostartKey)
    }
}

extension ContactTraceManager {
    private static let minimumNextRetryDateKey = "ctm_minimumNextRetryDate"
    
    fileprivate func setMinimumNextRetryDate(date: Date?) {
        if let date = date {
            
            // Put an upper bound to protect against a server incorretly using a date too far in the future, which would render the app useless
            let latestDate = Date().addingTimeInterval(86400)
            
            let date = min(date, latestDate)
            
            UserDefaults.standard.set(date, forKey: Self.minimumNextRetryDateKey)
        }
        else {
            UserDefaults.standard.removeObject(forKey: Self.minimumNextRetryDateKey)
        }
        
        UserDefaults.standard.synchronize()
    }
    
    fileprivate var minimumNextRetryDate: Date? {
        return UserDefaults.standard.object(forKey: Self.minimumNextRetryDateKey) as? Date
    }
}

extension ContactTraceManager {
    private static let lastReceivedInfectedKeysKey = "lastRecievedInfectedKeysKey"
    
    var lastReceivedInfectedKeys: Date? {
        return UserDefaults.standard.object(forKey: Self.lastReceivedInfectedKeysKey) as? Date
    }

    func clearLastReceivedInfectedKeys() {
        UserDefaults.standard.removeObject(forKey: Self.lastReceivedInfectedKeysKey)
        UserDefaults.standard.synchronize()
    }

    func saveLastReceivedInfectedKeys(date: Date) {
        UserDefaults.standard.set(date, forKey: Self.lastReceivedInfectedKeysKey)
        UserDefaults.standard.synchronize()
    }

    func performBackgroundUpdate(completion: @escaping (Swift.Error?) -> Void) {
        
        // TODO: Use UIApplication.shared.beginBackgroundTask so this can finish

        guard !self.isUpdatingExposures else {
            print("Already updating exposures, skipping")
            completion(nil)
            return
        }

        print("Updating exposures....")
        self.isUpdatingExposures = true
        
        self._performBackgroundUpdate { error in
            self.scheduleNextBackgroundUpdate()
            self.isUpdatingExposures = false
            completion(error)
        }
    }
    
    private func _performBackgroundUpdate(completion: @escaping (Swift.Error?) -> Void) {

        if let date = self.minimumNextRetryDate {
            let now = Date()
            
            guard now >= date else {
                // Not allowed to update yet

                let duration = date.timeIntervalSince(now)
                
                let dcf = DateComponentsFormatter()
                dcf.unitsStyle = .short
                
                if let str = dcf.string(from: duration) {
                    print("Not allowed to retrieve new keys for another \(str).")
                }
                
                self.detectExposures { error in
                    completion(error)
                }
                
                return
            }
        }

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        
        let retrieveKeysOperation = AsyncBlockOperation { operation in
            KeyServer.shared.retrieveInfectedKeys(since: self.lastReceivedInfectedKeys) { response, error in
                guard let response = response else {
                    completion(error ?? Error.unknownError)
                    return
                }
                
                if let config = response.enConfig {
                    print("Received configuration: \(config)")
                    self.saveConfiguration(config: config)
                }
                else {
                    print("Did not receive updated configuration")
                }
                
                let clearCacheFirst: Bool
                
                switch response.listType {
                case .fullList: clearCacheFirst = true
                case .partialList: clearCacheFirst = false
                }
                
                
                if let date = response.earliestRetryDate {
                    self.setMinimumNextRetryDate(date: date)
                }

                self.saveNewInfectedKeys(keys: response.keys, deletedKeys: response.deletedKeys, clearCacheFirst: clearCacheFirst) { keyCount, error in
                    
                    if error != nil {
                        operation.cancel()
                    }
                    
                    self.saveLastReceivedInfectedKeys(date: response.date)
                    
                    operation.complete()
                }
            }
        }
        
        retrieveKeysOperation.completionBlock = {
            guard !retrieveKeysOperation.isCancelled else {
                completion(nil)
                return
            }

            self.detectExposures { error in
                completion(nil)
            }
        }

        operationQueue.addOperation(retrieveKeysOperation)
    }
    
    fileprivate func detectExposures(completion: @escaping (Swift.Error?) -> Void) {
        
        guard self.enManager.exposureNotificationEnabled else {
            print("Exposure notification not enabled")
            completion(nil)
            return
        }
        
        print("Detecting exposures...")
        
        let session = ENExposureDetectionSession()
        
        let config = self.savedConfiguration ?? self.defaultConfiguration
        
        if let config = config {
            session.configuration = config.exposureConfig
        }

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        
        let activateOperation = AsyncBlockOperation { operation in
            session.activate { error in
                if error != nil {
                    operation.cancel()
                }
                
                operation.complete()
            }
        }
        
        let addKeysOperation = AsyncBlockOperation { operation in
            DataManager.shared.allInfectedKeys { keys, error in
                guard let keys = keys, keys.count > 0 else {
                    operation.cancel()
                    operation.complete()
                    return
                }

                let k: [ENTemporaryExposureKey] = keys.map { $0.enExposureKey }
                
                session.batchAddDiagnosisKeys(k) { error in
                    if error != nil {
                        operation.cancel()
                    }

                    operation.complete()
                }
            }
        }
        
        let diagnoseOperation = AsyncBlockOperation { operation in
            session.finishedDiagnosisKeys { summary, error in
                guard let summary = summary else {
                    operation.cancel()
                    operation.complete()
                    return
                }

                guard summary.matchedKeyCount > 0 else {
                    DataManager.shared.saveExposures(exposures: []) { error in
                        
                        if error != nil {
                            operation.cancel()
                        }
                        
                        operation.complete()
                    }
                    
                    return
                }
                
                // Documentation says use a reasonable number, such as 100
                let maximumCount: Int = 100
                
                self.getExposures(session: session, maximumCount: maximumCount, exposures: []) { exposures, error in
                    guard let exposures = exposures else {
                        operation.cancel()
                        operation.complete()
                        return
                    }
                    
                    DataManager.shared.saveExposures(exposures: exposures) { error in
                        
                        self.updateBadgeCount()
                        
                        self.sendExposureNotificationForPendingContacts { notificationError in
                            completion(error ?? notificationError)
                        }
                    }
                }
            }
        }

        activateOperation.completionBlock = {
            guard !activateOperation.isCancelled else {
                session.invalidate()
                return
            }

            operationQueue.addOperation(addKeysOperation)
        }
        
        addKeysOperation.completionBlock = {
            print("In addKeysOperation completion block")

            guard !addKeysOperation.isCancelled else {
                session.invalidate()
                return
            }
            
            
            operationQueue.addOperation(diagnoseOperation)
        }
        
        diagnoseOperation.completionBlock = {
            print("In diagnoseOperation completion block")
            session.invalidate()
        }

        operationQueue.addOperation(activateOperation)
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
    
    private func saveNewInfectedKeys(keys: [TPTemporaryExposureKey], deletedKeys: [TPTemporaryExposureKey], clearCacheFirst: Bool, completion: @escaping (DataManager.KeyUpdateCount?, Swift.Error?) -> Void) {
        
        DataManager.shared.saveInfectedKeys(keys: keys, deletedKeys: deletedKeys, clearCacheFirst: clearCacheFirst) { keyCount, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            completion(keyCount, nil)
        }
    }
    
    private func sendExposureNotificationForPendingContacts(completion: @escaping (Swift.Error?) -> Void) {
        
        let request = ExposureFetchRequest(includeStatuses: [ .unread, .read ], includeNotificationStatuses: [.notSent], sortDirection: nil)
        
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
        
        self.isUpdatingEnabledState = true
        
        self.enManager.setExposureNotificationEnabled(true) { error in
            if let error = error {
                print("ERROR: \(error)")
                
                self.isUpdatingEnabledState = false
                self.isContactTracingEnabled = false
                completion(error)
                return
            }

            let unc = UNUserNotificationCenter.current()
            
            unc.requestAuthorization(options: [ .alert, .sound, .badge ]) { success, error in

            }

            self.isContactTracingEnabled = true
            self.isUpdatingEnabledState = false
            
            self.setAutoStartIfPossible(flag: error == nil)

            self.performBackgroundUpdate { _ in
                
            }
                
            completion(error)
        }
    }
    
    func stopTracing() {
        guard self.isContactTracingEnabled && !self.isUpdatingEnabledState else {
            return
        }
        
        self.setAutoStartIfPossible(flag: false)

        self.isUpdatingEnabledState = true
        
        self.enManager.setExposureNotificationEnabled(false) { _ in
            
        }
        
        self.isContactTracingEnabled = false
        self.isUpdatingEnabledState = false
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
        
        print("Adding: \(batch.count) keys")

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
        
        self.enManager.getDiagnosisKeys { keys, error in
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
        
        self.stopTracing()
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        self.enManager.resetAllData { error in
            dispatchGroup.leave()
        }
        
        self.clearLastReceivedInfectedKeys()

        dispatchGroup.enter()
        DataManager.shared.clearRemoteKeyAndLocalExposuresCache { error in
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            completion(nil)
        }
    }
}
