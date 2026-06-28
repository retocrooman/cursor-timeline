import SwiftUI
import CursorTimelineCore

public struct LegendView: View {
    let sessions: [TimelineSession]

    public init(sessions: [TimelineSession]) {
        self.sessions = sessions
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 24) {
            repoLegend
            Divider()
                .frame(height: 20)
            modelLegend
            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var repoLegend: some View {
        HStack(spacing: 12) {
            Text("Repo")
                .foregroundStyle(.secondary)
            ForEach(uniqueRepos, id: \.repoId) { repo in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(RepoColorPalette.color(for: repo.repoId))
                        .frame(width: 12, height: 12)
                    Text(repo.repoLabel)
                        .lineLimit(1)
                }
            }
        }
    }

    private var modelLegend: some View {
        HStack(spacing: 12) {
            Text("Model")
                .foregroundStyle(.secondary)
            ForEach(ModelFamily.allCases, id: \.self) { model in
                if usedModels.contains(model) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(ModelColorPalette.color(for: model))
                            .frame(width: 8, height: 8)
                        Text(ModelColorPalette.label(for: model))
                    }
                }
            }
        }
    }

    private var uniqueRepos: [(repoId: String, repoLabel: String)] {
        var seen = Set<String>()
        return sessions.compactMap { session in
            guard seen.insert(session.repoId).inserted else { return nil }
            return (session.repoId, session.repoLabel)
        }
    }

    private var usedModels: Set<ModelFamily> {
        Set(sessions.flatMap { $0.prompts.map(\.model) })
    }
}
