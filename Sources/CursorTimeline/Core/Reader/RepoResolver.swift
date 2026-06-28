import Foundation

public struct RepoIdentity: Sendable, Equatable {
    public let repoId: String
    public let repoLabel: String
}

public enum RepoResolver {
    public static func resolve(workspacePath: String?) -> RepoIdentity {
        guard let raw = workspacePath?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return RepoIdentity(repoId: "unknown", repoLabel: "unknown")
        }

        if raw == "empty-window" {
            return RepoIdentity(repoId: "empty-window", repoLabel: "ホーム")
        }

        let normalized = (raw as NSString).standardizingPath
        let label = URL(fileURLWithPath: normalized).lastPathComponent
        return RepoIdentity(
            repoId: normalized,
            repoLabel: label.isEmpty ? normalized : label
        )
    }
}
