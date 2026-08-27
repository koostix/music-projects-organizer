import Foundation

public struct CoverPicker: Sendable {
    private static let preferredNames = ["cover", "folder", "artwork", "album", "front", "art"]

    public init() {}

    public func coverFile(in root: URL, recursive: Bool = true) throws -> URL? {
        let files = try imageFiles(in: root, recursive: recursive)
        guard !files.isEmpty else { return nil }

        if let named = files.first(where: { isPreferredName($0) }) {
            return named
        }
        return files.max { lhs, rhs in
            (fileSize(lhs) ?? 0) < (fileSize(rhs) ?? 0)
        }
    }

    public func imageFiles(in root: URL, recursive: Bool = true) throws -> [URL] {
        if !recursive {
            return try immediateImages(in: root)
        }
        return try FileWalk.regularFiles(
            in: root,
            resourceKeys: [.isRegularFileKey, .fileSizeKey],
            maxFiles: 80
        ) { url, values in
            values.isRegularFile == true && MediaTypes.isImage(url)
        }
    }

    private func immediateImages(in root: URL) throws -> [URL] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory) else { return [] }
        if !isDirectory.boolValue {
            return MediaTypes.isImage(root) ? [root] : []
        }
        let urls = try fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        return urls.filter { MediaTypes.isImage($0) }
    }

    private func isPreferredName(_ url: URL) -> Bool {
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        return Self.preferredNames.contains { name.contains($0) }
    }

    private func fileSize(_ url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }
}
