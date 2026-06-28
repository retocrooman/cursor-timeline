import Foundation

public struct CursorPaths: Sendable, Equatable {
    public let homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    public var cursorApplicationSupport: URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support/Cursor/User", isDirectory: true)
    }

    public var globalDatabase: URL {
        cursorApplicationSupport
            .appendingPathComponent("globalStorage/state.vscdb", isDirectory: false)
    }

    public var workspaceStorage: URL {
        cursorApplicationSupport.appendingPathComponent("workspaceStorage", isDirectory: true)
    }

    public var agentTranscriptsRoot: URL {
        homeDirectory.appendingPathComponent(".cursor/projects", isDirectory: true)
    }
}
