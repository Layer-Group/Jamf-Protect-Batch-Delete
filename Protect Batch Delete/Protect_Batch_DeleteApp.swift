//
//  Protect_Batch_DeleteApp.swift
//  Protect Batch Delete
//
//  Created by Richard Mallion on 21/02/2023.
//

import SwiftUI
import Charts
import CryptoKit
import AppKit

@main
struct Protect_Batch_DeleteApp: App {
    @StateObject private var statsStore = RunStatsStore()
    @StateObject private var auditStore = AuditLogStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(
                    minWidth: 750, maxWidth: 1000,
                    minHeight: 600, maxHeight: 900)
                .environmentObject(statsStore)
                .environmentObject(auditStore)
        }
        .windowResizability(.contentSize)
        .commands { ExportCommands() }

        WindowGroup("Dashboard", id: "dashboard") {
            DashboardView()
                .environmentObject(statsStore)
                .frame(minWidth: 720, minHeight: 540)
        }

    }
}

// MARK: - App Commands
struct ExportCommands: Commands {
    @FocusedValue(\.exportSuccessesAction) var exportAction
    @FocusedValue(\.hasSuccesses) var hasSuccesses
    @Environment(\.openWindow) var openWindow
    @EnvironmentObject var auditStore: AuditLogStore

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button("Export successes CSV") { exportAction?() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!(hasSuccesses ?? false))
            Divider()
            Button("Export Audit Log…") { auditStore.exportSignedAuditLog() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
        }
        CommandGroup(after: .appInfo) {
            Button("Send Feedback…") {
                if let url = URL(string: "https://github.com/Layer-Group/Jamf-Protect-Batch-Delete/issues/new/choose") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        CommandMenu("View") {
            Button("Show Dashboard") { openWindow(id: "dashboard") }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Divider()
            Button("Export successes CSV") { exportAction?() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!(hasSuccesses ?? false))
            Button("Export Audit Log…") { auditStore.exportSignedAuditLog() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}

// MARK: - Dashboard View (inlined for target inclusion)
struct DashboardView: View {
    @EnvironmentObject var stats: RunStatsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Dashboard", systemImage: "chart.bar.doc.horizontal")
                    .font(.title2.bold())
                Spacer()
                if let ts = stats.lastUpdated {
                    Text(ts, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Last updated")
                }
            }

            HStack(spacing: 16) {
                statTile(icon: "checkmark.circle.fill", color: .green, title: "Success", value: stats.successes)
                statTile(icon: "xmark.octagon.fill", color: .red, title: "Failed", value: stats.failures)
                statTile(icon: "arrow.clockwise.circle.fill", color: .blue, title: "Retried", value: stats.retried)
                statTile(icon: "number.circle", color: .gray, title: "Total", value: stats.total)
            }

            GroupBox("Status Breakdown") {
                Chart(stats.statusBreakdown, id: \.key) { item in
                    BarMark(
                        x: .value("Status", item.key),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(by: .value("Status", item.key))
                }
                .chartLegend(.visible)
                .frame(height: 220)
                .accessibilityLabel("Status breakdown chart")
            }

            GroupBox("Success Ratio") {
                HStack {
                    if #available(macOS 14.0, *) {
                        Chart {
                            let success = Double(max(stats.successes, 0))
                            let fail = Double(max(stats.failures, 0))
                            if success + fail > 0 {
                                SectorMark(angle: .value("Success", success), innerRadius: .ratio(0.6))
                                    .foregroundStyle(Color.green)
                                SectorMark(angle: .value("Failed", fail), innerRadius: .ratio(0.6))
                                    .foregroundStyle(Color.red)
                            }
                        }
                        .frame(width: 220, height: 220)
                    } else {
                        // Fallback: stacked horizontal bar for macOS 13
                        Chart {
                            BarMark(
                                x: .value("Count", max(stats.successes, 0)),
                                y: .value("", "Success")
                            ).foregroundStyle(Color.green)
                            BarMark(
                                x: .value("Count", max(stats.failures, 0)),
                                y: .value("", "Failed")
                            ).foregroundStyle(Color.red)
                        }
                        .frame(width: 260, height: 120)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Success: \(stats.successes)", systemImage: "checkmark.circle")
                            .foregroundColor(.green)
                        Label("Failed: \(stats.failures)", systemImage: "xmark.octagon")
                            .foregroundColor(.red)
                        if stats.total > 0 {
                            let ratio = Int(round((Double(stats.successes) / Double(stats.total)) * 100))
                            Text("Success ratio: \(ratio)%")
                                .font(.headline)
                        }
                    }
                    Spacer()
                }
            }

            GroupBox("Top Errors") {
                if stats.errorBreakdown.isEmpty {
                    Text("No errors in last run.")
                        .foregroundColor(.secondary)
                } else {
                    List(stats.errorBreakdown.prefix(10), id: \.key) { row in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text(row.key)
                                .textSelection(.enabled)
                            Spacer()
                            Text("\(row.count)")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(minHeight: 140, maxHeight: 220)
                }
            }

            Spacer()
        }
        .padding(16)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { /* no-op, store is live */ }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh from the last run in the current window")
            }
        }
    }

    @ViewBuilder
    private func statTile(icon: String, color: Color, title: String, value: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text("\(value)").font(.title3.bold())
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
}
