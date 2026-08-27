import SwiftUI

@main
struct MusicProjectsOrganizerApp: App {
    @StateObject private var viewModel = InboxViewModel()

    var body: some Scene {
        WindowGroup("Music Projects Organizer") {
            InboxView(viewModel: viewModel)
                .focusable()
                .onKeyPress(.space) {
                    viewModel.tapBeat()
                    return .handled
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Folder…") { viewModel.openFolder() }
                    .keyboardShortcut("o", modifiers: [.command])

                Button("Use Inbox") { viewModel.useInbox() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                    .disabled(viewModel.isWorkbenchMode)

                Divider()

                Button("File It") { viewModel.fileSelected() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!viewModel.canFile)

                Button("Rename") { viewModel.renameSelected() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                    .disabled(!viewModel.canRename)

                Button("Skip") { viewModel.skip() }
                    .keyboardShortcut(".", modifiers: [.command])
                    .disabled(viewModel.selectedPile == nil)

                Divider()

                Button("Tap Tempo") { viewModel.tapBeat() }
                    .keyboardShortcut(.space, modifiers: [])
                    .disabled(viewModel.selectedPile == nil)

                Button("Previous Audio") { viewModel.selectAdjacentPreview(offset: -1) }
                    .disabled(viewModel.audioFiles.isEmpty)

                Button("Next Audio") { viewModel.selectAdjacentPreview(offset: 1) }
                    .disabled(viewModel.audioFiles.isEmpty)

                Divider()

                Button("Reveal Pile in Finder") { viewModel.revealSelected() }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(viewModel.selectedPile == nil)

                Button("Reveal Current Folder") { viewModel.revealCurrentFolder() }
                    .keyboardShortcut("r", modifiers: [.command, .option])

                Button("Reveal _Start in Finder") { viewModel.revealStart() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Reload") { viewModel.reload() }
                    .keyboardShortcut("l", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let musicProjectsOrganizerReload = Notification.Name("musicProjectsOrganizerReload")
}
