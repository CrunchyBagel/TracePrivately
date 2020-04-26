//
//  ExposureNotificationConfig.swift
//  TracePrivately
//

import UIKit

struct ExposureNotificationConfig {
    struct DetectionSession {
        let attenuationThreshold: UInt8
        let durationThreshold: TimeInterval
        
        // No filtering
        static let defaultConfig = DetectionSession(attenuationThreshold: 0, durationThreshold: 0)
    }
    
    let session: DetectionSession
    
    static let defaultConfig = ExposureNotificationConfig(session: .defaultConfig)
}

extension ExposureNotificationConfig: CustomDebugStringConvertible {
    var debugDescription: String {
        return "session=\(session)"
    }
}

extension ExposureNotificationConfig.DetectionSession: CustomDebugStringConvertible {
    var debugDescription: String {
        return "attenuationThreshold=\(attenuationThreshold) durationThreshold=\(durationThreshold)"
    }
}

extension ExposureNotificationConfig {
    init?(plistUrl: URL) {
        guard let config = NSDictionary(contentsOf: plistUrl) else {
            return nil
        }
        
        var session: DetectionSession = .defaultConfig
        
        if let sessionConfig = config.object(forKey: "DetectionSession") as? [String : Any] {

            let attenuationThreshold: UInt8? = sessionConfig["attenuationThreshold"] as? UInt8
            
            let durationThreshold: TimeInterval? = sessionConfig["durationThreshold"] as? TimeInterval
            
            session = DetectionSession(
                attenuationThreshold: attenuationThreshold ?? session.attenuationThreshold,
                durationThreshold: durationThreshold ?? session.durationThreshold
            )
        }

        self.session = session
    }
}
