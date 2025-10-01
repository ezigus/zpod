//
//  HapticFeedbackService.swift
//  SharedUtilities
//
//  Created for Issue 02.1.6: Swipe Gestures and Quick Actions
//

import Foundation
import CoreModels

#if canImport(UIKit)
import UIKit

/// Service for providing haptic feedback during swipe gestures and user interactions
@MainActor
public final class HapticFeedbackService: Sendable {
    
    /// Shared instance for haptic feedback
    public static let shared = HapticFeedbackService()
    
    private init() {}
    
    /// Provide haptic feedback for partial swipe preview
    /// - Parameter style: The haptic style to use
    public func previewFeedback(style: SwipeHapticStyle = .light) {
        let generator: UIImpactFeedbackGenerator
        
        switch style {
        case .light:
            generator = UIImpactFeedbackGenerator(style: .light)
        case .medium:
            generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy:
            generator = UIImpactFeedbackGenerator(style: .heavy)
        case .soft:
            generator = UIImpactFeedbackGenerator(style: .soft)
        case .rigid:
            generator = UIImpactFeedbackGenerator(style: .rigid)
        }
        
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Provide haptic feedback for full swipe execution
    /// - Parameter style: The haptic style to use
    public func executionFeedback(style: SwipeHapticStyle = .medium) {
        let generator: UIImpactFeedbackGenerator
        
        switch style {
        case .light:
            generator = UIImpactFeedbackGenerator(style: .light)
        case .medium:
            generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy:
            generator = UIImpactFeedbackGenerator(style: .heavy)
        case .soft:
            generator = UIImpactFeedbackGenerator(style: .soft)
        case .rigid:
            generator = UIImpactFeedbackGenerator(style: .rigid)
        }
        
        generator.prepare()
        generator.impactOccurred(intensity: 0.8)
    }
    
    /// Provide haptic feedback for successful action completion
    public func successFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// Provide haptic feedback for action warning
    public func warningFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    /// Provide haptic feedback for action error
    public func errorFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    /// Provide haptic feedback for selection change
    public func selectionFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

#else

/// Stub implementation for non-UIKit platforms
@MainActor
public final class HapticFeedbackService: Sendable {
    public static let shared = HapticFeedbackService()
    private init() {}
    
    public func previewFeedback(style: SwipeHapticStyle = .light) {}
    public func executionFeedback(style: SwipeHapticStyle = .medium) {}
    public func successFeedback() {}
    public func warningFeedback() {}
    public func errorFeedback() {}
    public func selectionFeedback() {}
}

#endif
