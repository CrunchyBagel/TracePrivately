//
//  ENMockFramework.swift
//  TracePrivately
//

import Foundation

enum ENErrorCode {
    case success
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
    case internalError
    case insufficientMemory
    
    var localizedTitle: String {
        return ""
    }
}

struct ENError: LocalizedError {
    let errorCode: ENErrorCode
    
    var localizedDescription: String {
        return errorCode.localizedTitle
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
    
    func activateWithCompletion(_ inCompletion: ENErrorHandler)
    func invalidate()
}

protocol ENAuthorizable {
    var authorizationStatus: ENAuthorizationStatus { get }
    var authorizationMode: ENAuthorizationMode { get set }
}

typealias ENMultiState = Bool

struct ENSettings {
    let enableState: ENMultiState
}

struct ENMutableSettings {
    // TODO: Use this accordingly
}

struct ENSettingsGetRequest: ENBaseRequest {
    let settings: ENSettings
}

class ENSettingsChangeRequest: ENAuthorizableBaseRequest {
    let settings: ENSettings
    
    init(settings: ENSettings) {
        self.settings = settings
    }
}

typealias ENIntervalNumber = Int

struct ENTemporaryExposureKey {
    let keyData: Data
    let rollingStartNumber: ENIntervalNumber
}

struct ENExposureDetectionSummary {
    let daysSinceLastExposure: Int
    let matchedKeyCount: UInt64
}

typealias ENExposureDetectionFinishCompletion = ((ENExposureDetectionSummary?, Swift.Error?) -> Void)

typealias ENExposureDetectionGetExposureInfoCompletion = (([ENExposureInfo]?, Bool, Swift.Error?) -> Void)

class ENExposureDetectionSession: ENBaseRequest {
    var attenuationThreshold: UInt8 = 0
    var durationThreshold: TimeInterval = 0
    var maxKeyCount: Int = 0
    
    func addDiagnosisKeys(inKeys: [ENTemporaryExposureKey], completion: ENErrorHandler) {
        
    }
    
    func finishedDiagnosisKeysWithCompletion(completion: ENExposureDetectionFinishCompletion) {
        
    }
    
    func getExposureInfoWithMaxCount(maxCount: UInt32, completion: ENExposureDetectionGetExposureInfoCompletion) {
        
    }
}

struct ENExposureInfo {
    let attenuationValue: UInt8
    let date: Date
    let duration: TimeInterval
}

struct ENSelfExposureInfo {
    let keys: [ENTemporaryExposureKey]
}

class ENSelfExposureInfoRequest: ENAuthorizableBaseRequest {
    var selfExposureInfo: ENSelfExposureInfo?
}

class ENSelfExposureResetRequest: ENAuthorizableBaseRequest {
    
}

class ENAuthorizableBaseRequest: ENBaseRequest, ENAuthorizable {
    var authorizationStatus: ENAuthorizationStatus = .unknown
    var authorizationMode: ENAuthorizationMode = .defaultMode
}

class ENBaseRequest: ENActivatable {
    var dispatchQueue: DispatchQueue?
    
    var invalidationHandler: (() -> Void)?
    
    func activateWithCompletion(_ inCompletion: (Error?) -> Void) {
        
    }
    
    func invalidate() {
        
    }
    
    
}
