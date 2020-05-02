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
    var attenuationScores: [NSNumber] = []
    var attenuationWeight: Double = 100
    var daysSinceLastExposureScores: [NSNumber] = []
    var daysSinceLastExposureWeight: Double = 100
    var durationScores: [NSNumber] = []
    var durationWeight: Double = 100
    var transmissionRiskScores: [NSNumber] = []
    var transmissionRiskWeight: Double = 100
}

enum TPRiskLevel: UInt8 {
    case invalid = 0
    case lowest = 1
    case low = 10
    case lowMedium = 25
    case medium = 50
    case mediumHigh = 65
    case high = 80
    case veryHigh = 90
    case highest = 100
}
#endif

struct TPTemporaryExposureKey {
    let keyData: Data
    let rollingStartNumber: TPIntervalNumber
    let transmissionRiskLevel: TPRiskLevel!
}

#if !os(macOS)
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

enum TPSimplifiedExposureRisk {
    case high
    case medium
    case low
}

extension TPExposureInfo {
    // TODO: The docs are a bit weird here. It indicates the total should be 1 - 8, but also says the value could 0..100 and it also says could be less than 0, so I've wrapped the value here so it can easily be updated
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
