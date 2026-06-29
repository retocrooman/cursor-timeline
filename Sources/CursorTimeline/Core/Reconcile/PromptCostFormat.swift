import Foundation

public enum PromptCostFormat {
    public static func label(for estimate: PromptCostEstimate) -> String? {
        switch estimate.confidence {
        case .exact:
            guard let cost = estimate.costUSD else { return nil }
            let base = formatUSD(cost)
            if estimate.assignedEventCount > 1 {
                return "\(base) (\(estimate.assignedEventCount) req)"
            }
            return base
        case .range:
            guard let minCost = estimate.rangeMinUSD, let maxCost = estimate.rangeMaxUSD else { return nil }
            return "\(formatUSD(minCost))–\(formatUSD(maxCost))?"
        case .unmatched:
            return nil
        }
    }

    public static func formatUSD(_ value: Decimal) -> String {
        let number = value as NSDecimalNumber
        return String(format: "$%.2f", number.doubleValue)
    }
}
