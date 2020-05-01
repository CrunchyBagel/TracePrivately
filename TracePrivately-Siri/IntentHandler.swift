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

extension IntentHandler: StartTracingIntentHandling {
    func handle(intent: StartTracingIntent, completion: @escaping (StartTracingIntentResponse) -> Void) {
        completion(.init(code: .continueInApp, userActivity: nil))
    }
}

extension IntentHandler: StopTracingIntentHandling {
    func handle(intent: StopTracingIntent, completion: @escaping (StopTracingIntentResponse) -> Void) {
        completion(.init(code: .continueInApp, userActivity: nil))
    }
}
