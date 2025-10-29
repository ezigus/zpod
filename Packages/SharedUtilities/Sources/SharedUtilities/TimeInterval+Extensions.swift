//
//  TimeInterval+Extensions.swift
//  SharedUtilities
//
//  Created for concurrency-safe duration formatting
//

import Foundation

extension TimeInterval {
    /// Returns an abbreviated description of the time interval
    /// - Parameter includeSeconds: Whether to include seconds in the output
    /// - Returns: A formatted string like "1h 23m 45s" or "1h 23m"
    public func abbreviatedDescription(includeSeconds: Bool = false) -> String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        
        var components: [String] = []
        
        if hours > 0 {
            components.append("\(hours)h")
        }
        
        if minutes > 0 || hours > 0 {
            components.append("\(minutes)m")
        }
        
        if includeSeconds {
            if hours > 0 || minutes > 0 {
                components.append("\(seconds)s")
            } else if seconds > 0 {
                components.append("\(seconds)s")
            } else {
                return "0s"
            }
        } else if components.isEmpty {
            // If no hours or minutes and not including seconds, show "0m"
            return "0m"
        }
        
        return components.joined(separator: " ")
    }
}
