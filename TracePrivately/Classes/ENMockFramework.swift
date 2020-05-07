//
//  ENMockFramework.swift
//  TracePrivately
//

import Foundation
import UIKit

/// To use the real ExposureNotifications framework, just comment out this entire file. You must be running iOS 13.4 or newer

enum ENErrorCode: Int {
    case unknown
    case badParameter
    case notEntitled
    case notAuthorized
    case unsupported
    case invalidated
    case bluetoothOff
    case insufficientStorage
    case notEnabled
    case apiMisuse
    case `internal`
    case insufficientMemory
    case rateLimited
    
    var localizedTitle: String {
        switch self {
        case .unknown: return "Unknown"
        case .badParameter: return "Bad Parameter"
        case .notEntitled: return "Not Entitled"
        case .notAuthorized: return "Not Authorized"
        case .unsupported: return "Unsupported"
        case .invalidated: return "Invalidated"
        case .bluetoothOff: return "Bluetooth Off"
        case .insufficientStorage: return "Insufficient Storage"
        case .notEnabled: return "Not Enabled"
        case .apiMisuse: return "API Miuse"
        case .internal: return "Internal Error"
        case .insufficientMemory: return "Insufficient Memory"
        case .rateLimited: return "Rate Limited"
        }
    }
}

struct ENError: LocalizedError {
    let code: ENErrorCode
    
    var localizedDescription: String {
        return code.localizedTitle
    }
}

enum ENAuthorizationMode {
    case defaultMode
    case nonUi
    case ui
}

enum ENAuthorizationStatus {
    case unknown
    case restricted
    case notAuthorized
    case authorized
}

typealias ENErrorHandler = ((Error?) -> Void)

protocol ENActivatable {
    var dispatchQueue: DispatchQueue? { get set }
    var invalidationHandler: (() -> Void)? { get set }
    
    func activate(_ completionHandler: @escaping ENErrorHandler)
    func invalidate()
}

protocol ENAuthorizable {

}

typealias ENIntervalNumber = UInt32

typealias ENAttenuation = UInt8
 
typealias ENRiskLevel = UInt8

class ENTemporaryExposureKey {
    var keyData: Data!
    var rollingPeriod: ENIntervalNumber!
    var rollingStartNumber: ENIntervalNumber!
    var transmissionRiskLevel: ENRiskLevel!
    
    init() {
        
    }
}

extension ENTemporaryExposureKey {
    // This is used so we can resolve a date from the key
    var ymd: DateComponents? {
        guard let str = self.stringValue else {
            return nil
        }
        
        let parts = str.components(separatedBy: "_")
        
        guard parts.count == 2 else {
            return nil
        }
        
        let yyyymmdd = parts[1]
        
        guard yyyymmdd.count == 8 else {
            return nil
        }
        
        let y = Int(String(yyyymmdd[0 ... 3]))
        let m = Int(String(yyyymmdd[4 ... 5]))
        let d = Int(String(yyyymmdd[6 ... 7]))
        
        var dc = DateComponents()
        dc.year = y
        dc.month = m
        dc.day = d
        
        return dc
    }

    fileprivate var stringValue: String? {
        return String(data: self.keyData, encoding: .utf8)
    }
}

typealias ENGetDiagnosisKeysHandler = ([ENTemporaryExposureKey]?, Error?) -> Void
 
@objc enum ENStatus : Int {
    case unknown = 0
    case active = 1
    case disabled = 2
    case bluetoothOff = 3
    case restricted = 4
}


class ENManager: ENBaseRequest {

    @objc dynamic private(set) var exposureNotificationStatus: ENStatus = .unknown
    
    @objc dynamic private(set) var exposureNotificationEnabled = false
    
    static var authorizationStatus: ENAuthorizationStatus { return .authorized }
    
    override func activate(queue: DispatchQueue, completionHandler: @escaping (Error?) -> Void) {
        print("Activating ENManager ...")

        let queue = self.dispatchQueue ?? .main
        
        queue.asyncAfter(deadline: .now() + 0.1) {
            let status = self.mockStatus
            
            if status != .unknown {
                self.exposureNotificationStatus = status
            }
            
            completionHandler(nil)
        }
    }
    
    private func saveMockStatus(status: ENStatus) {
        UserDefaults.standard.set(status.rawValue, forKey: "_mock_status")
        UserDefaults.standard.synchronize()
    }
    
    private var mockStatus: ENStatus {
        let val = UserDefaults.standard.integer(forKey: "_mock_status")
        return ENStatus(rawValue: val) ?? .unknown
    }
    
    func setExposureNotificationEnabled(_ flag: Bool, completionHandler: @escaping ENErrorHandler) {
        if !flag {
            self.exposureNotificationEnabled = false
            completionHandler(nil)
            return
        }

        switch self.exposureNotificationStatus {
        case .bluetoothOff:
            completionHandler(ENError(code: .bluetoothOff))
            return

        case .restricted:
            completionHandler(ENError(code: .notAuthorized))
            return

        case .active:
            let queue = self.dispatchQueue ?? .main
            
            queue.asyncAfter(deadline: .now() + 0.3) {
                self.exposureNotificationEnabled = flag
                completionHandler(nil)
            }
            
        case .disabled, .unknown:
            self.showAuthorizationPrompt(title: nil, message: nil) { allowed in
                self.exposureNotificationStatus = allowed ? .active : .disabled
                
                if allowed {
                    let queue = self.dispatchQueue ?? .main
                    
                    queue.asyncAfter(deadline: .now() + 0.3) {
                        self.saveMockStatus(status: .active)
                        self.exposureNotificationEnabled = flag
                        completionHandler(nil)
                    }
                }
                else {
                    self.saveMockStatus(status: .disabled)
                    self.exposureNotificationEnabled = false
                    completionHandler(ENError(code: .notAuthorized))
                }
            }
        }
    }

//    override var permissionDialogMessage: String? {
//        return "Allow this app to retrieve your anonymous tracing keys?"
//    }
    
    func getDiagnosisKeys(completionHandler: @escaping ENGetDiagnosisKeysHandler) {
        
        let delay: TimeInterval = 0.5
        
        let queue = self.dispatchQueue ?? .main
        
        queue.asyncAfter(deadline: .now() + delay) {
            completionHandler(ENInternalState.shared.dailyKeys, nil)
        }
    }
    
    func resetAllData(completionHandler: @escaping ENErrorHandler) {
        
        self.showAuthorizationPrompt(title: nil, message: nil) { allowed in
            if allowed {
                let queue = self.dispatchQueue ?? .main
                
                queue.asyncAfter(deadline: .now() + 0.2) {
                    completionHandler(nil)
                }
            }
            else {
                completionHandler(ENError(code: .notAuthorized))
            }
        }
    }
}

typealias ENRiskScore = UInt8
 
class ENExposureDetectionSummary {
    var daysSinceLastExposure: Int!
    var matchedKeyCount: UInt64!
    var maximumRiskScore: ENRiskScore!
    var attenuationDurations: [NSNumber]!
    var metadata: [AnyHashable : Any]?
}

typealias ENExposureDetectionFinishCompletion = ((ENExposureDetectionSummary?, Swift.Error?) -> Void)

typealias ENGetExposureInfoCompletion = (([ENExposureInfo]?, Bool, Swift.Error?) -> Void)

class ENExposureConfiguration {
    init() {
        self.minimumRiskScore = 0
        
        self.attenuationLevelValues = [ 1, 2, 3, 4, 5, 6, 7, 8 ]
        self.daysSinceLastExposureLevelValues = [ 1, 2, 3, 4, 5, 6, 7, 8 ]
        self.durationLevelValues = [ 1, 2, 3, 4, 5, 6, 7, 8 ]
        self.transmissionRiskLevelValues = [ 1, 2, 3, 4, 5, 6, 7, 8 ]

        self.daysSinceLastExposureWeight = 100
        self.attenuationWeight = 100
        self.durationWeight = 100
        self.transmissionRiskWeight = 100
    }
    
     var metadata: [AnyHashable : Any]?
    var minimumRiskScore: ENRiskScore
    var attenuationLevelValues: [NSNumber]
    var attenuationWeight: Double
    var daysSinceLastExposureLevelValues: [NSNumber]
    var daysSinceLastExposureWeight: Double
    var durationLevelValues: [NSNumber]
    var durationWeight: Double
    var transmissionRiskLevelValues: [NSNumber]
    var transmissionRiskWeight: Double
}

typealias ENDetectExposuresHandler = (ENExposureDetectionSummary?, Error?) -> Void
typealias ENGetExposureInfoHandler = ([ENExposureInfo]?, Error?) -> Void

extension ENManager {
    private static let maximumFakeMatches = 5
    
    private func remoteInfectedKeys(keys: [ENTemporaryExposureKey]) -> [ENTemporaryExposureKey] {
        // Filters out keys for local device for the purposes of better testing
        
        let localDeviceId = ENInternalState.shared.localDeviceId.data
        
        return keys.filter { key in
            return key.keyData != localDeviceId
        }
    }

    // TODO: Get this working with URLs
    @discardableResult func detectExposures(configuration: ENExposureConfiguration, diagnosisKeyURLs: [URL], completionHandler: @escaping ENDetectExposuresHandler) -> Progress {
        
        let delay: TimeInterval = 0.5
        
        let queue = self.dispatchQueue ?? .main

        queue.asyncAfter(deadline: .now() + delay) {
            let keys = enQueue.sync { return self.remoteInfectedKeys }
            
            let summary = ENExposureDetectionSummary()
            summary.daysSinceLastExposure = 0
            summary.matchedKeyCount = 0 // TODO: Fix UInt64(min(Self.maximumFakeMatches, keys.count)),
            summary.maximumRiskScore = 0 // TODO: Fix
            /// Array index 0: Sum of durations for all exposures when attenuation was <= 50.
            /// Array index 1: Sum of durations for all exposures when attenuation was > 50.
            /// These durations are aggregated across all exposures and capped at 30 minutes.
            summary.attenuationDurations = [ 0, 0 ]
            summary.metadata = nil
            
            completionHandler(summary, nil)
        }

        return Progress(totalUnitCount: 1) // TODO: Ensure this works right
    }
    
    @discardableResult func getExposureInfo(summary: ENExposureDetectionSummary, userExplanation: String, completionHandler: @escaping ENGetExposureInfoHandler) -> Progress {
        
        let queue: DispatchQueue = self.dispatchQueue ?? .main

        let delay: TimeInterval = 0.5
                
        queue.asyncAfter(deadline: .now() + delay) {
            guard !self.isInvalidated else {
                completionHandler(nil, ENError(code: .invalidated))
                return
            }

            // For now this is assuming that every key is infected. Obviously this isn't accurate, just useful for testing.
            let allKeys: [ENTemporaryExposureKey] = [] // TODO: Fix enQueue.sync { self.remoteInfectedKeys }
            
            guard allKeys.count > 0 else {
                completionHandler([], nil)
                return
            }
            
            let allMatchedKeys: [ENTemporaryExposureKey] = Array(allKeys[0 ..< min(Self.maximumFakeMatches, allKeys.count)])
            
            let contacts: [ENExposureInfo] = allMatchedKeys.compactMap { key in

                let date = Date(timeIntervalSince1970: TimeInterval(key.rollingStartNumber * 600))
                let duration: TimeInterval = 15 * 60

                let exposure = ENExposureInfo()
                exposure.attenuationDurations = []
                exposure.attenuationValue = 0
                exposure.date = date
                exposure.duration = duration
                exposure.totalRiskScore = 8
                exposure.transmissionRiskLevel = 5
                exposure.metadata = nil

                return exposure
            }
            
            completionHandler(contacts, nil)
        }
        
        return Progress(totalUnitCount: 1) // TODO: Ensure this works right
    }
}

class ENExposureInfo {
    var attenuationDurations: [NSNumber]!
    var attenuationValue: ENAttenuation!
    var date: Date!
    var duration: TimeInterval!
    var metadata: [AnyHashable : Any]?
    var totalRiskScore: ENRiskScore!
    var transmissionRiskLevel: ENRiskLevel!
}

class ENSelfExposureResetRequest: ENAuthorizableBaseRequest {
    
    override var permissionDialogMessage: String? {
        return "Allow this app to reset your anonymous tracing keys?"
    }

    override fileprivate func activateWithPermission(queue: DispatchQueue, completionHandler: @escaping (Error?) -> Void) {
        
        print("Resetting keys ...")
        queue.asyncAfter(deadline: .now() + 0.5) {
            print("Finished resetting keys")
            
            // Nothing to do since we're generating fake stable keys for the purpose of testing
            completionHandler(nil)
        }
    }
}

class ENAuthorizableBaseRequest: ENBaseRequest, ENAuthorizable {
    fileprivate var permissionDialogTitle: String? {
        return nil
    }
    fileprivate var permissionDialogMessage: String? {
        return nil
    }
    
    fileprivate var shouldPrompt: Bool {
        return true
    }
    
    final override fileprivate func activate(queue: DispatchQueue, completionHandler: @escaping (Error?) -> Void) {
        
        if self.shouldPrompt {
            DispatchQueue.main.async {
                let title = self.permissionDialogTitle ?? "Permission"
                let message = self.permissionDialogMessage ?? "Allow this?"

                self.showAuthorizationPrompt(title: title, message: message) { allowed in
                    guard allowed else {
                        completionHandler(ENError(code: .notAuthorized))
                        return
                    }

                    self.activateWithPermission(queue: queue, completionHandler: completionHandler)
                }
            }
        }
        else {
            let queue = self.dispatchQueue ?? .main
            self.activateWithPermission(queue: queue, completionHandler: completionHandler)
        }
    }
    
    fileprivate func activateWithPermission(queue: DispatchQueue, completionHandler: @escaping (Error?) -> Void) {
        queue.async {
//            print("Should be overridden")
            completionHandler(nil)
        }
    }
}

fileprivate let enQueue = DispatchQueue(label: "TracePrivately", qos: .default, attributes: [])

class ENBaseRequest: NSObject, ENActivatable {
    /// This property holds the the dispatch queue used to invoke handlers on. If this property isn’t set, the framework uses the main queue.
    var dispatchQueue: DispatchQueue?
    
    private var _invalidationHandler: (() -> Void)?
    
    var invalidationHandler: (() -> Void)? {
        get {
            return enQueue.sync {
                return self._invalidationHandler
            }
        }
        set {
            enQueue.sync {
                self._invalidationHandler = newValue
            }
        }
    }
    
    private var _isRunning = false
    fileprivate var isRunning: Bool {
        get {
            return enQueue.sync {
                return self._isRunning
            }
        }
        set {
            enQueue.sync {
                self._isRunning = newValue
            }
        }
    }
    
    private var _isInvalidated = false
    fileprivate var isInvalidated: Bool {
        get {
            return enQueue.sync {
                return self._isInvalidated
            }
        }
        set {
            enQueue.sync {
                self._isInvalidated = newValue
            }
        }
    }

    final func activate(_ completionHandler: @escaping (Swift.Error?) -> Void) {
        
        let queue: DispatchQueue = self.dispatchQueue ?? .main
        
        self.isRunning = true
        
        self.activate(queue: queue) { error in
            guard !self.isInvalidated else {
                completionHandler(ENError(code: .invalidated))
                return
            }
            
            self.isRunning = false
            completionHandler(error)
        }
    }
    
    fileprivate func activate(queue: DispatchQueue, completionHandler: @escaping (Swift.Error?) -> Void) {
        queue.async {
//            print("Should be overridden")
            completionHandler(nil)
        }
    }
    
    func invalidate() {
        self.isInvalidated = true
        
        let queue: DispatchQueue = self.dispatchQueue ?? .main
        
        queue.async {
            self.invalidationHandler?()
            self.invalidationHandler = nil
        }
    }
    
    func showAuthorizationPrompt(title: String?, message: String?, completionHandler: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let title = title ?? "Permission"
            let message = message ?? "Allow this?"
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Deny", style: .cancel, handler: { action in
                completionHandler(false)
                return
            }))

            alert.addAction(UIAlertAction(title: "Allow", style: .default, handler: { action in
                completionHandler(true)
            }))
            
            guard let vc = UIApplication.shared.windows.first?.rootViewController else {
                completionHandler(false)
                return
            }
            
            if let presented = vc.presentedViewController {
                presented.present(alert, animated: true, completion: nil)
            }
            else {
                vc.present(alert, animated: true, completion: nil)
            }
        }
    }
}

private class ENInternalState {
    
    static let shared = ENInternalState()
    
    private var _tracingEnabled: Bool = false
    
    fileprivate var tracingEnabled: Bool {
        get {
            return enQueue.sync {
                return self._tracingEnabled
            }
        }
        set {
            enQueue.sync {
                self._tracingEnabled = newValue
            }
        }
    }

    private init() {
        
    }
    
    // This is only for testing as it would otherwise be considered identifiable. This class is purely
    // a mock implementation of Apple's framework, so allowances like this are made in order to help
    // develop and test.
    fileprivate lazy var localDeviceId: UUID = {
        return UIDevice.current.identifierForVendor!
    }()
    
    // These keys are stable for this device as they use a device specific ID with an index appended
    var dailyKeys: [ENTemporaryExposureKey] {
        return enQueue.sync {
            
            let deviceId = self.localDeviceId
            
            let calendar = Calendar(identifier: .gregorian)
            
            var todayDc = calendar.dateComponents([ .day, .month, .year ], from: Date())
            todayDc.hour = 12
            todayDc.minute = 0
            todayDc.second = 0
            
            guard let todayMidday = calendar.date(from: todayDc) else {
                return []
            }
            
            var keys: [ENTemporaryExposureKey] = []
            
            let keyData = deviceId.data
            
            for idx in 0 ..< 14 {
                guard let date = calendar.date(byAdding: .day, value: -idx, to: todayMidday, wrappingComponents: false) else {
                    continue
                }
                
//                let dc = calendar.dateComponents([ .day, .month, .year ], from: date)
//
//                let dateStr = String(format: "%04d%02d%02d", dc.year!, dc.month!, dc.day!)
//
//                let str = deviceId + "_" + dateStr
//
//                guard let keyData = str.data(using: .utf8) else {
//                    continue
//                }
                
                let rollingStartNumber = UInt32.intervalNumberFrom(date: date)
                
                let key = ENTemporaryExposureKey()
                key.keyData = keyData
                key.rollingPeriod = 144
                key.rollingStartNumber = rollingStartNumber
                key.transmissionRiskLevel = 0
                
                keys.append(key)
            }
            
            print("Generated keys: \(keys)")

            return keys
        }
    }

}

extension String {
    subscript (r: CountableClosedRange<Int>) -> String {
        get {
            let startIndex =  self.index(self.startIndex, offsetBy: r.lowerBound)
            let endIndex = self.index(startIndex, offsetBy: r.upperBound - r.lowerBound)
            return String(self[startIndex...endIndex])
        }
    }
}

