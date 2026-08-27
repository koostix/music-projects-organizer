import Foundation

public enum FileStats {
    public static func collect(at root: URL) throws -> (count: Int, bytes: Int64, oldest: Date, newest: Date) {
        try summarize(
            files: FileWalk.regularFiles(
                in: root,
                resourceKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
                maxFiles: 8_000
            ) { _, values in
                values.isRegularFile == true
            },
            root: root
        )
    }

    /// Immediate children only. Used when listing a container so we don't walk a whole volume.
    public static func shallow(at root: URL) throws -> (count: Int, bytes: Int64, oldest: Date, newest: Date) {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
            let now = Date()
            return (0, 0, now, now)
        }

        if !isDirectory.boolValue {
            let values = try root.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let date = values.contentModificationDate ?? Date()
            return (1, Int64(values.fileSize ?? 0), date, date)
        }

        let urls = try fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []
        for url in urls {
            if url.lastPathComponent == ".DS_Store" { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(url)
            }
        }
        return try summarize(files: files, root: root)
    }

    private static func summarize(
        files: [URL],
        root: URL
    ) throws -> (count: Int, bytes: Int64, oldest: Date, newest: Date) {
        var count = 0
        var bytes: Int64 = 0
        var oldest: Date?
        var newest: Date?
        for fileURL in files {
            let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            count += 1
            bytes += Int64(values.fileSize ?? 0)
            if let date = values.contentModificationDate {
                oldest = min(oldest ?? date, date)
                newest = max(newest ?? date, date)
            }
        }

        if let oldest, let newest {
            return (count, bytes, oldest, newest)
        }
        let folderValues = try root.resourceValues(forKeys: [.contentModificationDateKey])
        let date = folderValues.contentModificationDate ?? Date()
        return (count, bytes, date, date)
    }
}
