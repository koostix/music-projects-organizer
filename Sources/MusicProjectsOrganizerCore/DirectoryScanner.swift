import Foundation

public struct DirectoryScanner: Sendable {
    public init() {}

    public func scan(_ directory: URL) throws -> [Pile] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let urls = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var folders: [URL] = []
        var looseFiles: [URL] = []
        for url in urls {
            if url.lastPathComponent == ".DS_Store" { continue }
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true || MediaTypes.isLogicPackage(url) {
                folders.append(url)
            } else if values.isRegularFile == true {
                looseFiles.append(url)
            }
        }

        if folders.isEmpty && !looseFiles.isEmpty {
            return [try makePile(at: directory, origin: .folder, kind: .folder)]
        }

        var piles: [Pile] = []
        if !looseFiles.isEmpty {
            piles.append(try makeLoosePile(in: directory, files: looseFiles))
        }
        for url in folders {
            let kind: PileKind = MediaTypes.isLogicPackage(url) ? .logicPackage : .folder
            piles.append(try makePile(at: url, origin: .folder, kind: kind))
        }
        return piles
    }

    private func makePile(at url: URL, origin: Origin, kind: PileKind) throws -> Pile {
        let stats = MediaTypes.isLogicPackage(url)
            ? try FileStats.collect(at: url)
            : try FileStats.shallow(at: url)
        return Pile(
            sourceURL: url,
            origin: origin,
            displayName: url.lastPathComponent,
            fileCount: stats.count,
            oldestFileDate: stats.oldest,
            kind: kind,
            byteSize: stats.bytes
        )
    }

    private func makeLoosePile(in directory: URL, files: [URL]) throws -> Pile {
        var count = 0
        var bytes: Int64 = 0
        var oldest: Date?
        for url in files {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            count += 1
            bytes += Int64(values.fileSize ?? 0)
            if let date = values.contentModificationDate {
                oldest = min(oldest ?? date, date)
            }
        }
        return Pile(
            sourceURL: directory,
            origin: .folder,
            displayName: "\(count) loose file\(count == 1 ? "" : "s")",
            fileCount: count,
            oldestFileDate: oldest ?? Date(),
            kind: .looseFiles,
            byteSize: bytes,
            isUnnamed: true
        )
    }
}
