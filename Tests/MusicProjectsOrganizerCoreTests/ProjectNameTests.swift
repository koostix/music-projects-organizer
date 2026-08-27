import XCTest
@testable import MusicProjectsOrganizerCore

final class ProjectNameTests: XCTestCase {
    func testFolderNameKeepsSpacesInDescription() {
        let name = ProjectName(yymmdd: "260323", description: "underwater guitar", bpm: 92)
        XCTAssertEqual(name.folderName, "260323_underwater guitar_92")
        XCTAssertTrue(name.isValid)
    }

    func testSlashBecomesSpaceAndCollapses() {
        let name = ProjectName(yymmdd: "260323", description: "toy / piano", bpm: 80)
        XCTAssertEqual(name.folderName, "260323_toy piano_80")
        XCTAssertTrue(name.isValid)
    }

    func testRemovesColonBackslashAndNarrowNoBreakSpace() {
        let narrow = "\u{202F}"
        let name = ProjectName(
            yymmdd: "260318",
            description: "Feb 18: night\(narrow)session\\take",
            bpm: 88
        )
        XCTAssertEqual(name.folderName, "260318_Feb 18 night session take_88")
    }

    func testEmptyDescriptionIsInvalid() {
        XCTAssertFalse(ProjectName(yymmdd: "260323", description: "   ", bpm: 92).isValid)
        XCTAssertFalse(ProjectName(yymmdd: "260323", description: "/", bpm: 92).isValid)
    }

    func testBpmBounds() {
        XCTAssertFalse(ProjectName(yymmdd: "260323", description: "toy", bpm: 19).isValid)
        XCTAssertFalse(ProjectName(yymmdd: "260323", description: "toy", bpm: 301).isValid)
        XCTAssertTrue(ProjectName(yymmdd: "260323", description: "toy", bpm: 20).isValid)
        XCTAssertTrue(ProjectName(yymmdd: "260323", description: "toy", bpm: 300).isValid)
        XCTAssertTrue(ProjectName(yymmdd: "260323", description: "toy", bpm: 0).isValid)
    }

    func testRemovingSpacesFromTitledFolder() {
        XCTAssertEqual(ProjectName.pascalCaseWords("underwater guitar"), "UnderwaterGuitar")
        XCTAssertEqual(
            ProjectName.removingSpaces(from: "260323_underwater guitar_92"),
            "260323_UnderwaterGuitar_92"
        )
        XCTAssertEqual(
            ProjectName.removingSpaces(from: "20250828 Session - MaryLuFlute-Mix"),
            "20250828Session-MaryLuFlute-Mix"
        )
        XCTAssertEqual(
            ProjectName.removingSpaces(from: "Chill Song.logicx"),
            "ChillSong.logicx"
        )
        XCTAssertNil(ProjectName.removingSpaces(from: "260323_toypiano_92"))
        XCTAssertNil(ProjectName.removingSpaces(from: "   "))
        XCTAssertEqual(
            ProjectName.removingSpaces(from: "260323_underwater guitar", bpm: 92),
            "260323_UnderwaterGuitar_92"
        )
        XCTAssertEqual(
            ProjectName.removingSpaces(from: "260323_underwater guitar_80", bpm: 92),
            "260323_UnderwaterGuitar_92"
        )
        XCTAssertEqual(
            ProjectName.removingSpaces(from: "260323_ToyPiano", bpm: 92),
            "260323_ToyPiano_92"
        )
        XCTAssertEqual(
            ProjectName.removingSpaces(from: "Chill Song", bpm: 0),
            "ChillSong_000"
        )
    }

    func testZeroBpmRendersAs000() {
        let name = ProjectName(yymmdd: "260323", description: "drone wash", bpm: 0)
        XCTAssertEqual(name.folderName, "260323_drone wash_000")
        XCTAssertEqual(name.bpmLabel, "000")
    }

    func testParseReads000AsNoTempo() {
        let parsed = ProjectName.parse("260323_drone wash_000")
        XCTAssertEqual(parsed?.yymmdd, "260323")
        XCTAssertEqual(parsed?.description, "drone wash")
        XCTAssertEqual(parsed?.bpm, 0)
    }

    func testYymmddFromDateUsesInjectedCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let components = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 3, day: 23)
        let date = components.date!
        XCTAssertEqual(ProjectName.yymmdd(from: date, calendar: calendar), "260323")
    }

    func testDefaultDatePrefersExistingLeadingYymmdd() {
        let oldest = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(
            ProjectName.defaultDate(fromDisplayName: "260320_UNNAMED-02", oldest: oldest),
            "260320"
        )
    }

    func testParseReadsDateDescriptionAndBpm() {
        let parsed = ProjectName.parse("260323_underwater guitar_92")
        XCTAssertEqual(parsed?.yymmdd, "260323")
        XCTAssertEqual(parsed?.description, "underwater guitar")
        XCTAssertEqual(parsed?.bpm, 92)
    }

    func testParseDropsUnnamedDescription() {
        let parsed = ProjectName.parse("260320_UNNAMED-02")
        XCTAssertEqual(parsed?.yymmdd, "260320")
        XCTAssertEqual(parsed?.description, "")
        XCTAssertNil(parsed?.bpm)
    }

    func testParseIgnoresLogicSuffix() {
        let parsed = ProjectName.parse("260218_toy piano_88.logicx")
        XCTAssertEqual(parsed?.yymmdd, "260218")
        XCTAssertEqual(parsed?.description, "toy piano")
        XCTAssertEqual(parsed?.bpm, 88)
    }

    func testParseReturnsNilWhenNameHasNoDatePrefix() {
        XCTAssertNil(ProjectName.parse("Untitled 5.logicx"))
        XCTAssertNil(ProjectName.parse("session-drop"))
    }

    func testNamingSchemeRequiresDateNameAndTempo() {
        XCTAssertTrue(ProjectName.matchesNamingScheme("260323_underwater guitar_92"))
        XCTAssertTrue(ProjectName.matchesNamingScheme("260323_drone wash_000"))
        XCTAssertTrue(ProjectName.matchesNamingScheme("260218_toy piano_88.logicx"))
        XCTAssertFalse(ProjectName.matchesNamingScheme("260323_underwater guitar"))
        XCTAssertFalse(ProjectName.matchesNamingScheme("260320_UNNAMED-02"))
        XCTAssertFalse(ProjectName.matchesNamingScheme("Untitled 5.logicx"))
        XCTAssertFalse(ProjectName.matchesNamingScheme("20250828 Session - MaryLuFlute-Mix"))
        XCTAssertFalse(ProjectName.matchesNamingScheme("Chill Song"))
    }

    func testDefaultDateFallsBackToOldestWhenNameHasNoDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let components = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 2, day: 18)
        let oldest = components.date!
        XCTAssertEqual(
            ProjectName.defaultDate(fromDisplayName: "Untitled 5.logicx", oldest: oldest, calendar: calendar),
            "260218"
        )
    }
}
