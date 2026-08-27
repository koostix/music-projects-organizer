import XCTest
@testable import MusicProjectsOrganizerCore

final class InboxServiceTests: XCTestCase {
    private var tempRoot: URL!
    private var workbench: Workbench!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MusicProjectsOrganizer-service-\(UUID().uuidString)", isDirectory: true)
        workbench = Workbench(
            root: tempRoot.appendingPathComponent("_Music Projects", isDirectory: true),
            logicProjects: tempRoot.appendingPathComponent("Logic", isDirectory: true)
        )
        try FileManager.default.createDirectory(at: workbench.inbox, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workbench.start, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testLoadPreviewAndFilePileEndToEnd() throws {
        let source = workbench.inbox.appendingPathComponent("session-drop", isDirectory: true)
        try writeFile(at: source.appendingPathComponent("MIXST001.WAV"), contents: Data(repeating: 0x61, count: 10))
        try writeFile(at: source.appendingPathComponent("stem.wav"), contents: Data(repeating: 0x61, count: 100))

        let service = InboxService(workbench: workbench)
        let piles = try service.loadPiles()
        XCTAssertEqual(piles.count, 1)
        XCTAssertEqual(piles[0].displayName, "session-drop")
        XCTAssertEqual(try service.previewURL(for: piles[0])?.lastPathComponent, "MIXST001.WAV")

        let result = try service.file(
            piles[0],
            name: ProjectName(yymmdd: "260323", description: "toy piano", bpm: 92)
        )

        XCTAssertTrue(result.didMove)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: workbench.start.appendingPathComponent("260323_toy piano_92/MIXST001.WAV").path
        ))
        XCTAssertTrue(try service.loadPiles().isEmpty)
    }

    func testScanInspectAndRenameAnArbitraryFolder() throws {
        let dump = tempRoot.appendingPathComponent("Session1232", isDirectory: true)
        try writeFile(at: dump.appendingPathComponent("TapeLooper-A.wav"), contents: Data(repeating: 0x61, count: 12))
        try writeFile(at: dump.appendingPathComponent("TapeLooper-B.wav"), contents: Data(repeating: 0x61, count: 8))

        let service = InboxService(workbench: workbench)
        let piles = try service.loadPiles(in: dump)
        XCTAssertEqual(piles.count, 1)
        XCTAssertEqual(piles[0].displayName, "Session1232")

        let inventory = try service.inspect(piles[0])
        XCTAssertEqual(inventory.entries.map(\.name), ["TapeLooper-A.wav", "TapeLooper-B.wav"])
        XCTAssertEqual(try service.audioFiles(in: piles[0]).count, 2)

        let result = try service.file(
            piles[0],
            name: ProjectName(yymmdd: "260510", description: "tape looper", bpm: 92)
        )
        XCTAssertTrue(result.didMove)
        XCTAssertEqual(result.destination.lastPathComponent, "260510_tape looper_92")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.destination.appendingPathComponent("TapeLooper-A.wav").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dump.path))
    }

    func testWrapsLooseFilesInAnOpenedContainer() throws {
        let container = tempRoot.appendingPathComponent("dumps", isDirectory: true)
        try writeFile(at: container.appendingPathComponent("keep/mix.wav"), contents: Data("keep".utf8))
        try writeFile(at: container.appendingPathComponent("orphan.wav"), contents: Data("loose".utf8))

        let service = InboxService(workbench: workbench)
        let piles = try service.loadPiles(in: container)
        let loose = try XCTUnwrap(piles.first(where: { $0.kind == .looseFiles }))

        let result = try service.file(
            loose,
            name: ProjectName(yymmdd: "260510", description: "orphan take", bpm: 100)
        )
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: container.appendingPathComponent("260510_orphan take_100/orphan.wav").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(atPath: container.appendingPathComponent("keep/mix.wav").path))
        XCTAssertEqual(result.destination.lastPathComponent, "260510_orphan take_100")
    }

    func testAutoRenameStripsSpacesFromATitledFolder() throws {
        let titled = workbench.start.appendingPathComponent("260323_underwater guitar_92", isDirectory: true)
        try writeFile(at: titled.appendingPathComponent("mix.wav"), contents: Data("a".utf8))
        let service = InboxService(workbench: workbench)
        let pile = Pile(
            sourceURL: titled,
            origin: .start,
            displayName: "260323_underwater guitar_92",
            fileCount: 1,
            oldestFileDate: Date(),
            isUnnamed: false
        )

        let result = try service.autoRename(pile)

        XCTAssertTrue(result.didMove)
        XCTAssertEqual(result.destination.lastPathComponent, "260323_UnderwaterGuitar_92")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.destination.appendingPathComponent("mix.wav").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: titled.path))
    }

    func testAutoRenameKeepsTappedTempoWhenNameHadNone() throws {
        let titled = workbench.start.appendingPathComponent("260323_underwater guitar", isDirectory: true)
        try writeFile(at: titled.appendingPathComponent("mix.wav"), contents: Data("a".utf8))
        let service = InboxService(workbench: workbench)
        let pile = Pile(
            sourceURL: titled,
            origin: .start,
            displayName: "260323_underwater guitar",
            fileCount: 1,
            oldestFileDate: Date(),
            isUnnamed: false
        )

        let result = try service.autoRename(pile, bpm: 92)

        XCTAssertTrue(result.didMove)
        XCTAssertEqual(result.destination.lastPathComponent, "260323_UnderwaterGuitar_92")
    }

    func testAutoRenameRefusesUnnamedFolders() throws {
        let pile = Pile(
            sourceURL: workbench.start.appendingPathComponent("Untitled", isDirectory: true),
            origin: .start,
            displayName: "Untitled",
            fileCount: 0,
            oldestFileDate: Date()
        )
        XCTAssertThrowsError(try InboxService(workbench: workbench).autoRename(pile)) { error in
            guard case InboxServiceError.cannotAutoRename = error else {
                return XCTFail("expected cannotAutoRename, got \(error)")
            }
        }
    }

    func testEnsureInboxCreatesTheDropFolder() throws {
        try FileManager.default.removeItem(at: workbench.inbox)
        let service = InboxService(workbench: workbench)
        try service.ensureInbox()
        XCTAssertTrue(FileManager.default.fileExists(atPath: workbench.inbox.path))
    }

    private func writeFile(at url: URL, contents: Data) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url)
    }
}
