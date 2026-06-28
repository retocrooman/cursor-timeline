import Foundation

public struct OverlapPlacement: Equatable, Sendable {
    public let column: Int
    public let totalColumns: Int

    public init(column: Int, totalColumns: Int) {
        self.column = column
        self.totalColumns = totalColumns
    }
}

public enum OverlapLayout {
    public struct SessionInterval: Identifiable, Equatable, Sendable {
        public let id: String
        public let start: Date
        public let end: Date

        public init(id: String, start: Date, end: Date) {
            self.id = id
            self.start = start
            self.end = end
        }
    }

    /// 同一日のセッションに greedy column を割当（DESIGN §7）
    public static func compute(sessions: [SessionInterval]) -> [String: OverlapPlacement] {
        guard !sessions.isEmpty else { return [:] }

        let sorted = sessions.sorted { lhs, rhs in
            if lhs.start != rhs.start {
                return lhs.start < rhs.start
            }
            let lhsDuration = lhs.end.timeIntervalSince(lhs.start)
            let rhsDuration = rhs.end.timeIntervalSince(rhs.start)
            return lhsDuration > rhsDuration
        }

        var clusters: [[SessionInterval]] = []
        var currentCluster: [SessionInterval] = []
        var clusterEnd = Date.distantPast

        for session in sorted {
            if currentCluster.isEmpty || session.start < clusterEnd {
                currentCluster.append(session)
                clusterEnd = max(clusterEnd, session.end)
            } else {
                clusters.append(currentCluster)
                currentCluster = [session]
                clusterEnd = session.end
            }
        }
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }

        var result: [String: OverlapPlacement] = [:]

        for cluster in clusters {
            let clusterSorted = cluster.sorted { lhs, rhs in
                if lhs.start != rhs.start {
                    return lhs.start < rhs.start
                }
                let lhsDuration = lhs.end.timeIntervalSince(lhs.start)
                let rhsDuration = rhs.end.timeIntervalSince(rhs.start)
                return lhsDuration > rhsDuration
            }

            var columnEnds: [Date] = []
            var assignments: [(id: String, column: Int)] = []

            for session in clusterSorted {
                if let column = columnEnds.firstIndex(where: { $0 <= session.start }) {
                    assignments.append((session.id, column))
                    columnEnds[column] = session.end
                } else {
                    assignments.append((session.id, columnEnds.count))
                    columnEnds.append(session.end)
                }
            }

            let totalColumns = max(columnEnds.count, 1)
            for (id, column) in assignments {
                result[id] = OverlapPlacement(column: column, totalColumns: totalColumns)
            }
        }

        return result
    }
}
