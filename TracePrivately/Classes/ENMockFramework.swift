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
    var authorizationStatus: ENAuthorizationStatus { get }
    var authorizationMode: ENAuthorizationMode { get set }
}

typealias ENIntervalNumber = UInt32

typealias ENAttenuation = UInt8
 
public enum ENRiskLevel : UInt8 {

    
    case invalid = 0 /// Invalid level. Used when it isn't available.

    /// Invalid level. Used when it isn't available.
    case lowest = 1 /// Lowest risk.

    /// Lowest risk.
    case low = 10 /// Low risk.

    /// Low risk.
    case lowMedium = 25 /// Risk between low and medium.

    /// Risk between low and medium.
    case medium = 50 /// Medium risk.

    /// Medium risk.
    case mediumHigh = 65 /// Risk between medium and high.

    /// Risk between medium and high.
    case high = 80 /// High risk.

    /// High risk.
    case veryHigh = 90 /// Very high risk.

    /// Very high risk.
    case highest = 100 /// Highest risk.
}

class ENTemporaryExposureKey {
    var keyData: Data!
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
 
enum ENStatus : Int {

    
    /// Status of Exposure Notification is unknown. This is the status before ENManager has activated successfully.
    case unknown = 0

    
    /// Exposure Notification is active on the system.
    case active = 1

    
    /// Exposure Notification is disabled. setExposureNotificationEnabled:completionHandler can be used to enable it.
    case disabled = 2

    
    /// Bluetooth has been turned off on the system. Bluetooth is required for Exposure Notification.
        /// Note: this may not match the state of Bluetooth as reported by CoreBluetooth.
        /// Exposure Notification is a system service and can use Bluetooth in situations when apps cannot.
        /// So for the purposes of Exposure Notification, it's better to use this API instead of CoreBluetooth.
    case bluetoothOff = 3

    
    /// Exposure Notification is not active due to system restrictions, such as parental controls.
        /// When in this state, the app cannot enable Exposure Notification.
    case restricted = 4
}


class ENManager: ENBaseRequest {

    var exposureNotificationStatus: ENStatus {
        // TODO: Implement properly
        return .active
    }
    
    func setExposureNotificationEnabled(_ flag: Bool, completion: @escaping ENErrorHandler) {
        // TODO: Doesn't do anything
        // TODO: Request permission here
        completion(nil)
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
        // TODO: Show auth dialog here
        completionHandler(nil)
    }
}

typealias ENRiskScore = UInt8
 
struct ENExposureDetectionSummary {
    let daysSinceLastExposure: Int
    let matchedKeyCount: UInt64
    let maximumRiskScore: ENRiskScore // TODO: Make use of this.
}

typealias ENExposureDetectionFinishCompletion = ((ENExposureDetectionSummary?, Swift.Error?) -> Void)

typealias ENGetExposureInfoCompletion = (([ENExposureInfo]?, Bool, Swift.Error?) -> Void)

class ENExposureConfiguration {
    init() {
        self.minimumRiskScore = 0
        
        self.attenuationScores = [ 1, 2, 3, 4, 5, 6, 7, 8 ]
        self.daysSinceLastExposureScores = [ 1, 2, 3, 4, 5, 6, 7, 8 ]
        self.durationScores = [ 1, 2, 3, 4, 5, 6, 7, 8 ]
        self.transmissionRiskScores = [ 1, 2, 3, 4, 5, 6, 7, 8 ]

        self.daysSinceLastExposureWeight = 100
        self.attenuationWeight = 100
        self.durationWeight = 100
        self.transmissionRiskWeight = 100
    }
    
    /// Minimum risk score. Excludes exposure incidents with scores lower than this. Defaults to no minimum.
    var minimumRiskScore: ENRiskScore

    
    //---------------------------------------------------------------------------------------------------------------------------
    /**    @brief    Scores for attenuation buckets. Must contain 8 scores, one for each bucket as defined below:
        
        attenuationScores[0] when Attenuation > 73.
        attenuationScores[1] when 73 >= Attenuation > 63.
        attenuationScores[2] when 63 >= Attenuation > 51.
        attenuationScores[3] when 51 >= Attenuation > 33.
        attenuationScores[4] when 33 >= Attenuation > 27.
        attenuationScores[5] when 27 >= Attenuation > 15.
        attenuationScores[6] when 15 >= Attenuation > 10.
        attenuationScores[7] when 10 >= Attenuation.
    */
    var attenuationScores: [NSNumber]

    
    /// Weight to apply to the attenuation score. Must be in the range 0-100.
    var attenuationWeight: Double

    
    //---------------------------------------------------------------------------------------------------------------------------
    /**    @brief    Scores for days since last exposure buckets. Must contain 8 scores, one for each bucket as defined below:
    
        daysSinceLastExposureScores[0] when Days >= 14.
        daysSinceLastExposureScores[1] else Days >= 12
        daysSinceLastExposureScores[2] else Days >= 10
        daysSinceLastExposureScores[3] else Days >= 8
        daysSinceLastExposureScores[4] else Days >= 6
        daysSinceLastExposureScores[5] else Days >= 4
        daysSinceLastExposureScores[6] else Days >= 2
        daysSinceLastExposureScores[7] else Days >= 0
    */
    var daysSinceLastExposureScores: [NSNumber]

    
    /// Weight to apply to the days since last exposure score. Must be in the range 0-100.
    var daysSinceLastExposureWeight: Double

    
    //---------------------------------------------------------------------------------------------------------------------------
    /**    @brief    Scores for duration buckets. Must contain 8 scores, one for each bucket as defined below:
    
        durationScores[0] when Duration == 0
        durationScores[1] else Duration <= 5
        durationScores[2] else Duration <= 10
        durationScores[3] else Duration <= 15
        durationScores[4] else Duration <= 20
        durationScores[5] else Duration <= 25
        durationScores[6] else Duration <= 30
        durationScores[7] else Duration  > 30
    */
    var durationScores: [NSNumber]

    
    /// Weight to apply to the duration score. Must be in the range 0-100.
    var durationWeight: Double

    
    //---------------------------------------------------------------------------------------------------------------------------
    /**    @brief    Scores for transmission risk buckets. Must contain 8 scores, one for each bucket as defined below:
    
        transmissionRiskScores[0] for ENRiskLevelLowest.
        transmissionRiskScores[1] for ENRiskLevelLow.
        transmissionRiskScores[2] for ENRiskLevelLowMedium.
        transmissionRiskScores[3] for ENRiskLevelMedium.
        transmissionRiskScores[4] for ENRiskLevelMediumHigh.
        transmissionRiskScores[5] for ENRiskLevelHigh.
        transmissionRiskScores[6] for ENRiskLevelVeryHigh.
        transmissionRiskScores[7] for ENRiskLevelHighest.
    */
    var transmissionRiskScores: [NSNumber]

    
    /// Weight to apply to the transmission risk score. Must be in the range 0-100.
    var transmissionRiskWeight: Double
}

class ENExposureDetectionSession: ENBaseRequest {
    var configuration = ENExposureConfiguration()
    var maximumKeyCount: Int = 10
    
    private var _infectedKeys: [ENTemporaryExposureKey] = []

    private static let maximumFakeMatches = 5
    
    private var remoteInfectedKeys: [ENTemporaryExposureKey] {
        // Filters out keys for local device for the purposes of better testing
        
        let localDeviceId = ENInternalState.shared.localDeviceId.data
        
        return self._infectedKeys.filter { key in
            return key.keyData != localDeviceId
        }
    }

    func addDiagnosisKeys(_ keys: [ENTemporaryExposureKey], completionHandler: @escaping ENErrorHandler) {
        enQueue.sync {
            self._infectedKeys.append(contentsOf: keys)
        }
        
        let queue = self.dispatchQueue ?? .main
        
        queue.asyncAfter(deadline: .now() + 0.5) {
            completionHandler(nil)
        }
    }
    
    func finishedDiagnosisKeys(completionHandler: @escaping ENExposureDetectionFinishCompletion) {
        
        let delay: TimeInterval = 0.5
        
        let queue = self.dispatchQueue ?? .main

        queue.asyncAfter(deadline: .now() + delay) {
            let keys = enQueue.sync { return self.remoteInfectedKeys }
            
            let summary = ENExposureDetectionSummary(
                daysSinceLastExposure: 0,
                matchedKeyCount: UInt64(min(Self.maximumFakeMatches, keys.count)),
                maximumRiskScore: 8
            )
            
            completionHandler(summary, nil)
        }

    }
    
    private var cursor: Int = 0
    
    func getExposureInfo(withMaximumCount maximumCount: Int, completionHandler: @escaping ENGetExposureInfoCompletion) {
        
        let queue: DispatchQueue = self.dispatchQueue ?? .main

        let delay: TimeInterval = 0.5
                
        queue.asyncAfter(deadline: .now() + delay) {
            guard !self.isInvalidated else {
                self.cursor = 0
                completionHandler(nil, true, ENError(code: .invalidated))
                return
            }

            // For now this is assuming that every key is infected. Obviously this isn't accurate, just useful for testing.
            let allKeys: [ENTemporaryExposureKey] = enQueue.sync { self.remoteInfectedKeys }
            
            guard allKeys.count > 0 else {
                completionHandler([], true, nil)
                return
            }
            
            let allMatchedKeys: [ENTemporaryExposureKey] = Array(allKeys[0 ..< min(Self.maximumFakeMatches, allKeys.count)])
            
            let fromIndex = self.cursor
            let toIndex   = min(allMatchedKeys.count, self.cursor + Int(maximumCount))
            
            guard fromIndex < toIndex else {
                self.cursor = 0
                completionHandler([], true, nil)
                return
            }
            
            let keys = Array(allMatchedKeys[fromIndex ..< toIndex])
            
            let contacts: [ENExposureInfo] = keys.compactMap { key in

                let date = Date(timeIntervalSince1970: TimeInterval(key.rollingStartNumber * 600))
                let duration: TimeInterval = 15 * 60

                return ENExposureInfo(
                    attenuationValue: 0,
                    date: date,
                    duration: duration,
                    totalRiskScore: 51,
                    transmissionRiskLevel: .medium
                )
            }
            
            let inDone = toIndex >= allMatchedKeys.count
            self.cursor = inDone ? 0 : toIndex
            
            completionHandler(contacts, inDone, nil)
        }
    }
}

struct ENExposureInfo {
    let attenuationValue: ENAttenuation
    let date: Date
    let duration: TimeInterval
    let totalRiskScore: ENRiskScore
    let transmissionRiskLevel: ENRiskLevel
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
    var authorizationStatus: ENAuthorizationStatus = .unknown
    var authorizationMode: ENAuthorizationMode = .defaultMode
    
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
                
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Deny", style: .cancel, handler: { action in
                    completionHandler(ENError(code: .notAuthorized))
                    return
                }))

                alert.addAction(UIAlertAction(title: "Allow", style: .default, handler: { action in
                    self.activateWithPermission(queue: queue, completionHandler: completionHandler)
                }))
                
                guard let vc = UIApplication.shared.windows.first?.rootViewController else {
                    completionHandler(ENError(code: .unknown))
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
        else {
            let queue = self.dispatchQueue ?? .main
            self.activateWithPermission(queue: queue, completionHandler: completionHandler)
        }
    }
    
    fileprivate func activateWithPermission(queue: DispatchQueue, completionHandler: @escaping (Error?) -> Void) {
        queue.async {
            print("Should be overridden")
            completionHandler(nil)
        }
    }
}

fileprivate let enQueue = DispatchQueue(label: "TracePrivately", qos: .default, attributes: [])

class ENBaseRequest: ENActivatable {
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
            print("Should be overridden")
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
                
                let intervalNumber = ENIntervalNumber(date.timeIntervalSince1970 / 600)
                let rollingStartNumber = intervalNumber / 144 * 144

                
                
                let key = ENTemporaryExposureKey()
                key.keyData = keyData
                key.rollingStartNumber = rollingStartNumber
                key.transmissionRiskLevel = .high // TODO: Make better use of risk level
                
                keys.append(key)
            }
            
            print("Generated keys: \(keys)")

            return keys
        }
    }

}

extension UUID {
    var data: Data {
        return withUnsafePointer(to: self.uuid) {
            Data(bytes: $0, count: MemoryLayout.size(ofValue: self.uuid))
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

