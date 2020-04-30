//
//  ExposureDataTypes.swift
//  TracePrivately
//

import Foundation
#if canImport(ExposureNotification)
import ExposureNotification
#endif

// These types map to the ExposureNotification framework so it can easily be factored out

typealias TPIntervalNumber = ENIntervalNumber
typealias TPAttenuation = ENAttenuation
typealias TPRiskScore = ENRiskScore
typealias TPRiskLevel = ENRiskLevel
typealias TPExposureConfiguration = ENExposureConfiguration

struct TPTemporaryExposureKey {
    let keyData: Data
    let rollingStartNumber: TPIntervalNumber
    let transmissionRiskLevel: TPRiskLevel!
}

extension TPTemporaryExposureKey {
    var enExposureKey: ENTemporaryExposureKey {
        let key = ENTemporaryExposureKey()
        key.keyData = keyData
        key.rollingStartNumber = rollingStartNumber
        key.transmissionRiskLevel = transmissionRiskLevel
        
        return key
    }
}

extension ENTemporaryExposureKey {
    var tpExposureKey: TPTemporaryExposureKey {
        return .init(
            keyData: keyData,
            rollingStartNumber: rollingStartNumber,
            transmissionRiskLevel: transmissionRiskLevel
        )
    }
}
 
struct TPExposureInfo {
    let attenuationValue: TPAttenuation
    let date: Date
    let duration: TimeInterval
    let totalRiskScore: TPRiskScore
    let transmissionRiskLevel: TPRiskLevel
}

extension ENExposureInfo {
    var tpExposureInfo: TPExposureInfo {
        return .init(attenuationValue: attenuationValue, date: date, duration: duration, totalRiskScore: totalRiskScore, transmissionRiskLevel: transmissionRiskLevel)
    }
}
