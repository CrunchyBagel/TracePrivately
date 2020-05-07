//
//  ContactTraceManager.swift
//  TracePrivately
//

// TODO: Merge in protobuf file and other stuff

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
    
    static let backgroundProcessingTaskIdentifier = Bundle.main.bundleIdentifier! + ".processor"

    fileprivate var enManager = ENManager()

    fileprivate var statusObserver: NSKeyValueObservation?
    
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

        self.statusObserver = self.enManager.observe(\.exposureNotificationStatus) { [unowned self] manager, change in
            self.exposureNotificationStatusUpdated()
        }
        
        UNUserNotificationCenter.current().delegate = self
        
        // It's not clear how new keys will automatically be submitted, since the documentation indicates auth is required every time you retrieve keys. Maybe need to prompt the user with a notification.
        
        self.isBootStrapping = true
        
        self.enManager.activate { error in
            guard error == nil else {
                self.isBootStrapping = false
                return
            }
            
            if self.shouldAutoStartIfPossible && ENManager.authorizationStatus == .authorized {
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

        self.isUpdatingExposures = true
        
        self._performBackgroundUpdate { error in
            self.scheduleNextBackgroundUpdate()
            self.isUpdatingExposures = false
            completion(error)
        }
    }
    
    private func _performBackgroundUpdate(completion: @escaping (Swift.Error?) -> Void) {
/*
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
*/
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        
        let retrieveKeysOperation = AsyncBlockOperation { operation in
            print("Beginning operation: retrieveKeysOperation")
            
            KeyServer.shared.retrieveInfectedKeys(since: self.lastReceivedInfectedKeys) { response, error in
                guard let response = response else {
                    operation.cancel()
                    operation.complete()
                    return
                }
                
                if let config = response.enConfig {
                    self.saveConfiguration(config: config)
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
            print("Completing operation: retrieveKeysOperation")
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

        let config = self.savedConfiguration ?? self.defaultConfiguration
        let enConfig = config?.exposureConfig ?? ENExposureConfiguration()

        
        self.writeDatabaseToLocalProtobuf { localUrl, error in
            guard let localUrl = localUrl else {
                completion(error)
                return
            }

            // TODO: This is so far untested
            self.enManager.detectExposures(configuration: enConfig, diagnosisKeyURLs: [localUrl]) { summary, error in
                guard let summary = summary else {
                    completion(nil)
                    return
                }
                
                // TODO: Explanation
                self.enManager.getExposureInfo(summary: summary, userExplanation: "TODO") { exposures, error in
                    guard let exposures = exposures else {
                        completion(error)
                        return
                    }
                    
                    let exp = exposures.map{ $0.tpExposureInfo }
                 
                    DataManager.shared.saveExposures(exposures: exp) { error in

                        self.updateBadgeCount()

                        self.sendExposureNotificationForPendingContacts { notificationError in
                            completion(error ?? notificationError)
                        }
                    }
                }
            }
        }
    }
    
    // This code to create a protobuf and write to disk is listed from Apple's sample project
    
    // TODO: This is now an intermediate step of going through the database then to a filesystem file.
    // Seems like overengineering now. The infected keys should just avoid the database altogether
    // and be written straight to filesystem in protobuf format.
    // TODO: These are limited to 500kb, so need to break up accordingly
    private func writeDatabaseToLocalProtobuf(completion: @escaping (URL?, Swift.Error?) -> Void) {
        DataManager.shared.allInfectedKeys { keys, error in
            guard let keys = keys else {
                completion(nil, error)
                return
            }
            
            let file = File.with { file in
                file.key = keys.map { diagnosisKey in
                    Key.with { key in
                        key.keyData = diagnosisKey.keyData
                        key.rollingPeriod = diagnosisKey.rollingPeriod
                        key.rollingStartNumber = diagnosisKey.rollingStartNumber
                        key.transmissionRiskLevel = Int32(diagnosisKey.transmissionRiskLevel)
                    }
                }
            }

            do {
                let data = try file.serializedData()
                let localUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("diagnosisKeys")
                try data.write(to: localUrl)
                completion(localUrl, nil)
            }
            catch {
                completion(nil, error)
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
        
        guard !self.enManager.exposureNotificationEnabled else {
            completion(nil)
            return
        }
        
        self.isUpdatingEnabledState = true
        
        print("ENManager.setExposureNotificationEnabled(true)")
        self.enManager.setExposureNotificationEnabled(true) { error in
            if let error = error {
                print("ERROR: \(error)")
                
                self.isUpdatingEnabledState = false
                completion(error)
                return
            }
            
            let unc = UNUserNotificationCenter.current()
            
            unc.requestAuthorization(options: [ .alert, .sound, .badge ]) { success, error in

            }

            self.isUpdatingEnabledState = false
            
            self.setAutoStartIfPossible(flag: error == nil)

            completion(error)
        }
    }
    
    func exposureNotificationStatusUpdated() {
        print("Exposure notification status update: \(self.enManager.exposureNotificationStatus)")
        
        self.isContactTracingEnabled = self.enManager.exposureNotificationEnabled
        
        if self.enManager.exposureNotificationStatus == .active {
            self.performBackgroundUpdate { _ in
                
            }
        }
    }
    
    func stopTracing() {
        guard self.enManager.exposureNotificationEnabled else {
            return
        }
        
        guard !self.isUpdatingEnabledState else {
            return
        }
        
        self.setAutoStartIfPossible(flag: false)

        self.isUpdatingEnabledState = true
        
        print("ENManager.setExposureNotificationEnabled(false)")
        self.enManager.setExposureNotificationEnabled(false) { error in
            if let error = error {
                print("Error: \(error)")
            }

            self.isUpdatingEnabledState = false
        }
    }
}

extension ContactTraceManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // This prevents the notification from appearing when in the foreground
        completionHandler([ .alert, .badge, .sound ])
        
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

        // TODO: Rethink how this works
        completion(nil)
        /*
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
 */
    }
}

extension ENStatus: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .active: return "Active"
        case .disabled: return "Disabled"
        case .restricted: return "Restricted"
        case .unknown: return "Unknown"
        case .bluetoothOff: return "Bluetooth Off"
        @unknown default: return "Unknown Default"
        }
    }
}
