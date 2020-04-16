//
//  CTMockFramework.swift
//  TracePrivately
//

import UIKit

typealias CTErrorHandler = ((Swift.Error?) -> Void)

enum CTManagerState {
    case unknown
    case on
    case off
}

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
}

/// Requests whether contact tracing is on or off on the device
class CTStateGetRequest {
    /// This property holds the completion handler that framework invokes when the request completes. The property is cleared upon completion to break any potential retain cycles.
    var completionHandler: CTErrorHandler?
    
    /// This property holds the the dispatch queue used to invoke handlers on. If this property isn’t set, the framework uses the main queue.
    var dispatchQueue: DispatchQueue?
    
    ///This property contains the snapshot of the state when the request was performed. It’s valid only after the framework invokes the completion handler.
    var state: CTManagerState = .unknown
    
    
    
    enum CTError: LocalizedError {
        case requestIsInvalidated
        case requestAlreadyRunning
        
        var errorDescription: String? {
            switch self {
            case .requestIsInvalidated: return "Invalidated request"
            case .requestAlreadyRunning: return "Already running"
            }
        }
    }
    
    private var _isRunning = false
    private var isRunning: Bool {
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
    private var isInvalidated: Bool {
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
    
    /// Invalidates a previously initiated request. If there is an outstanding completion handler, the framework will invoke it with an error.
    /// Don’t reuse the request after this is called. If you require another request, create a new one.
    func invalidate() {
        self.isInvalidated = true
    }
}

/// Changes the state of contact tracing on the device.
class CTStateSetRequest {
    /// This property holds the completion handler that framework invokes when the request completes. The property is cleared upon completion to break any potential retain cycles.
    var completionHandler: CTErrorHandler?

    /// This property holds the the dispatch queue used to invoke handlers on. If this property isn’t set, the framework uses the main queue.
    var dispatchQueue: DispatchQueue?

    /// This property contains the state to set Contact Tracing to. Call the perform method to apply the state once set.
    var state: CTManagerState?
    
    /// Asynchronously performs the request to get the state, and invokes the completion handler when it's done.
    func perform() {
        
    }
    
    /// Invalidates a previously initiated request. If there is an outstanding completion handler, the framework will invoke it with an error.
    /// Don’t reuse the request after this is called. If you require another request, create a new one.
    func invalidate() {
        
    }
}

/// The type definition for the completion handler
typealias CTExposureDetectionFinishHandler = (CTExposureDetectionSummary?, Error?) -> Void

/// The type definition for the completion handler
typealias CTExposureDetectionContactHandler = ([CTContactInfo]?, Error?) -> Void

/// Performs exposure detection bad on previously collected proximity data and keys.
class CTExposureDetectionSession {
    /// This property holds the the dispatch queue used to invoke handlers on. If this property isn’t set, the framework uses the main queue.
    var dispatchQueue: DispatchQueue?
    
    /// This property contains the maximum number of keys to provide to this API at once. This property’s value updates after each operation complete and before the completion handler is invoked. Use this property to throttle key downloads to avoid excessive buffering of keys in memory.
    var maxKeyCount: Int = 0

    /// Activates the session and requests authorization for the app with the user. Properties and methods cannot be used until this completes successfully.
    func activateWithCompletion(_ inCompletion: CTErrorHandler) {
        
    }
    
    /// Invalidates the session. Any outstanding completion handlers will be invoked with an error. The session cannot be used after this is called. A new session must be created if another detection is needed.
    func invalidate() {
        
    }
    
    /// Asynchronously adds the specified keys to the session to allow them to be checked for exposure. Each call to this method must include more keys than specified by the current value of <maxKeyCount>.
    func addPositiveDiagnosisKey(inKeys keys: [CTDailyTracingKey], completion: @escaping (CTErrorHandler)) {
        
    }
    
    /// Indicates all of the available keys have been provided. Any remaining detection will be performed and the completion handler will be invoked with the results.
    func finishedPositiveDiagnosisKeys(completion: CTExposureDetectionFinishHandler) {
        
    }
    
    /// Obtains information on each incident. This can only be called once the detector finishes. The handler may be invoked multiple times. An empty array indicates the final invocation of the hander.
    func getContactInfoWithHandler(completion: CTExposureDetectionContactHandler) {
        
    }
}

/// Provides a summary on exposures.
class CTExposureDetectionSummary {
    /// This property holds the number of keys that matched for an exposure detection.
    var matchedKeyCount: Int?
}

///The type definition for the completion handler.
typealias CTSelfTracingInfoGetCompletion = (CTSelfTracingInfo?, Error?)

/// Requests the daily tracing keys used by this device to share with a server.
class CTSelfTracingInfoRequest {
    /// This request is intended to be called when a user has a positive diagnosis. Once the keys are shared with a server, other users can use the keys to check if their device has been in contact with any positive diagnosis users. Each request will require the user to authorize access.
    /// Keys will be reported for the previous 14 days of contact tracing. The app will also be launched every day after the daily tracing key changes to allow it to request again to get the key for each previous day for the next 14 days.

    /// This property invokes this completion handler when the request completes and clears the property to break any potential retain cycles.
    var completionHanler: CTSelfTracingInfoGetCompletion?
    
    /// This property holds the the dispatch queue used to invoke handlers on. If this property isn’t set, the framework uses the main queue.
    var dispatchQueue: DispatchQueue?
    
    /// Asynchronously performs the request to get the state, and invokes the completion handler when it's done.
    func perform() {
        
    }
    
    /// Invalidates a previously initiated request. If there is an outstanding completion handler, the framework will invoke it with an error.
    /// Don’t reuse the request after this is called. If you require another request, create a new one.
    func invalidate() {
        
    }
}

/// Contains the Daily Tracing Keys.
class CTSelfTracingInfo {
    /// Daily tracing keys available at the time of the request.
    var dailyTracingKeys: [CTDailyTracingKey]?
}


/// Contains information about a single contact incident.
class CTContactInfo {
    /// How long the contact was in proximity. Minimum duration is 5 minutes and increments by 5 minutes: 5, 10, 15, etc.
    var duration: TimeInterval?
    /// This property contains the time when the contact occurred. This may have reduced precision, such as within one day of the actual time.
    var timestamp: CFAbsoluteTime?
}

/// The Daily Tracing Key object
class CTDailyTracingKey {
    /// This property contains the Daily Tracing Key information.
    var keyData: Data?
}
