//
//  ExposureNotificationConfig.swift
//  TracePrivately
//

import UIKit

struct ExposureNotificationConfig {
    struct BucketConfig {
        let weight: Double
        
        let val1: ENRiskScore
        let val2: ENRiskScore
        let val3: ENRiskScore
        let val4: ENRiskScore
        let val5: ENRiskScore
        let val6: ENRiskScore
        let val7: ENRiskScore
        let val8: ENRiskScore
        
        var scores: [NSNumber] {
            let vals: [ENRiskScore] = [
                val1, val2, val3, val4, val5, val6, val7, val8
            ]
            
            return vals.map { $0 as NSNumber }
        }
    }
    
    let minimumRiskScore: ENRiskScore
    
    let attenuation: BucketConfig
    let daysSinceLastExposure: BucketConfig
    let duration: BucketConfig
    let transmissionRisk: BucketConfig
    
    var exposureConfig: TPExposureConfiguration {
        let config = TPExposureConfiguration()
        config.minimumRiskScore = self.minimumRiskScore
        
        config.attenuationWeight = attenuation.weight
        config.attenuationScores = attenuation.scores
        
        config.daysSinceLastExposureWeight = daysSinceLastExposure.weight
        config.daysSinceLastExposureScores = daysSinceLastExposure.scores
        
        config.durationWeight = duration.weight
        config.durationScores = duration.scores
        
        config.transmissionRiskWeight = transmissionRisk.weight
        config.transmissionRiskScores = transmissionRisk.scores

        return config
    }
}

extension ExposureNotificationConfig {
    init?(plistUrl: URL) {
        guard let config = NSDictionary(contentsOf: plistUrl) else {
            print("Unable to turn config into dictionary")
            return nil
        }
        
        guard let detectionSessionConfig = config.object(forKey: "DetectionSession") as? [String: Any] else {
            print("DetectionSession not found")
            return nil
        }
        
        guard let minimumRiskScoreConfig = detectionSessionConfig["minimumRiskScore"] as? [String: Any] else {
            print("minimumRiskScore config not found")
            return nil
        }
        
        guard let minimumRiskScore = minimumRiskScoreConfig["value"] as? NSNumber else {
            print("minimumRiskScore value not found")
            return nil
        }
        
        guard let attenuationConfig = detectionSessionConfig["attenuation"] as? [String: Any] else {
            print("attenuationConfig not found")
            return nil
        }
        
        guard let attenuation = BucketConfig(config: attenuationConfig) else {
            print("Unable to create attenuation config")
            return nil
        }
        
        guard let transmissionRiskConfig = detectionSessionConfig["transmissionRisk"] as? [String: Any] else {
            print("transmissionRisk not found")
            return nil
        }
        
        guard let transmissionRisk = BucketConfig(config: transmissionRiskConfig) else {
            print("Unable to create transmissionRisk config")
            return nil
        }
        
        guard let daysSinceLastExposureConfig = detectionSessionConfig["daysSinceLastExposure"] as? [String: Any] else {
            print("daysSinceLastExposure not found")
            return nil
        }
        
        guard let daysSinceLastExposure = BucketConfig(config: daysSinceLastExposureConfig) else {
            print("Unable to create daysSinceLastExposed config")
            return nil
        }
        
        guard let durationConfig = detectionSessionConfig["duration"] as? [String: Any] else {
            print("durationConfig not found")
            return nil
        }
        
        guard let duration = BucketConfig(config: durationConfig) else {
            print("Unable to create duration config")
            return nil
        }

        self.minimumRiskScore = minimumRiskScore.uint8Value
        self.attenuation = attenuation
        self.transmissionRisk = transmissionRisk
        self.daysSinceLastExposure = daysSinceLastExposure
        self.duration = duration
    }
}

extension ExposureNotificationConfig: CustomDebugStringConvertible {
    var debugDescription: String {
        return "minimumRiskScore=\(minimumRiskScore) attenuation=\(attenuation) daysSinceLastExposure=\(daysSinceLastExposure) duration=\(duration) transmissionRisk=\(transmissionRisk)"
    }
}

extension ExposureNotificationConfig.BucketConfig: CustomDebugStringConvertible {
    var debugDescription: String {
        return "weight=\(weight) scores=\(self.scores)"
    }
    
    init?(config: [String: Any]) {
        
        guard let weight = config["weight"] as? Double else {
            print("Weight must be specified")
            return nil
        }
        
        guard weight >= 0 && weight <= 100 else {
            print("Weight must be in the range 0...100")
            return nil
        }
        
        guard let scores = config["scores"] as? [NSNumber] else {
            print("Scores must be [NSNumber]")
            return nil
        }
        
        guard scores.count == 8 else {
            print("Scores must have 8 elements exactly")
            return nil
        }
        
        let values: [ENRiskScore] = scores.map { $0.uint8Value }
        
        self.weight = weight
        self.val1 = values[0]
        self.val2 = values[1]
        self.val3 = values[2]
        self.val4 = values[3]
        self.val5 = values[4]
        self.val6 = values[5]
        self.val7 = values[6]
        self.val8 = values[7]
    }
}
