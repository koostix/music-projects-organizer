import XCTest
@testable import MusicProjectsOrganizerCore

final class CoverPickerTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MusicProjectsOrganizer-cover-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testPrefersCoverNamedImageOverLargerSnapshot() throws {
        try write(name: "snapshot.png", size: 400)
        try write(name: "Cover.jpg", size: 40)
        XCTAssertEqual(try CoverPicker().coverFile(in: tempRoot)?.lastPathComponent, "Cover.jpg")
    }

    func testFallsBackToLargestImage() throws {
        try write(name: "small.png", size: 20)
        try write(name: "big.jpeg", size: 200)
        XCTAssertEqual(try CoverPicker().coverFile(in: tempRoot)?.lastPathComponent, "big.jpeg")
    }

    func testFindsNestedArtwork() throws {
        try write(name: "art/folder.png", size: 30)
        XCTAssertEqual(try CoverPicker().coverFile(in: tempRoot)?.lastPathComponent, "folder.png")
    }

    func testEmptyFolderReturnsNil() throws {
        try write(name: "take.wav", size: 10)
        XCTAssertNil(try CoverPicker().coverFile(in: tempRoot))
    }

    func testDoesNotWalkIntoNestedLogicPackage() throws {
        try write(name: "cover.jpg", size: 20)
        try write(name: "Untitled.logicx/Resources/buried.png", size: 400)
        XCTAssertEqual(try CoverPicker().coverFile(in: tempRoot)?.lastPathComponent, "cover.jpg")
        XCTAssertEqual(try CoverPicker().imageFiles(in: tempRoot).map(\.lastPathComponent), ["cover.jpg"])
    }

    private func write(name: String, size: Int) throws {
        let url = tempRoot.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x61, count: size).write(to: url)
    }
}
