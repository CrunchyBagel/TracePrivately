//
//  CTMockFramework.swift
//  TracePrivately
//

import UIKit

typealias CTErrorHandler = ((Swift.Error?) -> Void)

/// The type definition for the completion handler
typealias CTExposureDetectionFinishHandler = (CTExposureDetectionSummary?, Error?) -> Void

/// The type definition for the completion handler
typealias CTExposureDetectionContactHandler = ([CTContactInfo]?, Error?) -> Void

///The type definition for the completion handler.
typealias CTSelfTracingInfoGetCompletion = (CTSelfTracingInfo?, Error?) -> Void

/// I'm only guessing at these states
enum CTManagerState {
    case unknown
    case on
    case off
}

/// Requests whether contact tracing is on or off on the device
class CTStateGetRequest: CTBaseRequest {
    /// This property holds the completion handler that framework invokes when the request completes. The property is cleared upon completion to break any potential retain cycles.
    var completionHandler: CTErrorHandler?

    ///This property contains the snapshot of the state when the request was performed. It’s valid only after the framework invokes the completion handler.
    var state: CTManagerState = .unknown

    /// Asynchronously performs the request to get the state, and invokes the completion handler when it's done.
    func perform() {
        guard !self.isInvalidated else {
            completionHandler?(CTError.requestIsInvalidated)
            self.completionHandler = nil
            return
        }
        
        guard !self.isRunning else {
            // Silently fail?
            return
        }
        
        self.isRunning = true
        
        let queue: DispatchQueue = dispatchQueue ?? .main
        
        let delay: TimeInterval = 0.5
        
        queue.asyncAfter(deadline: .now() + delay) {
            guard !self.isInvalidated else {
                // I guess don't call handler here
                self.completionHandler = nil
                return
            }
            
            if CTInternalState.shared.state == .unknown {
                CTInternalState.shared.state = .off
            }
            
            self.state = CTInternalState.shared.state

            self.completionHandler?(nil)
            self.completionHandler = nil
            
            self.isRunning = false
        }
    }
}

/// Changes the state of contact tracing on the device.
class CTStateSetRequest: CTBaseRequest {
    /// This property holds the completion handler that framework invokes when the request completes. The property is cleared upon completion to break any potential retain cycles.
    var completionHandler: CTErrorHandler?

    /// This property contains the state to set Contact Tracing to. Call the perform method to apply the state once set.
    var state: CTManagerState = .unknown
    
    /// Asynchronously performs the request to get the state, and invokes the completion handler when it's done.
    func perform() {
     
        let queue: DispatchQueue = dispatchQueue ?? .main

        guard !self.isInvalidated else {
            let completion = self.completionHandler
            self.completionHandler = nil

            queue.async {
                completion?(CTError.requestIsInvalidated)
            }
            
            return
        }
        
        guard !self.isRunning else {
            // Silently fail?
            return
        }
        
        let validStates: [CTManagerState] = [ .off, .on ]
        
        let state = self.state
        
        guard validStates.contains(state) else {
            completionHandler?(CTError.invalidState)
            self.completionHandler = nil
            return
        }
        
        self.isRunning = true
        
        
        let delay: TimeInterval = 0.5
        
        queue.asyncAfter(deadline: .now() + delay) {
            guard !self.isInvalidated else {
                // I guess don't call handler here
                self.completionHandler = nil
                return
            }
            
            CTInternalState.shared.state = state
            
            self.completionHandler?(nil)
            self.completionHandler = nil
            
            self.isRunning = false
        }
    }
}

/// Performs exposure detection bad on previously collected proximity data and keys.
class CTExposureDetectionSession: CTBaseRequest {
    /// This property contains the maximum number of keys to provide to this API at once. This property’s value updates after each operation complete and before the completion handler is invoked. Use this property to throttle key downloads to avoid excessive buffering of keys in memory.
    var maxKeyCount: Int = 0
    
    private var _permissionAllowed = false
    fileprivate var permissionAllowed: Bool {
        get {
            return ctQueue.sync {
                return self._permissionAllowed
            }
        }
        set {
            ctQueue.sync {
                self._permissionAllowed = newValue
            }
        }
    }

    /// Activates the session and requests authorization for the app with the user. Properties and methods cannot be used until this completes successfully.
    func activateWithCompletion(_ completion: @escaping CTErrorHandler) {
        
        guard !self.isInvalidated else {
            let queue: DispatchQueue = self.dispatchQueue ?? .main
            
            queue.async {
                completion(CTError.invalidState)
            }
            
            return
        }
        
        let alert = UIAlertController(title: "Permission", message: "Press OK to allow this app to check if you have been exposed to COVID-19.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Deny", style: .cancel, handler: { action in
            let queue: DispatchQueue = self.dispatchQueue ?? .main
            
            queue.async {
                completion(CTError.permissionDenied)
            }
        }))

        alert.addAction(UIAlertAction(title: "Allow", style: .default, handler: { action in
            let queue: DispatchQueue = self.dispatchQueue ?? .main
            
            queue.async {
                self.permissionAllowed = true
                completion(CTError.permissionDenied)
            }
        }))
        
        guard let vc = UIApplication.shared.windows.first?.rootViewController else {
            completion(CTError.unknownError)
            return
        }
        
        DispatchQueue.main.async {
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    /// Asynchronously adds the specified keys to the session to allow them to be checked for exposure. Each call to this method must include more keys than specified by the current value of <maxKeyCount>.
    func addPositiveDiagnosisKey(inKeys keys: [CTDailyTracingKey], completion: @escaping (CTErrorHandler)) {
        
        guard !self.isInvalidated else {
            let queue: DispatchQueue = self.dispatchQueue ?? .main
            
            queue.async {
                completion(CTError.invalidState)
            }
            
            return
        }

    }
    
    /// Indicates all of the available keys have been provided. Any remaining detection will be performed and the completion handler will be invoked with the results.
    func finishedPositiveDiagnosisKeys(completion: @escaping CTExposureDetectionFinishHandler) {
        guard !self.isInvalidated else {
            let queue: DispatchQueue = self.dispatchQueue ?? .main
            
            queue.async {
                completion(nil, CTError.invalidState)
            }
            
            return
        }

    }
    
    /// Obtains information on each incident. This can only be called once the detector finishes. The handler may be invoked multiple times. An empty array indicates the final invocation of the hander.
    func getContactInfoWithHandler(completion: @escaping CTExposureDetectionContactHandler) {
        guard !self.isInvalidated else {
            let queue: DispatchQueue = self.dispatchQueue ?? .main
            
            queue.async {
                completion(nil, CTError.invalidState)
            }
            
            return
        }

    }
}

/// Provides a summary on exposures.
class CTExposureDetectionSummary {
    /// This property holds the number of keys that matched for an exposure detection.
    var matchedKeyCount: Int?
}

/// Requests the daily tracing keys used by this device to share with a server.
class CTSelfTracingInfoRequest: CTBaseRequest {
    /// This request is intended to be called when a user has a positive diagnosis. Once the keys are shared with a server, other users can use the keys to check if their device has been in contact with any positive diagnosis users. Each request will require the user to authorize access.
    /// Keys will be reported for the previous 14 days of contact tracing. The app will also be launched every day after the daily tracing key changes to allow it to request again to get the key for each previous day for the next 14 days.

    /// This property invokes this completion handler when the request completes and clears the property to break any potential retain cycles.
    var completionHandler: CTSelfTracingInfoGetCompletion?
    
    /// Asynchronously performs the request to get the state, and invokes the completion handler when it's done.
    func perform() {
        guard !self.isInvalidated else {
            completionHandler?(nil, CTError.requestIsInvalidated)
            self.completionHandler = nil
            return
        }
        
        guard !self.isRunning else {
            // Silently fail?
            return
        }
        
        self.isRunning = true
        
        let queue: DispatchQueue = dispatchQueue ?? .main
        
        let delay: TimeInterval = 0.5
        
        queue.asyncAfter(deadline: .now() + delay) {
            guard !self.isInvalidated else {
                // I guess don't call handler here
                self.completionHandler = nil
                return
            }
            
            let keys: [CTDailyTracingKey] = CTInternalState.shared.dailyKeys.map { CTDailyTracingKey(keyData: $0) }
            
            let summary = CTSelfTracingInfo(dailyTracingKeys: keys)
            
            self.completionHandler?(summary, nil)
            self.completionHandler = nil
            
            self.isRunning = false
        }
    }
}

/// Contains the Daily Tracing Keys.
class CTSelfTracingInfo {
    /// Daily tracing keys available at the time of the request.
    let dailyTracingKeys: [CTDailyTracingKey]
    
    init(dailyTracingKeys: [CTDailyTracingKey]) {
        self.dailyTracingKeys = dailyTracingKeys
    }
}


/// Contains information about a single contact incident.
class CTContactInfo {
    /// How long the contact was in proximity. Minimum duration is 5 minutes and increments by 5 minutes: 5, 10, 15, etc.
    let duration: TimeInterval
    /// This property contains the time when the contact occurred. This may have reduced precision, such as within one day of the actual time.
    let timestamp: Date // TODO: This uses CFAbsoluteTime
    
    init(duration: TimeInterval, timestamp: Date) {
        self.duration = duration
        self.timestamp = timestamp
    }
}

/// The Daily Tracing Key object
class CTDailyTracingKey {
    /// This property contains the Daily Tracing Key information.
    let keyData: Data
    
    init(keyData: Data) {
        self.keyData = keyData
    }
}





/// Not part of the published framework

fileprivate let ctQueue = DispatchQueue(label: "TracePrivately", qos: .default, attributes: [])

private class CTInternalState {
    
    static let shared = CTInternalState()
    
    private var _state: CTManagerState = .unknown
    
    fileprivate var state: CTManagerState {
        get {
            return ctQueue.sync {
                return self._state
            }
        }
        set {
            ctQueue.sync {
                self._state = newValue
            }
        }
    }

    private init() {
        
    }
    
    // There's currently no stability with the keys here so it's going to tricky to properly test for now
    var dailyKeys: [Data] {
        return ctQueue.sync {
            
            var keys: [UUID] = []
            
            for _ in 0 ..< 14 {
                keys.append(UUID())
            }
            
            return keys.map { $0.data }
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

enum CTError: LocalizedError {
    case requestIsInvalidated
    case requestAlreadyRunning
    case invalidState
    case unknownError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .requestIsInvalidated: return "Invalidated request"
        case .requestAlreadyRunning: return "Already running"
        case .invalidState: return "Invalid state"
            
        case .unknownError: return "Unknown error"
        case .permissionDenied: return "Permission denied"
        }
    }
}

class CTBaseRequest {
    /// This property holds the the dispatch queue used to invoke handlers on. If this property isn’t set, the framework uses the main queue.
    var dispatchQueue: DispatchQueue?
    
    private var _isRunning = false
    fileprivate var isRunning: Bool {
        get {
            return ctQueue.sync {
                return self._isRunning
            }
        }
        set {
            ctQueue.sync {
                self._isRunning = newValue
            }
        }
    }
    
    private var _isInvalidated = false
    fileprivate var isInvalidated: Bool {
        get {
            return ctQueue.sync {
                return self._isInvalidated
            }
        }
        set {
            ctQueue.sync {
                self._isInvalidated = newValue
            }
        }
    }
    
    /// Invalidates a previously initiated request. If there is an outstanding completion handler, the framework will invoke it with an error.
    /// Don’t reuse the request after this is called. If you require another request, create a new one.
    func invalidate() {
        self.isInvalidated = true
    }

}
