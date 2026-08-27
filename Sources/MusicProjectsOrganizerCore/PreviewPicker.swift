import Foundation

public struct PreviewPicker: Sendable {
    public init() {}

    public func previewFile(in root: URL, recursive: Bool = true) throws -> URL? {
        let files = try audioFiles(in: root, recursive: recursive)
        guard !files.isEmpty else { return nil }

        if let mix = files.first(where: { $0.lastPathComponent.uppercased().hasPrefix("MIXST") }) {
            return mix
        }

        let bounces = files.filter { isInsideBounces($0, root: root) }
        if let bounce = largest(bounces) {
            return bounce
        }

        if let smart = files.first(where: {
            $0.lastPathComponent.lowercased().hasPrefix("smart tempo multitrack set")
        }) {
            return smart
        }

        return largest(files)
    }

    public func audioFiles(in root: URL, recursive: Bool = true) throws -> [URL] {
        if !recursive {
            return try immediateAudio(in: root)
        }
        return try FileWalk.regularFiles(
            in: root,
            resourceKeys: [.isRegularFileKey, .fileSizeKey],
            maxFiles: 2_000
        ) { url, values in
            values.isRegularFile == true && MediaTypes.isAudio(url)
        }
    }

    private func immediateAudio(in root: URL) throws -> [URL] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory) else { return [] }
        if !isDirectory.boolValue {
            return MediaTypes.isAudio(root) ? [root] : []
        }
        let urls = try fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        return urls.filter { MediaTypes.isAudio($0) }
    }

    private func isInsideBounces(_ url: URL, root: URL) -> Bool {
        let rootParts = root.standardizedFileURL.pathComponents
        let parts = url.standardizedFileURL.deletingLastPathComponent().pathComponents
        guard parts.count >= rootParts.count else { return false }
        return parts.dropFirst(rootParts.count).contains { $0.caseInsensitiveCompare("Bounces") == .orderedSame }
    }

    private func largest(_ urls: [URL]) -> URL? {
        urls.max { lhs, rhs in
            (fileSize(lhs) ?? 0) < (fileSize(rhs) ?? 0)
        }
    }

    private func fileSize(_ url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }
}
