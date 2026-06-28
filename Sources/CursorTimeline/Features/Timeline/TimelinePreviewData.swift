import Foundation
import CursorTimelineCore

public enum TimelinePreviewData {
    public static func mockSessions(calendar: Calendar = .current, now: Date = Date()) -> [TimelineSession] {
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let dayBefore = calendar.date(byAdding: .day, value: -2, to: today) else {
            return []
        }

        func at(_ day: Date, hour: Int, minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let sessionA = TimelineSession(
            id: "mock-a",
            repoId: "github.com/acme/frontend",
            repoLabel: "frontend",
            title: "ログイン画面のリファクタ",
            startAt: at(dayBefore, hour: 10),
            endAt: at(dayBefore, hour: 12, minute: 30),
            source: .composer,
            prompts: [
                PromptEvent(
                    id: "p1",
                    sessionId: "mock-a",
                    timestamp: at(dayBefore, hour: 10, minute: 15),
                    text: "ログインフォームのバリデーションを追加して",
                    model: .sonnet,
                    confidence: .high
                ),
                PromptEvent(
                    id: "p2",
                    sessionId: "mock-a",
                    timestamp: at(dayBefore, hour: 11, minute: 40),
                    text: "エラーメッセージを日本語にして",
                    model: .opus,
                    confidence: .high
                ),
            ]
        )

        let sessionB = TimelineSession(
            id: "mock-b",
            repoId: "github.com/acme/backend",
            repoLabel: "backend",
            title: "API エンドポイント追加",
            startAt: at(yesterday, hour: 14),
            endAt: at(yesterday, hour: 16),
            source: .composer,
            prompts: [
                PromptEvent(
                    id: "p3",
                    sessionId: "mock-b",
                    timestamp: at(yesterday, hour: 14, minute: 20),
                    text: "POST /users のハンドラを実装して",
                    model: .composer,
                    confidence: .high
                ),
            ]
        )

        let sessionC = TimelineSession(
            id: "mock-c",
            repoId: "github.com/acme/frontend",
            repoLabel: "frontend",
            title: "ダッシュボード UI",
            startAt: at(today, hour: 9, minute: 30),
            endAt: at(today, hour: 11),
            source: .composer,
            prompts: [
                PromptEvent(
                    id: "p4",
                    sessionId: "mock-c",
                    timestamp: at(today, hour: 10),
                    text: "カードレイアウトを3列にして",
                    model: .sonnet,
                    confidence: .high
                ),
            ]
        )

        let sessionD = TimelineSession(
            id: "mock-d",
            repoId: "github.com/acme/mobile",
            repoLabel: "mobile",
            title: "Push 通知設定",
            startAt: at(today, hour: 9, minute: 45),
            endAt: at(today, hour: 11, minute: 30),
            source: .composer,
            prompts: [
                PromptEvent(
                    id: "p5",
                    sessionId: "mock-d",
                    timestamp: at(today, hour: 10, minute: 30),
                    text: "FCM の設定手順を教えて",
                    model: .gpt,
                    confidence: .high
                ),
            ]
        )

        return [sessionA, sessionB, sessionC, sessionD]
    }

    public static var mockWindow: ThreeDayWindow {
        .today()
    }
}
