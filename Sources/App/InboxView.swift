import AppKit
import SwiftUI
import MusicProjectsOrganizerCore

struct InboxView: View {
    @ObservedObject var viewModel: InboxViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: 280)
                .background(Theme.sidebar)
        } detail: {
            detail
                .background(Theme.background)
        }
        .frame(minWidth: 860, minHeight: 520)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItemGroup {
                Button("Reveal pile", systemImage: "folder") { viewModel.revealSelected() }
                    .disabled(viewModel.selectedPile == nil)
                    .help("Reveal the selected pile in Finder")
            }
        }
        .task {
            viewModel.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .musicProjectsOrganizerReload)) { _ in
            viewModel.reload()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer(minLength: 0)
                    HStack(spacing: 18) {
                        Button {
                            viewModel.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Reload this folder")

                        Button {
                            viewModel.openFolder()
                        } label: {
                            Image(systemName: "folder.badge.plus")
                        }
                        .buttonStyle(.borderless)
                        .help("Choose a source folder to inspect")

                        Button {
                            viewModel.revealCurrentFolder()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        .help("Reveal the source folder in Finder")

                        Button {
                            viewModel.useInbox()
                        } label: {
                            Image(systemName: "tray")
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.isWorkbenchMode)
                        .help(viewModel.isWorkbenchMode ? "Already in Inbox" : "Back to Inbox")
                    }
                    .font(.title2)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)

                HStack {
                    Text(viewModel.locationTitle.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text("\(viewModel.visiblePiles.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                        .help("Number of piles in this folder")
                }
                Text(viewModel.locationPath)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .help(viewModel.locationPath)
                Toggle("Unnamed only", isOn: $viewModel.showUnnamedOnly)
                    .font(.caption)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("Show only unnamed dumps")
                    .onChange(of: viewModel.showUnnamedOnly) { _, _ in
                        if let selected = viewModel.selectedPile,
                           viewModel.visiblePiles.contains(where: { $0.id == selected.id }) {
                            return
                        }
                        if let first = viewModel.visiblePiles.first {
                            viewModel.select(first)
                        } else {
                            viewModel.selectedPileID = nil
                        }
                    }
            }
            .padding()

            if viewModel.isLoading && viewModel.piles.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading…")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            ScrollViewReader { proxy in
                List(viewModel.visiblePiles, selection: $viewModel.selectedPileID) { pile in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(pile.displayName)
                                .lineLimit(1)
                            if pile.isUnnamed {
                                Text("unnamed")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        Text(pileSubtitle(pile))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    .tag(pile.id)
                    .id(pile.id)
                }
                .listStyle(.sidebar)
                .onChange(of: viewModel.selectedPileID) { _, newID in
                    viewModel.navFocus = .piles
                    if let pile = viewModel.piles.first(where: { $0.id == newID }) {
                        viewModel.select(pile)
                    }
                    scrollSidebar(proxy, to: newID)
                }
                .onChange(of: viewModel.piles) { _, _ in
                    scrollSidebar(proxy, to: viewModel.selectedPileID)
                }
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let pile = viewModel.selectedPile {
            VStack(spacing: 0) {
                // Info header
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(kindLabel(pile))
                                .font(.subheadline.weight(.medium))
                            if pile.isUnnamed {
                                Text("unnamed")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        Text(contentsLabel(pile))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        if viewModel.inventory?.hasLogicProject == true || pile.kind == .logicPackage {
                            Text("Close in Logic before filing.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    if let cover = viewModel.coverURL {
                        CoverPreview(url: cover)
                            .onTapGesture { viewModel.revealItem(cover) }
                            .help("Reveal cover in Finder")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // File list — flexible, fills remaining space
                if !viewModel.contentItems.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(viewModel.contentItems) { row in
                                Button {
                                    if row.isAudio {
                                        viewModel.choosePreview(row.url)
                                    } else {
                                        viewModel.selectContent(row.url)
                                        viewModel.revealItem(row.url)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: row.isAudio ? "waveform" : (row.isImage ? "photo" : (row.isDirectory ? "folder" : "doc")))
                                            .frame(width: 12)
                                        Text(row.name)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(row.kindLabel)
                                        if row.fileSize > 0, !row.isDirectory {
                                            Text(byteString(row.fileSize))
                                                .monospacedDigit()
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(isSelectedContent(row.url) ? Theme.accent : Theme.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(
                                        isSelectedContent(row.url)
                                            ? Theme.accent.opacity(0.12)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 4)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                    }
                    .scrollIndicators(.visible)
                    .frame(maxHeight: .infinity)
                } else {
                    Spacer(minLength: 0)
                }

                Divider()

                // Preview
                VStack(alignment: .leading, spacing: 6) {
                    if viewModel.selectedPreviewURL != nil {
                        PreviewControls(
                            player: viewModel.player,
                            filename: viewModel.selectedPreviewURL?.lastPathComponent ?? ""
                        )
                    } else if viewModel.contentItems.contains(where: \.isAudio) {
                        Text("Click a file or ↑↓ to preview.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    } else {
                        Text("No audio in this pile.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // Name
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        TextField("Description", text: $viewModel.descriptionText)
                            .textFieldStyle(.roundedBorder)
                        Button("Auto rename") { viewModel.autoRenameSelected() }
                            .disabled(!viewModel.canAutoRename || viewModel.isFiling)
                            .help("Remove spaces and capitalize each word, like UnderwaterGuitar.")
                    }
                    HStack(spacing: 8) {
                        TextField("YYMMDD", text: $viewModel.dateText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 88)
                        TextField("BPM or 000", text: $viewModel.bpmText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 88)
                        Button(viewModel.tapCount > 0 ? "Tap (\(viewModel.tapCount))" : "Tap") {
                            viewModel.tapBeat()
                        }
                        .help("Tap the beat. Leave 000 if there is no tempo.")
                        Spacer()
                    }
                    if !viewModel.proposedFolderName.isEmpty {
                        Text(viewModel.proposedFolderName)
                            .font(.caption.monospaced())
                            .foregroundStyle(viewModel.isNameValid ? Theme.accent : Theme.muted)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // Organize
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Picker("", selection: $viewModel.destination) {
                            Text(FileDestination.inPlace.title).tag(FileDestination.inPlace)
                            Text(FileDestination.start.title).tag(FileDestination.start)
                            if viewModel.customDestination != nil {
                                Text(viewModel.customDestination?.lastPathComponent ?? "Other")
                                    .tag(FileDestination.custom)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Button("Choose folder…") {
                            viewModel.chooseCustomDestination()
                        }
                    }
                    if viewModel.destination == .custom, let folder = viewModel.customDestination {
                        Text(folder.path)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .textSelection(.enabled)
                            .lineLimit(1)
                    }
                    if pile.kind == .looseFiles {
                        Text("Loose files will be wrapped into the new folder. Subfolders stay put.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    HStack {
                        Button("Skip") { viewModel.skip() }
                        Spacer()
                        Button(fileButtonTitle(pile), action: viewModel.fileSelected)
                            .keyboardShortcut(.return, modifiers: [])
                            .buttonStyle(.borderedProminent)
                            .disabled(!viewModel.canFile)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .navigationTitle(pile.kind == .looseFiles ? "Wrap files" : "Organize")
            .safeAreaInset(edge: .bottom) {
                Text(viewModel.status)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
        } else if viewModel.isLoading {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                viewModel.isWorkbenchMode ? "Inbox is clear" : "Nothing to organize",
                systemImage: "checkmark.circle",
                description: Text(
                    viewModel.isWorkbenchMode
                        ? "Drop a session folder into _Music Projects/_Inbox, or open any folder."
                        : "Open another folder, or turn off Unnamed only."
                )
            )
        }
    }

    // MARK: - Helpers

    private func scrollSidebar(_ proxy: ScrollViewProxy, to id: URL?) {
        guard let id else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private func isSelectedContent(_ url: URL) -> Bool {
        viewModel.selectedContentID?.standardized.path == url.standardized.path
    }

    private func pileSubtitle(_ pile: Pile) -> String {
        let files = "\(pile.fileCount) file\(pile.fileCount == 1 ? "" : "s")"
        let size = pile.byteSize > 0 ? " · \(byteString(pile.byteSize))" : ""
        let origin = pile.origin == .folder ? pile.kind.rawValue : pile.origin.rawValue
        return "\(files)\(size) · \(origin)"
    }

    private func kindLabel(_ pile: Pile) -> String {
        switch pile.kind {
        case .looseFiles: return "Loose files"
        case .logicPackage: return "Logic project"
        case .folder: return "Folder"
        }
    }

    private func contentsLabel(_ pile: Pile) -> String {
        if let inventory = viewModel.inventory {
            return "\(inventory.summary) · \(byteString(inventory.totalBytes))"
        }
        return "\(pile.fileCount) file\(pile.fileCount == 1 ? "" : "s")"
    }

    private func fileButtonTitle(_ pile: Pile) -> String {
        switch (pile.kind, viewModel.destination) {
        case (.looseFiles, _): return "Wrap files"
        case (_, .inPlace): return "Rename"
        default: return "File it"
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Subviews

private struct CoverPreview: View {
    let url: URL

    var body: some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.06))
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PreviewControls: View {
    @ObservedObject var player: PreviewPlayer
    let filename: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WaveformView(
                samples: player.samples,
                progress: player.progress,
                currentTime: player.currentTime,
                duration: player.duration,
                onSeek: { player.seek(toProgress: $0) },
                onSeekEnd: { player.play() }
            )
            HStack {
                Button(player.isPlaying ? "Pause" : "Play") {
                    player.toggle()
                }
                Text(filename)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
    }
}
