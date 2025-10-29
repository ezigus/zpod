import Foundation
import SharedUtilities

// MARK: - Smart List Rule Evaluator

/// Helper for evaluating smart list rules.
/// Value type (struct) marked Sendable for safe cross-actor usage.
public struct SmartListRuleEvaluator: Sendable {
    
    public init() {}
    
    /// Evaluate all rules in a smart list rule set
    public func evaluateSmartListRules(episode: Episode, rules: SmartListRuleSet) -> Bool {
        guard !rules.rules.isEmpty else { return true }
        
        switch rules.logic {
        case .and:
            return rules.rules.allSatisfy { rule in
                let result = evaluateSmartListRule(episode: episode, rule: rule)
                return rule.isNegated ? !result : result
            }
        case .or:
            return rules.rules.contains { rule in
                let result = evaluateSmartListRule(episode: episode, rule: rule)
                return rule.isNegated ? !result : result
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Evaluate a single smart list rule
    private func evaluateSmartListRule(episode: Episode, rule: SmartListRule) -> Bool {
        switch rule.type {
        case .playStatus:
            return evaluatePlayStatusRule(episode: episode, comparison: rule.comparison, value: rule.value)
        case .downloadStatus:
            return evaluateDownloadStatusRule(episode: episode, comparison: rule.comparison, value: rule.value)
        case .dateAdded:
            return evaluateDateRule(date: episode.dateAdded, comparison: rule.comparison, value: rule.value)
        case .pubDate:
            guard let pubDate = episode.pubDate else { return false }
            return evaluateDateRule(date: pubDate, comparison: rule.comparison, value: rule.value)
        case .duration:
            guard let duration = episode.duration else { return false }
            return evaluateNumberRule(number: duration, comparison: rule.comparison, value: rule.value)
        case .rating:
            let rating = episode.rating.map(Double.init) ?? 0.0
            return evaluateNumberRule(number: rating, comparison: rule.comparison, value: rule.value)
        case .podcast:
            return evaluateStringRule(text: episode.podcastTitle, comparison: rule.comparison, value: rule.value)
        case .title:
            return evaluateStringRule(text: episode.title, comparison: rule.comparison, value: rule.value)
        case .description:
            return evaluateStringRule(text: episode.description ?? "", comparison: rule.comparison, value: rule.value)
        case .isFavorited:
            return evaluateBooleanRule(value: episode.isFavorited, comparison: rule.comparison, ruleValue: rule.value)
        case .isBookmarked:
            return evaluateBooleanRule(value: episode.isBookmarked, comparison: rule.comparison, ruleValue: rule.value)
        case .isArchived:
            return evaluateBooleanRule(value: episode.isArchived, comparison: rule.comparison, ruleValue: rule.value)
        case .playbackPosition:
            return evaluateNumberRule(number: Double(episode.playbackPosition), comparison: rule.comparison, value: rule.value)
        }
    }
    
    // MARK: - Rule Type Evaluators
    
    private func evaluatePlayStatusRule(episode: Episode, comparison: SmartListComparison, value: SmartListRuleValue) -> Bool {
        guard case .episodeStatus(let expectedStatus) = value else { return false }
        
        let actualStatus: EpisodePlayStatus
        if !episode.isPlayed && episode.playbackPosition == 0 {
            actualStatus = .unplayed
        } else if episode.isInProgress {
            actualStatus = .inProgress
        } else {
            actualStatus = .played
        }
        
        switch comparison {
        case .equals:
            return actualStatus == expectedStatus
        case .notEquals:
            return actualStatus != expectedStatus
        default:
            return false
        }
    }
    
    private func evaluateDownloadStatusRule(episode: Episode, comparison: SmartListComparison, value: SmartListRuleValue) -> Bool {
        guard case .downloadStatus(let expectedStatus) = value else { return false }
        
        switch comparison {
        case .equals:
            return episode.downloadStatus == expectedStatus
        case .notEquals:
            return episode.downloadStatus != expectedStatus
        default:
            return false
        }
    }
    
    private func evaluateDateRule(date: Date, comparison: SmartListComparison, value: SmartListRuleValue) -> Bool {
        switch value {
        case .date(let targetDate):
            return evaluateDateComparison(date: date, comparison: comparison, targetDate: targetDate)
        case .dateRange(let start, let end):
            switch comparison {
            case .between:
                return date >= start && date <= end
            default:
                return false
            }
        case .relativeDate(let period):
            let range = period.dateRange()
            switch comparison {
            case .within, .between:
                return date >= range.start && date <= range.end
            case .after:
                return date > range.start
            case .before:
                return date < range.end
            default:
                return false
            }
        default:
            return false
        }
    }
    
    private func evaluateDateComparison(date: Date, comparison: SmartListComparison, targetDate: Date) -> Bool {
        switch comparison {
        case .equals:
            return Calendar.current.isDate(date, inSameDayAs: targetDate)
        case .notEquals:
            return !Calendar.current.isDate(date, inSameDayAs: targetDate)
        case .before:
            return date < targetDate
        case .after:
            return date > targetDate
        default:
            return false
        }
    }
    
    private func evaluateNumberRule(number: Double, comparison: SmartListComparison, value: SmartListRuleValue) -> Bool {
        let targetValue: Double
        
        switch value {
        case .integer(let intValue):
            targetValue = Double(intValue)
        case .double(let doubleValue):
            targetValue = doubleValue
        case .timeInterval(let interval):
            targetValue = interval
        default:
            return false
        }
        
        switch comparison {
        case .equals:
            return abs(number - targetValue) < 0.01 // Allow small floating point differences
        case .notEquals:
            return abs(number - targetValue) >= 0.01
        case .lessThan:
            return number < targetValue
        case .greaterThan:
            return number > targetValue
        default:
            return false
        }
    }
    
    private func evaluateStringRule(text: String, comparison: SmartListComparison, value: SmartListRuleValue) -> Bool {
        guard case .string(let targetText) = value else { return false }
        
        let lowercaseText = text.lowercased()
        let lowercaseTarget = targetText.lowercased()
        
        switch comparison {
        case .equals:
            return lowercaseText == lowercaseTarget
        case .notEquals:
            return lowercaseText != lowercaseTarget
        case .contains:
            return lowercaseText.contains(lowercaseTarget)
        case .notContains:
            return !lowercaseText.contains(lowercaseTarget)
        case .startsWith:
            return lowercaseText.hasPrefix(lowercaseTarget)
        case .endsWith:
            return lowercaseText.hasSuffix(lowercaseTarget)
        default:
            return false
        }
    }
    
    private func evaluateBooleanRule(value: Bool, comparison: SmartListComparison, ruleValue: SmartListRuleValue) -> Bool {
        guard case .boolean(let expectedValue) = ruleValue else { return false }
        
        switch comparison {
        case .equals:
            return value == expectedValue
        case .notEquals:
            return value != expectedValue
        default:
            return false
        }
    }
}
