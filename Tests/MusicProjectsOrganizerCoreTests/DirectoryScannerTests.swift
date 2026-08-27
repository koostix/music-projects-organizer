import XCTest
@testable import MusicProjectsOrganizerCore

final class DirectoryScannerTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MusicProjectsOrganizer-dirscan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testDumpWithOnlyAudioBecomesTheFolderItself() throws {
        try write(name: "TapeLooper-A.wav", size: 12)
        try write(name: "TapeLooper-B.wav", size: 8)

        let piles = try DirectoryScanner().scan(tempRoot)
        XCTAssertEqual(piles.count, 1)
        XCTAssertEqual(piles[0].sourceURL.standardizedFileURL, tempRoot.standardizedFileURL)
        XCTAssertEqual(piles[0].kind, .folder)
        XCTAssertEqual(piles[0].origin, .folder)
        XCTAssertEqual(piles[0].fileCount, 2)
        XCTAssertEqual(piles[0].byteSize, 20)
    }

    func testContainerListsChildFoldersAndNamedProjects() throws {
        try write(name: "Session1232/take.wav", size: 10)
        try write(name: "260323_underwater guitar_92/mix.wav", size: 20)
        try write(name: "Untitled 2.logicx/Resources/info.plist", size: 4)

        let piles = try DirectoryScanner().scan(tempRoot)
        let byName = Dictionary(uniqueKeysWithValues: piles.map { ($0.displayName, $0) })
        XCTAssertEqual(Set(piles.map(\.displayName)), [
            "Session1232",
            "260323_underwater guitar_92",
            "Untitled 2.logicx",
        ])
        XCTAssertEqual(byName["Untitled 2.logicx"]?.kind, .logicPackage)
        XCTAssertEqual(byName["260323_underwater guitar_92"]?.isUnnamed, false)
        XCTAssertEqual(byName["260323_underwater guitar_92"]?.needsNaming, false)
        XCTAssertEqual(byName["Session1232"]?.needsNaming, true)
        XCTAssertEqual(byName["Untitled 2.logicx"]?.needsNaming, true)
        XCTAssertEqual(byName["Session1232"]?.origin, .folder)
    }

    func testLooseFilesBesideFoldersBecomeAWrapPile() throws {
        try write(name: "session/take.wav", size: 10)
        try write(name: "orphan.wav", size: 6)
        try write(name: "note.txt", size: 2)

        let piles = try DirectoryScanner().scan(tempRoot)
        let loose = piles.first(where: { $0.kind == .looseFiles })
        XCTAssertEqual(piles.count, 2)
        XCTAssertEqual(loose?.displayName, "2 loose files")
        XCTAssertEqual(loose?.sourceURL.standardizedFileURL, tempRoot.standardizedFileURL)
        XCTAssertEqual(loose?.fileCount, 2)
        XCTAssertTrue(loose?.isUnnamed ?? false)
        XCTAssertTrue(loose?.needsNaming ?? false)
    }

    func testMissingDirectoryReturnsEmpty() throws {
        let missing = tempRoot.appendingPathComponent("gone", isDirectory: true)
        XCTAssertTrue(try DirectoryScanner().scan(missing).isEmpty)
    }

    private func write(name: String, size: Int) throws {
        let url = tempRoot.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x61, count: size).write(to: url)
    }
}
