import SwiftUI
import CursorTimelineCore

enum RepoColorPalette {
    private static let palette: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint, .cyan, .brown,
    ]

    static func color(for repoId: String) -> Color {
        let index = abs(repoId.hashValue) % palette.count
        return palette[index]
    }
}

enum ModelColorPalette {
    static func color(for model: ModelFamily) -> Color {
        switch model {
        case .opus: return .purple
        case .sonnet: return .blue
        case .composer: return .green
        case .gpt: return .orange
        case .other: return .gray
        }
    }

    static func label(for model: ModelFamily) -> String {
        switch model {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .composer: return "Composer"
        case .gpt: return "GPT"
        case .other: return "その他"
        }
    }
}
