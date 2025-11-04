//
//  Protect_Batch_DeleteApp.swift
//  Protect Batch Delete
//
//  Created by Richard Mallion on 21/02/2023.
//

import SwiftUI

@main
struct Protect_Batch_DeleteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(
                    minWidth: 750, maxWidth: 1000,
                    minHeight: 600, maxHeight: 900)

        }
        .windowResizability(.contentSize)
        .commands { ExportCommands() }

    }
}

// MARK: - App Commands
struct ExportCommands: Commands {
    @FocusedValue(\.exportSuccessesAction) var exportAction
    @FocusedValue(\.hasSuccesses) var hasSuccesses

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button("Export successes CSV") { exportAction?() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!(hasSuccesses ?? false))
        }
    }
}
