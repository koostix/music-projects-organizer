import Foundation

enum FileWalk {
    static let nestedPackageExtensions: Set<String> = [
        "logicx", "app", "bundle", "framework", "plugin", "component", "appex", "photoslibrary",
    ]

    static func isNestedPackage(_ url: URL) -> Bool {
        nestedPackageExtensions.contains(url.pathExtension.lowercased())
    }

    static func regularFiles(
        in root: URL,
        resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
        maxFiles: Int,
        matching: (URL, URLResourceValues) throws -> Bool
    ) throws -> [URL] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory) else { return [] }

        if !isDirectory.boolValue {
            let values = try root.resourceValues(forKeys: Set(resourceKeys + [.isRegularFileKey]))
            return try matching(root, values) ? [root] : []
        }

        var results: [URL] = []
        let keys = Array(Set(resourceKeys + [.isRegularFileKey, .isDirectoryKey]))
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == ".DS_Store" { continue }
            if isNestedPackage(fileURL) {
                enumerator.skipDescendants()
                continue
            }
            let values = try fileURL.resourceValues(forKeys: Set(keys))
            guard try matching(fileURL, values) else { continue }
            results.append(fileURL)
            if results.count >= maxFiles { break }
        }
        return results
    }
}
