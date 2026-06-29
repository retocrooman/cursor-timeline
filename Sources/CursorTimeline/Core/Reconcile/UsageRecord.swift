import Foundation

public struct UsageRecord: Identifiable, Sendable, Equatable {
    public let id: String
    public let timestamp: Date
    public let user: String
    public let model: String
    public let kind: String
    public let costUSD: Decimal
    public let totalTokens: Int

    public init(
        id: String,
        timestamp: Date,
        user: String,
        model: String,
        kind: String,
        costUSD: Decimal,
        totalTokens: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.user = user
        self.model = model
        self.kind = kind
        self.costUSD = costUSD
        self.totalTokens = totalTokens
    }
}

public enum MatchConfidence: String, Sendable, Equatable {
    case exact
    case range
    case unmatched
}

public struct PromptCostEstimate: Sendable, Equatable {
    public let promptID: String
    public let timestamp: Date
    public let textPreview: String
    public let costUSD: Decimal?
    public let rangeMinUSD: Decimal?
    public let rangeMaxUSD: Decimal?
    public let assignedEventCount: Int
    public let confidence: MatchConfidence

    public init(
        promptID: String,
        timestamp: Date,
        textPreview: String,
        costUSD: Decimal?,
        rangeMinUSD: Decimal?,
        rangeMaxUSD: Decimal?,
        assignedEventCount: Int,
        confidence: MatchConfidence
    ) {
        self.promptID = promptID
        self.timestamp = timestamp
        self.textPreview = textPreview
        self.costUSD = costUSD
        self.rangeMinUSD = rangeMinUSD
        self.rangeMaxUSD = rangeMaxUSD
        self.assignedEventCount = assignedEventCount
        self.confidence = confidence
    }
}

public struct ReconciliationReport: Sendable, Equatable {
    public let estimates: [PromptCostEstimate]
    public let orphanEventCount: Int
    public let totalUsageCostUSD: Decimal
    public let assignedUsageCostUSD: Decimal

    public var matchedPromptCount: Int {
        estimates.filter { $0.confidence == .exact }.count
    }

    public var rangePromptCount: Int {
        estimates.filter { $0.confidence == .range }.count
    }

    public var unmatchedPromptCount: Int {
        estimates.filter { $0.confidence == .unmatched }.count
    }

    public var totalPromptCount: Int {
        estimates.count
    }

    public var matchRate: Double {
        guard totalPromptCount > 0 else { return 0 }
        return Double(matchedPromptCount) / Double(totalPromptCount)
    }

    public var anyMatchRate: Double {
        guard totalPromptCount > 0 else { return 0 }
        let any = matchedPromptCount + rangePromptCount
        return Double(any) / Double(totalPromptCount)
    }
}

public struct SessionMatchStats: Sendable, Equatable {
    /// CSV 期間と index が重なるセッション（bubble 未取得含む）
    public let sessionsInRange: Int
    /// user プロンプトが 1 件以上あるセッション
    public let sessionsWithPrompts: Int
    /// 1 件以上 exact 突合できたセッション
    public let sessionsExactMatch: Int
    /// 1 件以上 exact または range 突合できたセッション
    public let sessionsAnyMatch: Int

    public var exactSessionRate: Double {
        guard sessionsWithPrompts > 0 else { return 0 }
        return Double(sessionsExactMatch) / Double(sessionsWithPrompts)
    }

    public var anySessionRate: Double {
        guard sessionsWithPrompts > 0 else { return 0 }
        return Double(sessionsAnyMatch) / Double(sessionsWithPrompts)
    }
}

extension UsageReconciler {
    public static func sessionStats(
        prompts: [PromptEvent],
        sessions: [TimelineSession],
        report: ReconciliationReport
    ) -> SessionMatchStats {
        let byPromptID = Dictionary(
            report.estimates.map { ($0.promptID, $0.confidence) },
            uniquingKeysWith: { first, _ in first }
        )
        let promptsBySession = Dictionary(grouping: prompts, by: \.sessionId)

        var exactSessions = 0
        var anySessions = 0
        for sessionID in promptsBySession.keys {
            let confidences = promptsBySession[sessionID]?.compactMap { byPromptID[$0.id] } ?? []
            if confidences.contains(.exact) { exactSessions += 1 }
            if confidences.contains(.exact) || confidences.contains(.range) { anySessions += 1 }
        }

        let withPrompts = sessions.filter { !$0.prompts.isEmpty }.count

        return SessionMatchStats(
            sessionsInRange: sessions.count,
            sessionsWithPrompts: withPrompts,
            sessionsExactMatch: exactSessions,
            sessionsAnyMatch: anySessions
        )
    }
}

public struct ReconciliationConfig: Sendable, Equatable {
    /// プロンプト送信前に許容する usage イベントの余白
    public var preWindow: TimeInterval
    /// プロンプト送信後、同一リクエストとみなす窓
    public var postWindow: TimeInterval
    /// 未突合時にレンジ表示するための拡張窓
    public var rangeSlack: TimeInterval

    public init(
        preWindow: TimeInterval = 30,
        postWindow: TimeInterval = 300,
        rangeSlack: TimeInterval = 300
    ) {
        self.preWindow = preWindow
        self.postWindow = postWindow
        self.rangeSlack = rangeSlack
    }
}
