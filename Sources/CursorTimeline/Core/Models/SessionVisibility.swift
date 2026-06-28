import Foundation

public enum SessionVisibility {
    /// タイムライン表示対象か（ADR-022）
    public static func isDisplayable(_ session: TimelineSession) -> Bool {
        if session.prompts.isEmpty, isBlankTitle(session.title) {
            return false
        }
        return true
    }

    public static func filterDisplayable(_ sessions: [TimelineSession]) -> [TimelineSession] {
        sessions.filter(isDisplayable)
    }

    private static func isBlankTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "Untitled"
    }
}
