import Foundation

public enum TimelineMerger {
    private static let mergeWindow: TimeInterval = 15 * 60

    public static func merge(
        index: [SessionMeta],
        bubbles: [RawUserBubble],
        transcripts: [AgentTranscriptSession]
    ) -> [TimelineSession] {
        let bubblesByComposer = Dictionary(grouping: bubbles, by: \.composerId)
        var sessions: [String: TimelineSession] = [:]

        for meta in index {
            sessions[meta.id] = makeComposerSession(
                meta: meta,
                bubbles: bubblesByComposer[meta.id] ?? []
            )
        }

        for transcript in transcripts {
            if var existing = sessions[transcript.composerId] {
                existing = merge(existing: existing, with: transcript)
                sessions[transcript.composerId] = existing
                continue
            }

            if let candidateID = findMergeCandidateID(in: Array(sessions.values), transcript: transcript),
               var existing = sessions[candidateID] {
                existing = merge(existing: existing, with: transcript)
                sessions[candidateID] = existing
                continue
            }

            sessions[transcript.composerId] = makeTranscriptSession(transcript)
        }

        return sessions.values.sorted { $0.startAt > $1.startAt }
    }

    private static func makeComposerSession(meta: SessionMeta, bubbles: [RawUserBubble]) -> TimelineSession {
        let prompts = prompts(from: bubbles, sessionId: meta.id)
        let startAt = prompts.map(\.timestamp).min() ?? meta.startAt
        let endAt = prompts.map(\.timestamp).max() ?? meta.endAt
        let title = resolvedTitle(metaTitle: meta.title, prompts: prompts)

        return TimelineSession(
            id: meta.id,
            repoId: meta.repoId,
            repoLabel: meta.repoLabel,
            title: title,
            startAt: startAt,
            endAt: endAt,
            source: meta.source,
            prompts: prompts
        )
    }

    private static func makeTranscriptSession(_ transcript: AgentTranscriptSession) -> TimelineSession {
        let repo = RepoIdentity(repoId: transcript.projectSlug, repoLabel: transcript.projectSlug)
        let prompts = transcriptPrompts(from: transcript, sessionId: transcript.composerId, confidence: .low)
        let startAt = prompts.first?.timestamp ?? transcript.fileModifiedAt
        let endAt = prompts.last?.timestamp ?? transcript.fileModifiedAt
        let title = resolvedTitle(metaTitle: "Untitled", prompts: prompts)

        return TimelineSession(
            id: transcript.composerId,
            repoId: repo.repoId,
            repoLabel: repo.repoLabel,
            title: title,
            startAt: startAt,
            endAt: endAt,
            source: .agentTranscript,
            prompts: prompts
        )
    }

    private static func merge(existing: TimelineSession, with transcript: AgentTranscriptSession) -> TimelineSession {
        let mergedPrompts = mergePrompts(existing: existing.prompts, transcript: transcript)
        let startAt = mergedPrompts.map(\.timestamp).min() ?? existing.startAt
        let endAt = mergedPrompts.map(\.timestamp).max() ?? existing.endAt

        return TimelineSession(
            id: existing.id,
            repoId: existing.repoId,
            repoLabel: existing.repoLabel,
            title: existing.title == "Untitled" ? resolvedTitle(metaTitle: existing.title, prompts: mergedPrompts) : existing.title,
            startAt: startAt,
            endAt: endAt,
            source: .merged,
            prompts: mergedPrompts
        )
    }

    private static func prompts(from bubbles: [RawUserBubble], sessionId: String) -> [PromptEvent] {
        bubbles
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            .map { bubble in
                PromptEvent(
                    id: bubble.bubbleId,
                    sessionId: sessionId,
                    timestamp: bubble.createdAt ?? .distantPast,
                    text: bubble.text,
                    model: ModelNormalizer.normalize(bubble.modelRaw),
                    confidence: bubble.createdAt == nil ? .medium : .high
                )
            }
    }

    private static func transcriptPrompts(
        from transcript: AgentTranscriptSession,
        sessionId: String,
        confidence: TimestampConfidence
    ) -> [PromptEvent] {
        transcript.userMessages.enumerated().map { offset, message in
            PromptEvent(
                id: "transcript-\(sessionId)-\(message.lineIndex)",
                sessionId: sessionId,
                timestamp: transcript.fileModifiedAt.addingTimeInterval(TimeInterval(offset)),
                text: message.text,
                model: .other,
                confidence: confidence
            )
        }
    }

    private static func mergePrompts(
        existing: [PromptEvent],
        transcript: AgentTranscriptSession
    ) -> [PromptEvent] {
        var merged = existing
        let existingKeys = Set(existing.map { normalizedPromptKey($0.text) })

        for message in transcript.userMessages {
            let key = normalizedPromptKey(message.text)
            guard !existingKeys.contains(key) else { continue }
            merged.append(
                PromptEvent(
                    id: "transcript-\(transcript.composerId)-\(message.lineIndex)",
                    sessionId: transcript.composerId,
                    timestamp: transcript.fileModifiedAt.addingTimeInterval(TimeInterval(message.lineIndex)),
                    text: message.text,
                    model: .other,
                    confidence: .medium
                )
            )
        }

        return merged.sorted { $0.timestamp < $1.timestamp }
    }

    private static func findMergeCandidateID(
        in sessions: [TimelineSession],
        transcript: AgentTranscriptSession
    ) -> String? {
        let repo = RepoIdentity(repoId: transcript.projectSlug, repoLabel: transcript.projectSlug)
        let transcriptStart = transcript.fileModifiedAt

        return sessions.first { session in
            session.repoId == repo.repoId
                && abs(session.startAt.timeIntervalSince(transcriptStart)) <= mergeWindow
        }?.id
    }

    private static func resolvedTitle(metaTitle: String, prompts: [PromptEvent]) -> String {
        if metaTitle != "Untitled", !metaTitle.isEmpty {
            return metaTitle
        }
        guard let first = prompts.first?.text else { return "Untitled" }
        let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled" }
        return String(trimmed.prefix(80))
    }

    private static func normalizedPromptKey(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<user_query>", with: "")
            .replacingOccurrences(of: "</user_query>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
