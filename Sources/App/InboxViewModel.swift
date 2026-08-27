import AppKit
import Foundation
import MusicProjectsOrganizerCore
import SwiftUI

enum NavFocus {
    case piles
    case files
}

struct ContentItem: Identifiable, Hashable {
    var id: URL { url }
    var url: URL
    var name: String
    var kindLabel: String
    var fileSize: Int64
    var isAudio: Bool
    var isDirectory: Bool
    var isImage: Bool

    init(url: URL, name: String, kindLabel: String, fileSize: Int64, isAudio: Bool, isDirectory: Bool, isImage: Bool) {
        self.url = url
        self.name = name
        self.kindLabel = kindLabel
        self.fileSize = fileSize
        self.isAudio = isAudio
        self.isDirectory = isDirectory
        self.isImage = isImage
    }

    init(_ entry: InventoryEntry) {
        url = entry.url
        name = entry.name
        kindLabel = entry.kindLabel
        fileSize = entry.fileSize
        isAudio = entry.isAudio
        isDirectory = entry.isDirectory
        isImage = entry.isImage
    }
}

enum FileDestination: String, CaseIterable, Identifiable {
    case inPlace
    case start
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inPlace: return "Here"
        case .start: return "_Start"
        case .custom: return "Choose…"
        }
    }
}

@MainActor
final class InboxViewModel: ObservableObject {
    @Published private(set) var piles: [Pile] = []
    @Published var selectedPileID: URL?
    @Published var dateText = ""
    @Published var descriptionText = ""
    @Published var bpmText = ""
    @Published var destination: FileDestination = .inPlace
    @Published var customDestination: URL?
    @Published var showUnnamedOnly = false
    @Published private(set) var scanRoot: URL?
    @Published private(set) var inventory: FolderInventory?
    @Published private(set) var audioFiles: [URL] = []
    @Published private(set) var contentItems: [ContentItem] = []
    @Published private(set) var coverURL: URL?
    @Published var selectedPreviewURL: URL?
    @Published var selectedContentID: URL?
    @Published var navFocus: NavFocus = .piles
    @Published private(set) var status = "Ready"
    @Published private(set) var isFiling = false
    @Published private(set) var tapCount = 0
    let player = PreviewPlayer()

    let service: InboxService
    private let scanRootKey = "musicprojects.scanRoot"
    private var tapTempo = TapTempo()
    private var keyMonitor: Any?

    init(service: InboxService = InboxService(workbench: .live())) {
        self.service = service
        if let path = UserDefaults.standard.string(forKey: scanRootKey),
           !path.isEmpty,
           FileManager.default.fileExists(atPath: path) {
            scanRoot = URL(fileURLWithPath: path, isDirectory: true)
        }
        startKeyMonitor()
        reload()
    }

    var isWorkbenchMode: Bool { scanRoot == nil }

    var locationTitle: String {
        scanRoot?.lastPathComponent ?? "Inbox"
    }

    var locationPath: String {
        scanRoot?.path ?? service.workbench.root.path
    }

    var visiblePiles: [Pile] {
        showUnnamedOnly ? piles.filter(\.isUnnamed) : piles
    }

    var selectedPile: Pile? {
        piles.first(where: { $0.id == selectedPileID })
    }

    var proposedName: ProjectName {
        ProjectName(
            yymmdd: dateText,
            description: descriptionText,
            bpm: Int(bpmText) ?? 0
        )
    }

    var proposedFolderName: String { proposedName.folderName }

    var proposedDestinationURL: URL? {
        guard let selectedPile, proposedName.isValid else { return nil }
        return service.proposedDestination(for: selectedPile, name: proposedName, parent: destinationParent)
    }

    var isNameValid: Bool { proposedName.isValid }

    var canFile: Bool {
        isNameValid && !isFiling && (destination != .custom || customDestination != nil)
    }

    var canAutoRename: Bool {
        if descriptionText.contains(where: \.isWhitespace) { return true }
        guard let selectedPile, !selectedPile.isUnnamed, selectedPile.kind != .looseFiles else {
            return false
        }
        return ProjectName.removingSpaces(from: selectedPile.displayName) != nil
    }

    var autoRenamePreview: String? {
        selectedPile.flatMap { ProjectName.removingSpaces(from: $0.displayName) }
    }

    func reload(preferring id: URL? = nil) {
        do {
            if isWorkbenchMode {
                try service.ensureInbox()
            }
            piles = try service.loadPiles(in: scanRoot)
            let preferred = id ?? selectedPileID
            if let preferred, let match = pile(matching: preferred) {
                select(match)
            } else if let first = visiblePiles.first {
                select(first)
            } else {
                selectedPileID = nil
                clearForm()
                inventory = nil
                audioFiles = []
                contentItems = []
                coverURL = nil
                selectedPreviewURL = nil
                selectedContentID = nil
                player.stop()
            }
            status = piles.isEmpty ? emptyStatus : "Ready"
        } catch {
            status = error.localizedDescription
        }
    }

    func select(_ pile: Pile) {
        selectedPileID = pile.id
        navFocus = .piles
        resetTapTempo()
        applyForm(for: pile)
        destination = defaultDestination(for: pile)
        loadInspection(for: pile)
    }

    func skip() {
        guard let selectedPile else { return }
        let skippedName = selectedPile.displayName
        player.stop()
        if let index = visiblePiles.firstIndex(where: { $0.id == selectedPile.id }) {
            let nextIndex = index + 1
            if nextIndex < visiblePiles.count {
                select(visiblePiles[nextIndex])
            } else if index > 0 {
                select(visiblePiles[index - 1])
            } else {
                selectedPileID = nil
                clearForm()
                inventory = nil
                audioFiles = []
                contentItems = []
                coverURL = nil
                selectedContentID = nil
            }
        }
        status = "Skipped \(skippedName)."
    }

    func fileSelected() {
        guard let selectedPile, canFile else { return }
        isFiling = true
        defer { isFiling = false }
        player.stop()
        do {
            let result = try service.file(selectedPile, name: proposedName, into: destinationParent)
            status = result.didMove
                ? "Filed → \(result.destination.path)"
                : "Already filed."
            if scanRoot?.standardizedFileURL == selectedPile.sourceURL.standardizedFileURL {
                open(result.destination.deletingLastPathComponent(), persist: true, selecting: result.destination)
                return
            }
            descriptionText = ""
            bpmText = ""
            reloadKeepingStatus(preferring: result.destination)
        } catch {
            status = error.localizedDescription
        }
    }

    func autoRenameSelected() {
        guard canAutoRename else { return }
        if descriptionText.contains(where: \.isWhitespace) {
            descriptionText = ProjectName.pascalCaseWords(descriptionText)
        }
        guard let selectedPile,
              !selectedPile.isUnnamed,
              selectedPile.kind != .looseFiles,
              ProjectName.removingSpaces(from: selectedPile.displayName) != nil
        else {
            status = "Description → \(descriptionText)"
            return
        }
        isFiling = true
        defer { isFiling = false }
        player.stop()
        do {
            let result = try service.autoRename(selectedPile)
            status = result.didMove
                ? "Renamed → \(result.destination.lastPathComponent)"
                : "Already named."
            if scanRoot?.standardizedFileURL == selectedPile.sourceURL.standardizedFileURL {
                open(result.destination.deletingLastPathComponent(), persist: true, selecting: result.destination)
                return
            }
            reloadKeepingStatus(preferring: result.destination)
        } catch {
            status = error.localizedDescription
        }
    }

    func choosePreview(_ url: URL) {
        navFocus = .files
        selectedContentID = url
        if selectedPreviewURL?.standardizedFileURL == url.standardizedFileURL {
            player.toggle()
            return
        }
        selectPreview(url)
    }

    func selectContent(_ url: URL) {
        navFocus = .files
        selectedContentID = url
        if contentItems.first(where: { $0.url == url })?.isAudio == true {
            if selectedPreviewURL?.standardizedFileURL == url.standardizedFileURL {
                player.toggle()
            } else {
                selectPreview(url)
            }
        }
    }

    func selectAdjacentPile(offset: Int) {
        let piles = visiblePiles
        guard !piles.isEmpty else { return }
        let current = selectedPile.flatMap { selected in
            piles.firstIndex { $0.id == selected.id }
        } ?? 0
        let index = min(max(current + offset, 0), piles.count - 1)
        guard index != current else { return }
        select(piles[index])
    }

    func selectAdjacentContent(offset: Int) {
        let items = contentItems
        guard !items.isEmpty else { return }
        let current = selectedContentID.flatMap { url in
            items.firstIndex { $0.url.standardizedFileURL == url.standardizedFileURL }
        } ?? 0
        let index = min(max(current + offset, 0), items.count - 1)
        let item = items[index]
        selectedContentID = item.url
        if item.isAudio {
            selectPreview(item.url)
        }
    }

    func selectAdjacentPreview(offset: Int) {
        selectAdjacentContent(offset: offset)
    }

    private func selectPreview(_ url: URL) {
        selectedPreviewURL = url
        selectedContentID = url
        player.load(url)
        player.play()
    }

    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if NSApp.keyWindow?.firstResponder is NSTextView {
                return event
            }
            switch event.keyCode {
            case 126:
                Task { @MainActor in
                    if self.navFocus == .files {
                        self.selectAdjacentContent(offset: -1)
                    } else {
                        self.selectAdjacentPile(offset: -1)
                    }
                }
                return nil
            case 125:
                Task { @MainActor in
                    if self.navFocus == .files {
                        self.selectAdjacentContent(offset: 1)
                    } else {
                        self.selectAdjacentPile(offset: 1)
                    }
                }
                return nil
            default:
                return event
            }
        }
    }

    func tapBeat() {
        if let bpm = tapTempo.tap(at: ProcessInfo.processInfo.systemUptime) {
            bpmText = String(bpm)
            tapCount = tapTempo.tapCount
            status = "Tapped \(bpm) BPM"
        } else {
            tapCount = tapTempo.tapCount
            status = tapCount == 1 ? "Tap again to set BPM." : "Keep tapping…"
        }
    }

    func resetTapTempo() {
        tapTempo.reset()
        tapCount = 0
    }

    func revealItem(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = scanRoot ?? service.workbench.root
        panel.message = "Choose a folder of music projects or dumps to inspect."
        panel.prompt = "Open"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url, persist: true)
    }

    func useInbox() {
        scanRoot = nil
        UserDefaults.standard.removeObject(forKey: scanRootKey)
        showUnnamedOnly = false
        reload()
    }

    func open(_ url: URL, persist: Bool, selecting id: URL? = nil) {
        scanRoot = url
        if persist {
            UserDefaults.standard.set(url.path, forKey: scanRootKey)
        }
        showUnnamedOnly = false
        selectedPileID = id
        reload(preferring: id)
    }

    func chooseCustomDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Choose destination folder"
        panel.message = "Filed projects will move into this folder."
        panel.prompt = "Use"
        panel.directoryURL = customDestination ?? scanRoot ?? service.workbench.start

        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            Task { @MainActor in
                guard let self else { return }
                guard response == .OK, let url = panel.url else {
                    if self.customDestination == nil {
                        self.destination = self.defaultDestination(for: self.selectedPile)
                    }
                    return
                }
                self.customDestination = url
                self.destination = .custom
                self.status = "Destination → \(url.path)"
            }
        }

        DispatchQueue.main.async {
            if let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) {
                panel.beginSheetModal(for: window, completionHandler: finish)
            } else {
                finish(panel.runModal())
            }
        }
    }

    func revealSelected() {
        guard let selectedPile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selectedPile.sourceURL])
    }

    func revealStart() {
        NSWorkspace.shared.activateFileViewerSelecting([service.workbench.start])
    }

    func revealCurrentFolder() {
        let url = scanRoot ?? service.workbench.inbox
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private var destinationParent: URL? {
        switch destination {
        case .inPlace:
            return nil
        case .start:
            return service.workbench.start
        case .custom:
            return customDestination
        }
    }

    private var emptyStatus: String {
        if isWorkbenchMode {
            return "No unnamed piles."
        }
        return showUnnamedOnly ? "No unnamed folders here." : "This folder is empty."
    }

    private func defaultDestination(for pile: Pile?) -> FileDestination {
        switch pile?.origin {
        case .inbox, .logic:
            return .start
        default:
            return .inPlace
        }
    }

    private func loadInspection(for pile: Pile) {
        inventory = try? service.inspect(pile)
        audioFiles = (try? service.audioFiles(in: pile)) ?? []
        coverURL = try? service.coverURL(for: pile)
        rebuildContentItems()
        let preview = (try? service.previewURL(for: pile)) ?? audioFiles.first
        selectedPreviewURL = preview
        selectedContentID = preview ?? contentItems.first?.url
        player.load(preview)
    }

    private func rebuildContentItems() {
        var rows = (inventory?.entries ?? []).map(ContentItem.init)
        let listed = Set(rows.map { $0.url.standardizedFileURL })
        for url in audioFiles where !listed.contains(url.standardizedFileURL) {
            rows.append(
                ContentItem(
                    url: url,
                    name: url.lastPathComponent,
                    kindLabel: url.pathExtension.lowercased(),
                    fileSize: 0,
                    isAudio: true,
                    isDirectory: false,
                    isImage: false
                )
            )
        }
        contentItems = rows
    }

    private func reloadKeepingStatus(preferring id: URL? = nil) {
        let previous = status
        reload(preferring: id)
        status = previous
    }

    /// Match by standardized path so a rename (old URL → new URL) still finds
    /// the same pile after a rescan, and trailing-slash / symlink forms agree.
    private func pile(matching id: URL) -> Pile? {
        let target = id.standardizedFileURL
        return visiblePiles.first { $0.sourceURL.standardizedFileURL == target }
    }

    private func applyForm(for pile: Pile) {
        if pile.kind == .looseFiles {
            dateText = ProjectName.yymmdd(from: pile.oldestFileDate)
            descriptionText = ""
            bpmText = ""
            return
        }
        if let parsed = ProjectName.parse(pile.displayName) {
            dateText = parsed.yymmdd
            descriptionText = parsed.description
            bpmText = parsed.bpm.map { $0 == 0 ? "000" : String($0) } ?? ""
            return
        }
        dateText = ProjectName.defaultDate(fromDisplayName: pile.displayName, oldest: pile.oldestFileDate)
        descriptionText = suggestedDescription(for: pile.displayName)
        bpmText = ""
    }

    private func clearForm() {
        dateText = ""
        descriptionText = ""
        bpmText = ""
    }

    private func suggestedDescription(for displayName: String) -> String {
        var value = displayName
        if let range = value.range(of: #"^\d{6}[_-]"#, options: .regularExpression) {
            value.removeSubrange(range)
        }
        value = value.replacingOccurrences(of: ".logicx", with: "", options: [.caseInsensitive])
        if UnnamedDetector.isUnnamed(value) { return "" }
        return ProjectName.sanitize(value)
    }
}
