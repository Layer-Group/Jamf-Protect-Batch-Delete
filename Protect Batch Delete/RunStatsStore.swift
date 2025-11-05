import Foundation
import SwiftUI

final class RunStatsStore: ObservableObject {
    @Published var lastRunItems: [Item] = []
    @Published var lastUpdated: Date? = nil

    var total: Int { lastRunItems.count }
    var successes: Int { lastRunItems.filter { $0.status.lowercased().contains("success") || $0.status.lowercased().contains("deleted") }.count }
    var failures: Int { lastRunItems.filter { $0.status.lowercased().contains("failed") || $0.status.lowercased().contains("error") }.count }
    var retried: Int { lastRunItems.filter { $0.status.lowercased().contains("retried") }.count }

    var errorBreakdown: [(key: String, count: Int)] {
        let errors = lastRunItems.compactMap { $0.lastError?.trimmingCharacters(in: .whitespacesAndNewlines) }
        let counts = Dictionary(errors.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value > $1.value }
    }

    var statusBreakdown: [(key: String, count: Int)] {
        let statuses = lastRunItems.map { normalizedStatus($0.status) }
        let counts = Dictionary(statuses.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value > $1.value }
    }

    private func normalizedStatus(_ raw: String) -> String {
        let s = raw.lowercased()
        if s.contains("success") || s.contains("deleted") { return "Success" }
        if s.contains("failed") || s.contains("error") { return "Failed" }
        if s.contains("running") { return "Running" }
        if s.contains("queued") { return "Queued" }
        if s.contains("retried") { return "Retried" }
        return raw.capitalized
    }
}
