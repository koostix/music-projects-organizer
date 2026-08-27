import XCTest
@testable import MusicProjectsOrganizerCore

final class PreviewPickerTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MusicProjectsOrganizer-preview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testPrefersMixStemOverLongerRawTake() throws {
        try write(name: "MIXST001.WAV", size: 10)
        try write(name: "EX000_56.WAV", size: 100)
        XCTAssertEqual(try PreviewPicker().previewFile(in: tempRoot)?.lastPathComponent, "MIXST001.WAV")
    }

    func testPrefersBounceOverLongerRawOutsideBounces() throws {
        try write(name: "Bounces/mix.aif", size: 20)
        try write(name: "EX000_1.WAV", size: 200)
        XCTAssertEqual(try PreviewPicker().previewFile(in: tempRoot)?.lastPathComponent, "mix.aif")
    }

    func testPrefersSmartTempoWhenNoMixOrBounce() throws {
        try write(name: "Smart Tempo Multitrack Set 1.aif", size: 30)
        try write(name: "stem.wav", size: 300)
        XCTAssertEqual(
            try PreviewPicker().previewFile(in: tempRoot)?.lastPathComponent,
            "Smart Tempo Multitrack Set 1.aif"
        )
    }

    func testFallsBackToLongestAudioFile() throws {
        try write(name: "short.mp3", size: 5)
        try write(name: "long.m4a", size: 50)
        XCTAssertEqual(try PreviewPicker().previewFile(in: tempRoot)?.lastPathComponent, "long.m4a")
    }

    func testAudioFilesListsEveryAudioFile() throws {
        try write(name: "short.mp3", size: 5)
        try write(name: "Bounces/mix.wav", size: 20)
        try write(name: "photo.heic", size: 500)
        let files = try PreviewPicker().audioFiles(in: tempRoot).map(\.lastPathComponent).sorted()
        XCTAssertEqual(files, ["mix.wav", "short.mp3"])
    }

    func testEmptyFolderReturnsNil() throws {
        XCTAssertNil(try PreviewPicker().previewFile(in: tempRoot))
    }

    func testIgnoresHeicAndMov() throws {
        try write(name: "photo.heic", size: 500)
        try write(name: "clip.mov", size: 500)
        try write(name: "take.wav", size: 8)
        XCTAssertEqual(try PreviewPicker().previewFile(in: tempRoot)?.lastPathComponent, "take.wav")
    }

    func testDoesNotWalkIntoNestedLogicPackage() throws {
        try write(name: "take.wav", size: 8)
        try write(name: "Untitled.logicx/Media/buried.wav", size: 400)
        let files = try PreviewPicker().audioFiles(in: tempRoot).map(\.lastPathComponent).sorted()
        XCTAssertEqual(files, ["take.wav"])
    }

    func testFindsAudioInsideALogicPackageWhenThatIsTheRoot() throws {
        try write(name: "Untitled.logicx/Bounces/mix.wav", size: 20)
        try write(name: "Untitled.logicx/Media/take.wav", size: 8)
        let root = tempRoot.appendingPathComponent("Untitled.logicx", isDirectory: true)
        let files = try PreviewPicker().audioFiles(in: root).map(\.lastPathComponent).sorted()
        XCTAssertEqual(files, ["mix.wav", "take.wav"])
    }

    func testNonRecursiveListsOnlyImmediateAudio() throws {
        try write(name: "root.wav", size: 8)
        try write(name: "Bounces/mix.wav", size: 20)
        let files = try PreviewPicker().audioFiles(in: tempRoot, recursive: false).map(\.lastPathComponent)
        XCTAssertEqual(files, ["root.wav"])
    }

    private func write(name: String, size: Int) throws {
        let url = tempRoot.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x61, count: size).write(to: url)
    }
}
