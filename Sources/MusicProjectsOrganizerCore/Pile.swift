import Foundation

public enum Origin: String, Sendable, Equatable, Hashable {
    case inbox
    case start
    case revise
    case logic
    case folder
}

public enum PileKind: String, Sendable, Equatable, Hashable {
    case folder
    case logicPackage
    case looseFiles
}

public struct Pile: Equatable, Hashable, Identifiable, Sendable {
    public var id: URL { sourceURL }
    public var sourceURL: URL
    public var origin: Origin
    public var displayName: String
    public var fileCount: Int
    public var oldestFileDate: Date
    public var kind: PileKind
    public var byteSize: Int64
    public var isUnnamed: Bool

    public init(
        sourceURL: URL,
        origin: Origin,
        displayName: String,
        fileCount: Int,
        oldestFileDate: Date,
        kind: PileKind = .folder,
        byteSize: Int64 = 0,
        isUnnamed: Bool? = nil
    ) {
        self.sourceURL = sourceURL
        self.origin = origin
        self.displayName = displayName
        self.fileCount = fileCount
        self.oldestFileDate = oldestFileDate
        self.kind = kind
        self.byteSize = byteSize
        self.isUnnamed = isUnnamed ?? UnnamedDetector.isUnnamed(displayName)
    }

    /// Loose files, dumps, and folders that are not `YYMMDD_Name_BPM`.
    public var needsNaming: Bool {
        kind == .looseFiles || !ProjectName.matchesNamingScheme(displayName)
    }
}
