import Foundation

public struct PileScanner: Sendable {
    public init() {}

    public func ensureInboxExists(workbench: Workbench) throws {
        try FileManager.default.createDirectory(at: workbench.inbox, withIntermediateDirectories: true)
    }

    public func scan(workbench: Workbench) throws -> [Pile] {
        var piles: [Pile] = []
        piles += try children(of: workbench.inbox, origin: .inbox, unnamedOnly: false)
        piles += try children(of: workbench.start, origin: .start, unnamedOnly: true)
        piles += try children(of: workbench.revise, origin: .revise, unnamedOnly: true)
        piles += try children(of: workbench.logicProjects, origin: .logic, unnamedOnly: true, logicPackagesOnly: true)
        return piles
    }

    private func children(
        of directory: URL,
        origin: Origin,
        unnamedOnly: Bool,
        logicPackagesOnly: Bool = false
    ) throws -> [Pile] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let urls = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        var piles: [Pile] = []
        for url in urls {
            if url.lastPathComponent == ".DS_Store" { continue }
            if logicPackagesOnly && url.pathExtension.lowercased() != "logicx" { continue }
            if unnamedOnly && !UnnamedDetector.isUnnamed(url.lastPathComponent) { continue }

            let stats = MediaTypes.isLogicPackage(url)
                ? try FileStats.collect(at: url)
                : try FileStats.shallow(at: url)
            let kind: PileKind = MediaTypes.isLogicPackage(url) ? .logicPackage : .folder
            piles.append(
                Pile(
                    sourceURL: url,
                    origin: origin,
                    displayName: url.lastPathComponent,
                    fileCount: stats.count,
                    oldestFileDate: stats.oldest,
                    kind: kind,
                    byteSize: stats.bytes
                )
            )
        }
        return piles
    }
}
