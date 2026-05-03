import XCTest
@testable import MediaSizeWatchdog

final class MediaSizeWatchdogTests: XCTestCase {
    private final class NoOpLogger: MediaSizeLogger {
        func log(_ message: String) {}
    }

    func testReportsOversizedImageByMimeType() {
        let store = MediaSizeIssueStore()
        let watchdog = MediaSizeWatchdog(issueStore: store, logger: NoOpLogger())

        watchdog.report(
            url: URL(string: "https://example.com/avatar")!,
            size: 701 * 1024,
            mimeType: "image/jpeg",
            source: .custom
        )

        XCTAssertEqual(store.issues.count, 1)
        XCTAssertEqual(store.issues.first?.mediaType, .image)
        XCTAssertEqual(store.issues.first?.threshold, 500 * 1024)
    }

    func testReportsOversizedVideoByExtension() {
        let store = MediaSizeIssueStore()
        let watchdog = MediaSizeWatchdog(
            issueStore: store,
            logger: NoOpLogger()
        )

        watchdog.start(
            config: MediaSizeWatchdogConfig(
                imageThreshold: 10,
                videoThreshold: 100
            ),
            adapters: []
        )

        watchdog.report(
            url: URL(string: "https://example.com/video.mp4")!,
            size: 101,
            mimeType: nil,
            source: .custom
        )

        XCTAssertEqual(store.issues.count, 1)
        XCTAssertEqual(store.issues.first?.mediaType, .video)
    }

    func testIgnoresUnknownMedia() {
        let store = MediaSizeIssueStore()
        let watchdog = MediaSizeWatchdog(issueStore: store, logger: NoOpLogger())

        watchdog.report(
            url: URL(string: "https://example.com/document.txt")!,
            size: 10_000_000,
            mimeType: "text/plain",
            source: .custom
        )

        XCTAssertTrue(store.issues.isEmpty)
    }

    func testDeduplicatesByURL() {
        let store = MediaSizeIssueStore()
        let watchdog = MediaSizeWatchdog(
            issueStore: store,
            logger: NoOpLogger()
        )
        let url = URL(string: "https://example.com/image.png")!

        watchdog.report(url: url, size: 600 * 1024, mimeType: nil, source: .custom)
        watchdog.report(url: url, size: 700 * 1024, mimeType: nil, source: .custom)

        XCTAssertEqual(store.issues.count, 1)
    }
}
