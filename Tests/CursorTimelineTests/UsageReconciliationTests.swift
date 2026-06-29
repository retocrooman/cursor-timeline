import CursorTimelineCore
import XCTest

final class UsageCSVReaderTests: XCTestCase {
    func testParseSampleRow() throws {
        let csv = """
        Date,User,Cloud Agent ID,Automation ID,Kind,Model,Max Mode,Input (w/ Cache Write),Input (w/o Cache Write),Cache Read,Output Tokens,Total Tokens,Cost
        "2026-06-28T15:18:16.925Z","user@example.com","","","Included","auto","No","0","4394","393120","2211","399725","0.12"
        """

        let records = try UsageCSVReader.parse(text: csv)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].user, "user@example.com")
        XCTAssertEqual(records[0].model, "auto")
        XCTAssertEqual(records[0].costUSD, Decimal(string: "0.12"))
        XCTAssertEqual(records[0].totalTokens, 399725)
    }
}

final class UsageReconcilerTests: XCTestCase {
    func testAssignsUsageAfterPromptWithinWindow() throws {
        let base = try XCTUnwrap(isoDate("2026-06-28T06:00:00Z"))
        let prompt = PromptEvent(
            id: "p1",
            sessionId: "s1",
            timestamp: base,
            text: "hello",
            model: .gpt,
            confidence: .high
        )
        let usage = [
            UsageRecord(
                id: "u1",
                timestamp: base.addingTimeInterval(45),
                user: "u",
                model: "auto",
                kind: "On-Demand",
                costUSD: Decimal(string: "0.10")!,
                totalTokens: 1000
            ),
            UsageRecord(
                id: "u2",
                timestamp: base.addingTimeInterval(90),
                user: "u",
                model: "auto",
                kind: "On-Demand",
                costUSD: Decimal(string: "0.05")!,
                totalTokens: 500
            ),
        ]

        let report = UsageReconciler.reconcile(prompts: [prompt], usage: usage)
        XCTAssertEqual(report.matchedPromptCount, 1)
        XCTAssertEqual(report.estimates.first?.costUSD, Decimal(string: "0.15"))
        XCTAssertEqual(report.estimates.first?.assignedEventCount, 2)
        XCTAssertEqual(report.orphanEventCount, 0)
    }

    func testUnmatchedPromptGetsRangeWhenNearbyUsageExists() throws {
        let base = try XCTUnwrap(isoDate("2026-06-28T06:00:00Z"))
        let prompt = PromptEvent(
            id: "p1",
            sessionId: "s1",
            timestamp: base,
            text: "hello",
            model: .gpt,
            confidence: .high
        )
        let usage = [
            UsageRecord(
                id: "u1",
                timestamp: base.addingTimeInterval(400),
                user: "u",
                model: "auto",
                kind: "On-Demand",
                costUSD: Decimal(string: "0.20")!,
                totalTokens: 1000
            ),
        ]

        var config = ReconciliationConfig()
        config.postWindow = 60
        config.rangeSlack = 600

        let report = UsageReconciler.reconcile(prompts: [prompt], usage: usage, config: config)
        XCTAssertEqual(report.estimates.first?.confidence, .range)
        XCTAssertNil(report.estimates.first?.costUSD)
        XCTAssertEqual(report.estimates.first?.rangeMinUSD, Decimal(string: "0.20"))
    }

    private func isoDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

final class PromptCostFormatTests: XCTestCase {
    func testExactLabel() {
        let estimate = PromptCostEstimate(
            promptID: "p1",
            timestamp: Date(),
            textPreview: "hi",
            costUSD: Decimal(string: "0.18"),
            rangeMinUSD: nil,
            rangeMaxUSD: nil,
            assignedEventCount: 2,
            confidence: .exact
        )
        XCTAssertEqual(PromptCostFormat.label(for: estimate), "$0.18 (2 req)")
    }

    func testRangeLabel() {
        let estimate = PromptCostEstimate(
            promptID: "p1",
            timestamp: Date(),
            textPreview: "hi",
            costUSD: nil,
            rangeMinUSD: Decimal(string: "0.02"),
            rangeMaxUSD: Decimal(string: "0.05"),
            assignedEventCount: 3,
            confidence: .range
        )
        XCTAssertEqual(PromptCostFormat.label(for: estimate), "$0.02–$0.05?")
    }
}

final class UsageReconciliationPoCTests: XCTestCase {
    func testSessionMatchRateReport() throws {
        let csvPath = ProcessInfo.processInfo.environment["USAGE_CSV_PATH"]
            ?? "/Users/shiho/Downloads/team-usage-events-11563757-2026-06-28.csv"

        guard FileManager.default.fileExists(atPath: csvPath) else {
            throw XCTSkip("Usage CSV not found at \(csvPath)")
        }

        let paths = CursorPaths()
        guard FileManager.default.fileExists(atPath: paths.globalDatabase.path) else {
            throw XCTSkip("Cursor global database not found")
        }

        let output = try ReconciliationPoCRunner.run(csvURL: URL(fileURLWithPath: csvPath), paths: paths)
        print("\n\(output.report)\n")

        XCTAssertTrue(output.report.contains("Sessions matched (exact):"))
    }

    func testFocusedWindowSweep() throws {
        let csvPath = ProcessInfo.processInfo.environment["USAGE_CSV_PATH"]
            ?? "/Users/shiho/Downloads/team-usage-events-11563757-2026-06-28.csv"

        guard FileManager.default.fileExists(atPath: csvPath) else {
            throw XCTSkip("Usage CSV not found at \(csvPath)")
        }

        let paths = CursorPaths()
        guard FileManager.default.fileExists(atPath: paths.globalDatabase.path) else {
            throw XCTSkip("Cursor global database not found")
        }

        let dataset = try ReconciliationPoCRunner.loadDataset(
            csvURL: URL(fileURLWithPath: csvPath),
            paths: paths
        )

        let configs: [ReconciliationConfig] = [
            ReconciliationConfig(preWindow: 30, postWindow: 180, rangeSlack: 300),
            ReconciliationConfig(preWindow: 30, postWindow: 300, rangeSlack: 300),
            ReconciliationConfig(preWindow: 30, postWindow: 420, rangeSlack: 300),
            ReconciliationConfig(preWindow: 30, postWindow: 600, rangeSlack: 300),
            ReconciliationConfig(preWindow: 0, postWindow: 300, rangeSlack: 300),
            ReconciliationConfig(preWindow: 60, postWindow: 300, rangeSlack: 300),
            ReconciliationConfig(preWindow: 30, postWindow: 300, rangeSlack: 180),
            ReconciliationConfig(preWindow: 30, postWindow: 420, rangeSlack: 180),
        ]

        let rows = ReconciliationPoCRunner.sweep(dataset: dataset, configs: configs)
        print("\n=== Focused window sweep ===")
        print(ReconciliationPoCRunner.formatSweep(rows))

        for row in rows {
            let stats = UsageReconciler.sessionStats(
                prompts: dataset.prompts,
                sessions: dataset.sessions,
                report: row.report
            )
            print(
                String(
                    format: "  pre=%.0f post=%.0f slack=%.0f → session exact %.1f%% prompt exact %.1f%% orphan %d",
                    row.config.preWindow,
                    row.config.postWindow,
                    row.config.rangeSlack,
                    stats.exactSessionRate * 100,
                    row.report.matchRate * 100,
                    row.report.orphanEventCount
                )
            )
        }

        XCTAssertFalse(rows.isEmpty)
    }

    func testPoCAgainstLocalCSVAndDatabase() throws {
        let csvPath = ProcessInfo.processInfo.environment["USAGE_CSV_PATH"]
            ?? "/Users/shiho/Downloads/team-usage-events-11563757-2026-06-28.csv"

        guard FileManager.default.fileExists(atPath: csvPath) else {
            throw XCTSkip("Usage CSV not found at \(csvPath)")
        }

        let paths = CursorPaths()
        guard FileManager.default.fileExists(atPath: paths.globalDatabase.path) else {
            throw XCTSkip("Cursor global database not found")
        }

        let output = try ReconciliationPoCRunner.run(csvURL: URL(fileURLWithPath: csvPath), paths: paths)
        print("\n\(output.report)\n")

        XCTAssertFalse(output.report.isEmpty)
        XCTAssertTrue(output.report.contains("Sessions matched (exact):"))
    }
}
