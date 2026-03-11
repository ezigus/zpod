import Foundation

// MARK: - SmartListRuleValidator

/// Synchronous, pure validation for smart list rules.
///
/// Centralises rule constraints so both the UI layer (form submission)
/// and the persistence layer (pre-flight checks) share identical logic.
/// No external dependencies — safe to call from any actor.
public struct SmartListRuleValidator: Sendable {

    // MARK: - Error Types

    public enum ValidationError: LocalizedError, Equatable, Sendable {
        /// The comparison operator is not supported for this rule type.
        case unsupportedComparison(ruleType: SmartListRuleType, comparison: SmartListComparison)
        /// A string value is required but is empty or whitespace-only.
        case emptyStringValue(ruleType: SmartListRuleType)
        /// A numeric value is outside the valid range for this rule type.
        case numericOutOfRange(ruleType: SmartListRuleType, min: Double, max: Double)
        /// The value type does not match what this rule type/comparison pair expects.
        case valueTypeMismatch(ruleType: SmartListRuleType)
        /// A date range has a start date that is not before its end date.
        case invalidDateRange(ruleType: SmartListRuleType)

        public var errorDescription: String? {
            switch self {
            case .unsupportedComparison(let type, let comparison):
                return "'\(comparison.displayName)' is not a valid comparison for '\(type.displayName)' rules."
            case .emptyStringValue(let type):
                return "'\(type.displayName)' rules require a non-empty value."
            case .numericOutOfRange(let type, let min, let max):
                return "'\(type.displayName)' value must be between \(min) and \(max)."
            case .valueTypeMismatch(let type):
                return "The value type is incompatible with the '\(type.displayName)' rule."
            case .invalidDateRange(let type):
                return "'\(type.displayName)' date range must have a start date before the end date."
            }
        }
    }

    /// Aggregates multiple `ValidationError` values into a single `Error`.
    public struct ValidationErrors: LocalizedError, Sendable {
        public let errors: [ValidationError]

        public var errorDescription: String? {
            errors.compactMap(\.errorDescription).joined(separator: "\n")
        }
    }

    // MARK: - Public API

    public init() {}

    /// Validate a single rule. Returns `.success(())` if valid, or `.failure` with
    /// the first detected error.
    public static func validate(_ rule: SmartListRule) -> Result<Void, ValidationError> {
        if let error = checkComparison(rule) { return .failure(error) }
        if let error = checkValue(rule) { return .failure(error) }
        return .success(())
    }

    /// Validate a collection of rules. Returns `.success(())` if every rule is valid,
    /// or `.failure` containing all detected errors.
    public static func validateAll(_ rules: [SmartListRule]) -> Result<Void, ValidationErrors> {
        let errors = rules.compactMap { rule -> ValidationError? in
            if case .failure(let err) = validate(rule) { return err }
            return nil
        }
        return errors.isEmpty ? .success(()) : .failure(ValidationErrors(errors: errors))
    }

    /// Returns the comparisons that are valid for the given rule type.
    /// Delegates to `SmartListRuleType.availableComparisons` — single source of truth.
    public static func suggestedComparisons(for ruleType: SmartListRuleType) -> [SmartListComparison] {
        ruleType.availableComparisons
    }

    // MARK: - Private Helpers

    private static func checkComparison(_ rule: SmartListRule) -> ValidationError? {
        guard rule.type.availableComparisons.contains(rule.comparison) else {
            return .unsupportedComparison(ruleType: rule.type, comparison: rule.comparison)
        }
        return nil
    }

    private static func checkValue(_ rule: SmartListRule) -> ValidationError? {
        switch rule.type {
        case .podcast, .title, .description:
            guard case .string(let str) = rule.value else {
                return .valueTypeMismatch(ruleType: rule.type)
            }
            // Extend the trim set beyond .whitespacesAndNewlines to catch invisible
            // Unicode characters that are functionally empty but pass standard trimming:
            // U+200B zero-width space, U+200C ZWNJ, U+200D ZWJ, U+00AD soft hyphen,
            // U+FEFF BOM/zero-width no-break space, plus general control characters.
            var invisibleChars = CharacterSet.whitespacesAndNewlines
            invisibleChars.formUnion(.controlCharacters)
            invisibleChars.insert(charactersIn: "\u{200B}\u{200C}\u{200D}\u{00AD}\u{FEFF}")
            if str.trimmingCharacters(in: invisibleChars).isEmpty {
                return .emptyStringValue(ruleType: rule.type)
            }

        case .rating:
            let numericValue: Double
            switch rule.value {
            case .integer(let val): numericValue = Double(val)
            case .double(let val): numericValue = val
            default: return .valueTypeMismatch(ruleType: rule.type)
            }
            if !numericValue.isFinite || numericValue < 1 || numericValue > 5 {
                return .numericOutOfRange(ruleType: rule.type, min: 1, max: 5)
            }

        case .playbackPosition:
            guard case .double(let val) = rule.value else {
                return .valueTypeMismatch(ruleType: rule.type)
            }
            if !val.isFinite || val < 0 || val > 1 {
                return .numericOutOfRange(ruleType: rule.type, min: 0, max: 1)
            }

        case .duration:
            guard case .timeInterval(let val) = rule.value else {
                return .valueTypeMismatch(ruleType: rule.type)
            }
            if !val.isFinite || val < 0 {
                return .numericOutOfRange(ruleType: rule.type, min: 0, max: Double.greatestFiniteMagnitude)
            }

        case .playStatus:
            guard case .episodeStatus = rule.value else {
                return .valueTypeMismatch(ruleType: rule.type)
            }

        case .downloadStatus:
            guard case .downloadStatus = rule.value else {
                return .valueTypeMismatch(ruleType: rule.type)
            }

        case .isFavorited, .isBookmarked, .isArchived:
            guard case .boolean = rule.value else {
                return .valueTypeMismatch(ruleType: rule.type)
            }

        case .dateAdded, .pubDate:
            switch rule.value {
            case .relativeDate, .date: break
            case .dateRange(let start, let end):
                if start >= end {
                    return .invalidDateRange(ruleType: rule.type)
                }
            default: return .valueTypeMismatch(ruleType: rule.type)
            }
        }
        return nil
    }
}
