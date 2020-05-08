//
//  ExposureDataTypes.swift
//  TracePrivately
//

import Foundation
#if canImport(ExposureNotification)
import ExposureNotification
#endif

// These types map to the ExposureNotification framework so it can easily be factored out

#if canImport(ExposureNotification)
typealias TPIntervalNumber = ENIntervalNumber
typealias TPAttenuation = ENAttenuation
typealias TPRiskScore = ENRiskScore
typealias TPExposureConfiguration = ENExposureConfiguration
typealias TPRiskLevel = ENRiskLevel
#else
typealias TPIntervalNumber = UInt32
typealias TPAttenuation = UInt8
typealias TPRiskScore = UInt8

class TPExposureConfiguration {
    var minimumRiskScore: TPRiskScore = .zero
    var attenuationLevelValues: [NSNumber] = []
    var attenuationWeight: Double = 100
    var daysSinceLastExposureLevelValues: [NSNumber] = []
    var daysSinceLastExposureWeight: Double = 100
    var durationLevelValues: [NSNumber] = []
    var durationWeight: Double = 100
    var transmissionRiskLevelValues: [NSNumber] = []
    var transmissionRiskWeight: Double = 100
}

typealias TPRiskLevel = UInt8
#endif

struct TPTemporaryExposureKey {
    let keyData: Data
    let rollingPeriod: TPIntervalNumber
    let rollingStartNumber: TPIntervalNumber
    let transmissionRiskLevel: TPRiskLevel
}


#if !os(macOS)
extension TPTemporaryExposureKey {
    var enExposureKey: ENTemporaryExposureKey {
        let key = ENTemporaryExposureKey()
        key.keyData = keyData
        key.rollingStartNumber = rollingStartNumber
        key.rollingPeriod = rollingPeriod
        key.transmissionRiskLevel = transmissionRiskLevel
        
        return key
    }
}

extension ENTemporaryExposureKey {
    var tpExposureKey: TPTemporaryExposureKey {
        return .init(
            keyData: keyData,
            rollingPeriod: rollingPeriod,
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

enum TPSimplifiedExposureRisk {
    case high
    case medium
    case low
}

extension TPExposureInfo {
    var simplifiedRisk: TPSimplifiedExposureRisk {
        switch self.totalRiskScore {
        case 7...:
            return .high
        case 5...6:
            return .medium
        case ..<5:
            return .low
        default:
            return .low
        }
    }
}
#endif

extension UInt32 {
    static func intervalNumberFrom(date: Date) -> Self {
        let intervalNumber = UInt32(date.timeIntervalSince1970 / 600)
        return intervalNumber / 144 * 144
    }
}
