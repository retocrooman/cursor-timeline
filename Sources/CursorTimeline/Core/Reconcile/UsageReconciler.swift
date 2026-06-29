import Foundation

public enum UsageReconciler {
    /// usage イベントを直前のプロンプトに割当（1 event = 1 prompt、PoC 用 greedy）
    public static func reconcile(
        prompts: [PromptEvent],
        usage: [UsageRecord],
        config: ReconciliationConfig = ReconciliationConfig()
    ) -> ReconciliationReport {
        let sortedPrompts = prompts.sorted { $0.timestamp < $1.timestamp }
        let sortedUsage = usage.sorted { $0.timestamp < $1.timestamp }

        var assignments: [String: [UsageRecord]] = [:]
        var orphanCount = 0

        for event in sortedUsage {
            guard let prompt = assignPrompt(for: event, prompts: sortedPrompts, config: config) else {
                orphanCount += 1
                continue
            }
            assignments[prompt.id, default: []].append(event)
        }

        let totalUsageCost = sortedUsage.reduce(Decimal.zero) { $0 + $1.costUSD }
        var assignedCost = Decimal.zero

        let estimates: [PromptCostEstimate] = sortedPrompts.map { prompt in
            let assigned = assignments[prompt.id] ?? []
            assignedCost += assigned.reduce(Decimal.zero) { $0 + $1.costUSD }

            if !assigned.isEmpty {
                let sum = assigned.reduce(Decimal.zero) { $0 + $1.costUSD }
                return PromptCostEstimate(
                    promptID: prompt.id,
                    timestamp: prompt.timestamp,
                    textPreview: preview(prompt.text),
                    costUSD: sum,
                    rangeMinUSD: nil,
                    rangeMaxUSD: nil,
                    assignedEventCount: assigned.count,
                    confidence: .exact
                )
            }

            let nearby = nearbyEvents(for: prompt, usage: sortedUsage, config: config)
            if nearby.isEmpty {
                return PromptCostEstimate(
                    promptID: prompt.id,
                    timestamp: prompt.timestamp,
                    textPreview: preview(prompt.text),
                    costUSD: nil,
                    rangeMinUSD: nil,
                    rangeMaxUSD: nil,
                    assignedEventCount: 0,
                    confidence: .unmatched
                )
            }

            let costs = nearby.map(\.costUSD).filter { $0 > 0 }
            let minCost = costs.min() ?? nearby.map(\.costUSD).min() ?? 0
            let maxCost = costs.max() ?? nearby.map(\.costUSD).max() ?? 0

            return PromptCostEstimate(
                promptID: prompt.id,
                timestamp: prompt.timestamp,
                textPreview: preview(prompt.text),
                costUSD: nil,
                rangeMinUSD: minCost,
                rangeMaxUSD: maxCost,
                assignedEventCount: nearby.count,
                confidence: .range
            )
        }

        return ReconciliationReport(
            estimates: estimates,
            orphanEventCount: orphanCount,
            totalUsageCostUSD: totalUsageCost,
            assignedUsageCostUSD: assignedCost
        )
    }

    private static func assignPrompt(
        for event: UsageRecord,
        prompts: [PromptEvent],
        config: ReconciliationConfig
    ) -> PromptEvent? {
        let candidates = prompts.filter { prompt in
            event.timestamp >= prompt.timestamp.addingTimeInterval(-config.preWindow)
                && event.timestamp <= prompt.timestamp.addingTimeInterval(config.postWindow)
        }

        if let prior = candidates.last(where: { $0.timestamp <= event.timestamp }) {
            return prior
        }
        return candidates.first
    }

    private static func nearbyEvents(
        for prompt: PromptEvent,
        usage: [UsageRecord],
        config: ReconciliationConfig
    ) -> [UsageRecord] {
        let start = prompt.timestamp.addingTimeInterval(-config.preWindow)
        let end = prompt.timestamp.addingTimeInterval(config.postWindow + config.rangeSlack)
        return usage.filter { $0.timestamp >= start && $0.timestamp <= end }
    }

    private static func preview(_ text: String) -> String {
        let trimmed = text.replacingOccurrences(of: "\n", with: " ")
        return String(trimmed.prefix(60))
    }
}
