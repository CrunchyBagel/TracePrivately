//
//  IntentHandler.swift
//  TracePrivately-Siri
//

import Intents

class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        return self
    }
}

extension IntentHandler {
    var isTracingEnabled: Bool {
        return false // TODO: Implement
    }
}

extension IntentHandler: StartTracingIntentHandling {
    func handle(intent: StartTracingIntent, completion: @escaping (StartTracingIntentResponse) -> Void) {
        
//        if self.isTracingEnabled {
//            completion(.init(code: .success, userActivity: nil))
//        }
//        else {
            completion(.init(code: .continueInApp, userActivity: nil))
//        }
    }
}

extension IntentHandler: StopTracingIntentHandling {
    func handle(intent: StopTracingIntent, completion: @escaping (StopTracingIntentResponse) -> Void) {
        
//        if self.isTracingEnabled {
            completion(.init(code: .continueInApp, userActivity: nil))
//        }
//        else {
//            completion(.init(code: .success, userActivity: nil))
//        }
    }
}

extension IntentHandler: TracingStatusIntentHandling {
    var currentStatus: SiriTracingStatus {
        let status = SiriTracingStatus(identifier: nil, display: "Tracing Status") // TODO: Implement display string

        status.isTracingEnabled = self.isTracingEnabled as NSNumber
        status.diseaseStatus = .unknown // TODO: Implement

        return status
    }

    func handle(intent: TracingStatusIntent, completion: @escaping (TracingStatusIntentResponse) -> Void) {
        
        let response = TracingStatusIntentResponse(code: .success, userActivity: nil)
        response.status = self.currentStatus
        
        completion(response)
    }
}
