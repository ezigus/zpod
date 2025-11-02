//
//  IntentHandler.swift
//  zpodIntents
//
//  Created for Issue 02.1.8: CarPlay Siri Integration
//

import Intents

@available(iOS 14.0, *)
class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        // Route to appropriate intent handler based on intent type
        if intent is INPlayMediaIntent {
            return PlayMediaIntentHandler()
        }
        
        // Fallback for unknown intents
        return self
    }
}
