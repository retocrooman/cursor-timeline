import Foundation

public enum ReconciliationPoCRunner {
    public struct Dataset: Sendable {
        public let csvURL: URL
        public let usage: [UsageRecord]
        public let prompts: [PromptEvent]
        public let sessions: [TimelineSession]
    }

    public struct Output: Sendable {
        public let report: String
    }

    public struct SweepRow: Sendable {
        public let config: ReconciliationConfig
        public let report: ReconciliationReport
    }

    public static func loadDataset(csvURL: URL, paths: CursorPaths = CursorPaths()) throws -> Dataset {
        let usage = try UsageCSVReader.load(from: csvURL)
        guard let first = usage.first, let last = usage.last else {
            return Dataset(csvURL: csvURL, usage: [], prompts: [], sessions: [])
        }

        let loader = TimelineDataLoader(paths: paths)
        let index = try loader.fetchSessionIndex()

        let rangeStart = first.timestamp.addingTimeInterval(-3600)
        let rangeEnd = last.timestamp.addingTimeInterval(3600)
        let metasInRange = index.filter { meta in
            meta.startAt < rangeEnd && meta.endAt > rangeStart
        }
        let ids = metasInRange.map(\.id)

        let sessions = try loader.loadSessions(composerIdsForBubbles: ids)
        let prompts = sessions
            .flatMap(\.prompts)
            .filter { $0.timestamp >= rangeStart && $0.timestamp <= rangeEnd }
            .sorted { $0.timestamp < $1.timestamp }

        return Dataset(
            csvURL: csvURL,
            usage: usage,
            prompts: prompts,
            sessions: sessions
        )
    }

    public static func reconcile(
        dataset: Dataset,
        config: ReconciliationConfig = ReconciliationConfig()
    ) -> ReconciliationReport {
        UsageReconciler.reconcile(
            prompts: dataset.prompts,
            usage: dataset.usage,
            config: config
        )
    }

    public static func sweep(dataset: Dataset, configs: [ReconciliationConfig]) -> [SweepRow] {
        configs.map { config in
            SweepRow(config: config, report: reconcile(dataset: dataset, config: config))
        }
    }

    public static func formatSweep(_ rows: [SweepRow]) -> String {
        var lines = ["pre(s)\tpost(s)\trange(s)\texact%\torphan\tcost%"]
        for row in rows {
            let r = row.report
            let costRate = r.totalUsageCostUSD > 0
                ? (r.assignedUsageCostUSD as NSDecimalNumber).doubleValue
                    / (r.totalUsageCostUSD as NSDecimalNumber).doubleValue * 100
                : 0
            lines.append(
                String(
                    format: "%.0f\t%.0f\t%.0f\t%.1f\t%d\t%.1f",
                    row.config.preWindow,
                    row.config.postWindow,
                    row.config.rangeSlack,
                    r.matchRate * 100,
                    r.orphanEventCount,
                    costRate
                )
            )
        }
        return lines.joined(separator: "\n")
    }

    public static func run(
        csvURL: URL,
        paths: CursorPaths = CursorPaths(),
        config: ReconciliationConfig = ReconciliationConfig()
    ) throws -> Output {
        let dataset = try loadDataset(csvURL: csvURL, paths: paths)
        let report = reconcile(dataset: dataset, config: config)
        let sessionStats = UsageReconciler.sessionStats(
            prompts: dataset.prompts,
            sessions: dataset.sessions,
            report: report
        )

        guard let first = dataset.usage.first, let last = dataset.usage.last else {
            return Output(report: "CSV is empty")
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var lines: [String] = []
        lines.append("=== Usage Reconciliation PoC ===")
        lines.append("CSV: \(csvURL.path)")
        lines.append(
            "Window: pre=\(Int(config.preWindow))s post=\(Int(config.postWindow))s rangeSlack=\(Int(config.rangeSlack))s"
        )
        lines.append("Usage rows: \(dataset.usage.count)  total: $\(formatUSD(report.totalUsageCostUSD))")
        lines.append("Range: \(formatter.string(from: first.timestamp)) .. \(formatter.string(from: last.timestamp))")
        lines.append("Sessions in range (index): \(sessionStats.sessionsInRange)")
        lines.append("Sessions with user prompts: \(sessionStats.sessionsWithPrompts)")
        lines.append(
            String(
                format: "Sessions matched (exact): %d / %d (%.1f%%)",
                sessionStats.sessionsExactMatch,
                sessionStats.sessionsWithPrompts,
                sessionStats.exactSessionRate * 100
            )
        )
        lines.append(
            String(
                format: "Sessions matched (exact+range): %d / %d (%.1f%%)",
                sessionStats.sessionsAnyMatch,
                sessionStats.sessionsWithPrompts,
                sessionStats.anySessionRate * 100
            )
        )
        lines.append("Prompts in range: \(dataset.prompts.count)")
        lines.append(
            String(
                format: "Prompts matched (exact): %d / %d (%.1f%%)",
                report.matchedPromptCount,
                report.totalPromptCount,
                report.matchRate * 100
            )
        )
        lines.append(
            String(
                format: "Prompts matched (exact+range): %d / %d (%.1f%%)",
                report.matchedPromptCount + report.rangePromptCount,
                report.totalPromptCount,
                report.anyMatchRate * 100
            )
        )
        lines.append("Orphan usage events: \(report.orphanEventCount)")
        lines.append(
            "Assigned cost: $\(formatUSD(report.assignedUsageCostUSD)) / $\(formatUSD(report.totalUsageCostUSD))"
        )
        lines.append("")
        lines.append("--- Sample exact matches (up to 8) ---")
        for estimate in report.estimates.filter({ $0.confidence == .exact }).prefix(8) {
            lines.append(
                "  \(formatter.string(from: estimate.timestamp))  $\(formatUSD(estimate.costUSD ?? 0))  (\(estimate.assignedEventCount) ev)  \(estimate.textPreview)"
            )
        }
        lines.append("")
        lines.append("--- Sample range / unmatched (up to 5) ---")
        for estimate in report.estimates.filter({ $0.confidence != .exact }).prefix(5) {
            let costLabel: String
            switch estimate.confidence {
            case .range:
                costLabel = "$\(formatUSD(estimate.rangeMinUSD ?? 0))–$\(formatUSD(estimate.rangeMaxUSD ?? 0))?"
            case .unmatched:
                costLabel = "—"
            case .exact:
                costLabel = ""
            }
            lines.append(
                "  [\(estimate.confidence.rawValue)] \(formatter.string(from: estimate.timestamp))  \(costLabel)  \(estimate.textPreview)"
            )
        }

        return Output(report: lines.joined(separator: "\n"))
    }

    private static func formatUSD(_ value: Decimal) -> String {
        let number = value as NSDecimalNumber
        return String(format: "%.2f", number.doubleValue)
    }
}
