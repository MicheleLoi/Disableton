import XCTest
@testable import GrooveCore

final class SupportTests: XCTestCase {
    func testVersionParsingAndOrder() {
        XCTAssertEqual(AppVersion(string: "v0.1.12")?.description, "0.1.12")
        XCTAssertNil(AppVersion(string: "ultima"))
        XCTAssertLessThan(AppVersion(string: "0.1.9")!, AppVersion(string: "0.1.10")!)
        XCTAssertLessThan(AppVersion(string: "0.1")!, AppVersion(string: "0.1.1")!)
        XCTAssertEqual(AppVersion(string: "0.1.0")!, AppVersion(string: "0.1")!)
    }

    func testReleaseParsing() throws {
        let json = """
        {"tag_name":"v0.1.7","name":"Disableton 0.1.7","body":"Novità","html_url":"https://github.com/MicheleLoi/Disableton/releases/tag/v0.1.7",
         "assets":[{"name":"disableton-cli.zip","browser_download_url":"https://github.com/MicheleLoi/Disableton/releases/download/v0.1.7/disableton-cli.zip"},
                   {"name":"Disableton.zip","browser_download_url":"https://github.com/MicheleLoi/Disableton/releases/download/v0.1.7/Disableton.zip"}]}
        """
        let release = try XCTUnwrap(ReleaseInfo.parse(Data(json.utf8)))
        XCTAssertEqual(release.version, AppVersion([0, 1, 7]))
        XCTAssertEqual(release.appZipURL.lastPathComponent, "Disableton.zip")
        XCTAssertEqual(release.notes, "Novità")
    }

    func testReleaseRejectsForeignHosts() {
        let json = """
        {"tag_name":"v0.1.7","assets":[{"name":"Disableton.zip","browser_download_url":"https://example.com/Disableton.zip"}]}
        """
        XCTAssertNil(ReleaseInfo.parse(Data(json.utf8)))
        XCTAssertNil(ReleaseInfo.parse(Data("{\"tag_name\":\"v1\"}".utf8)))
    }

    func testEventLogKeepsRecentLinesAndWritesFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let log = EventLog(fileURL: dir.appendingPathComponent("test.log"), maxRecent: 3, maxFileBytes: 200)
        for i in 1...10 { log.log("evento \(i)") }
        XCTAssertEqual(log.recentLines.count, 3)
        XCTAssertTrue(log.recentLines.last!.hasSuffix("evento 10"))
        let text = try String(contentsOf: dir.appendingPathComponent("test.log"), encoding: .utf8)
        XCTAssertTrue(text.contains("evento 10"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("test.log.1").path))
    }

    func testReportAnonymizesHome() {
        var report = DiagnosticReport()
        report.add("Libreria", ["Cartella: /Users/mario/Library/Application Support/Disableton"])
        let text = report.text(homeDirectory: "/Users/mario")
        XCTAssertTrue(text.contains("~/Library/Application Support/Disableton"))
        XCTAssertFalse(text.contains("mario"))
    }

    func testIssueLinkStaysShort() {
        let body = (1...2000).map { "riga di registro numero \($0)" }.joined(separator: "\n")
        let url = IssueLink.url(title: "Problema", body: body)
        XCTAssertLessThanOrEqual(url.absoluteString.count, 7_500)
        XCTAssertTrue(url.absoluteString.hasPrefix("https://github.com/MicheleLoi/Disableton/issues/new?"))
        let short = IssueLink.url(title: "Titolo", body: "breve")
        XCTAssertTrue(short.absoluteString.contains("breve"))
    }

    func testCrashReportsFinder() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let before = Date().addingTimeInterval(-60)
        try "crash".write(to: dir.appendingPathComponent("Disableton-2026-11-25-101010.ips"), atomically: true, encoding: .utf8)
        try "altro".write(to: dir.appendingPathComponent("Safari-2026-11-25-101010.ips"), atomically: true, encoding: .utf8)
        try "testo".write(to: dir.appendingPathComponent("Disableton-note.txt"), atomically: true, encoding: .utf8)
        let found = CrashReports.find(in: dir, newerThan: before)
        XCTAssertEqual(found.map { $0.lastPathComponent }, ["Disableton-2026-11-25-101010.ips"])
        XCTAssertTrue(CrashReports.find(in: dir, newerThan: Date().addingTimeInterval(60)).isEmpty)
        XCTAssertEqual(CrashReports.excerpt(of: found[0]), "crash")
    }
}
