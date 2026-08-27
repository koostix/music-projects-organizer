import Foundation

public struct InboxService {
    public let workbench: Workbench
    private let scanner: PileScanner
    private let directoryScanner: DirectoryScanner
    private let inspector: FolderInspector
    private let picker: PreviewPicker
    private let covers: CoverPicker
    private let resolver: DestinationResolver
    private let mover: PileMover
    private let wrapper: LooseFileWrapper

    public init(
        workbench: Workbench,
        mover: PileMover = PileMover(),
        wrapper: LooseFileWrapper = LooseFileWrapper()
    ) {
        self.workbench = workbench
        self.scanner = PileScanner()
        self.directoryScanner = DirectoryScanner()
        self.inspector = FolderInspector()
        self.picker = PreviewPicker()
        self.covers = CoverPicker()
        self.resolver = DestinationResolver()
        self.mover = mover
        self.wrapper = wrapper
    }

    public func ensureInbox() throws {
        try scanner.ensureInboxExists(workbench: workbench)
    }

    public func loadPiles(in directory: URL? = nil) throws -> [Pile] {
        let piles: [Pile]
        if let directory {
            piles = try directoryScanner.scan(directory)
        } else {
            piles = try scanner.scan(workbench: workbench)
        }
        return piles.sorted { lhs, rhs in
            lhs.sourceURL.path.localizedStandardCompare(rhs.sourceURL.path) == .orderedAscending
        }
    }

    public func inspect(_ pile: Pile) throws -> FolderInventory {
        try inspector.inspect(pile)
    }

    public func previewURL(for pile: Pile) throws -> URL? {
        try picker.previewFile(in: pile.sourceURL, recursive: pile.kind != .looseFiles)
    }

    public func coverURL(for pile: Pile) throws -> URL? {
        try covers.coverFile(in: pile.sourceURL, recursive: pile.kind != .looseFiles)
    }

    public func audioFiles(in pile: Pile) throws -> [URL] {
        if pile.kind == .looseFiles {
            return try inspector.inspect(pile).audioEntries.map(\.url)
        }
        return try picker.audioFiles(in: pile.sourceURL)
    }

    public func inspection(for pile: Pile) -> PileInspection {
        let inventory = try? inspect(pile)
        let audio = (try? audioFiles(in: pile)) ?? []
        let cover = try? coverURL(for: pile)
        let preview = (try? previewURL(for: pile)) ?? audio.first
        return PileInspection(
            inventory: inventory,
            audioFiles: audio,
            coverURL: cover,
            previewURL: preview
        )
    }

    public func proposedDestination(for pile: Pile, name: ProjectName, parent: URL? = nil) -> URL {
        resolver.destination(for: pile, name: name, workbench: workbench, parent: parent)
    }

    public func file(_ pile: Pile, name: ProjectName, into parent: URL? = nil) throws -> MoveResult {
        guard name.isValid else {
            throw InboxServiceError.invalidProjectName
        }
        let destination = resolver.destination(for: pile, name: name, workbench: workbench, parent: parent)
        if pile.kind == .looseFiles {
            return try wrapper.wrap(from: pile.sourceURL, to: destination)
        }
        return try mover.move(from: pile.sourceURL, to: destination)
    }

    public func autoRename(_ pile: Pile, bpm: Int? = nil) throws -> MoveResult {
        guard !pile.isUnnamed, pile.kind != .looseFiles else {
            throw InboxServiceError.cannotAutoRename
        }
        guard let folderName = ProjectName.removingSpaces(from: pile.displayName, bpm: bpm) else {
            throw InboxServiceError.cannotAutoRename
        }
        let destination = resolver.inPlaceDestination(for: pile, folderName: folderName)
        return try mover.move(from: pile.sourceURL, to: destination)
    }
}

public struct PileInspection: Sendable {
    public var inventory: FolderInventory?
    public var audioFiles: [URL]
    public var coverURL: URL?
    public var previewURL: URL?

    public init(
        inventory: FolderInventory?,
        audioFiles: [URL],
        coverURL: URL?,
        previewURL: URL?
    ) {
        self.inventory = inventory
        self.audioFiles = audioFiles
        self.coverURL = coverURL
        self.previewURL = previewURL
    }
}

public enum InboxServiceError: Error, Equatable, LocalizedError {
    case invalidProjectName
    case cannotAutoRename

    public var errorDescription: String? {
        switch self {
        case .invalidProjectName:
            return "Enter a description, a six-digit date, and a BPM from 20 to 300 — or 000 if there is no tempo."
        case .cannotAutoRename:
            return "Auto rename only works on a titled folder that still has spaces."
        }
    }
}
