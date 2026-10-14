import XCTest
@testable import Codenotch

final class GaugeProjectsStoreTests: XCTestCase {
    private var tempStoreURL: URL!

    override func setUpWithError() throws {
        tempStoreURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaugeProjectsStoreTests-\(UUID().uuidString)")
            .appendingPathComponent("projects.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempStoreURL.deletingLastPathComponent())
    }

    func testRoundTripsEntries() {
        let store = GaugeProjectsStore(storeURL: tempStoreURL)
        let entry = GaugeProjectEntry(path: URL(fileURLWithPath: "/tmp/project"))
        XCTAssertTrue(store.save([entry]))
        XCTAssertEqual(store.load(), [entry])
    }

    func testAddDeduplicatesByCanonicalPath() {
        let store = GaugeProjectsStore(storeURL: tempStoreURL)
        let a = GaugeProjectEntry(path: URL(fileURLWithPath: "/tmp/project"))
        let b = GaugeProjectEntry(path: URL(fileURLWithPath: "/tmp/project/"))
        var list = store.add(a, to: [])
        list = store.add(b, to: list)
        XCTAssertEqual(list.count, 1)
    }

    func testRemoveStripsByID() {
        let store = GaugeProjectsStore(storeURL: tempStoreURL)
        let a = GaugeProjectEntry(path: URL(fileURLWithPath: "/tmp/a"))
        let b = GaugeProjectEntry(path: URL(fileURLWithPath: "/tmp/b"))
        let list = store.remove(id: a.id, from: [a, b])
        XCTAssertEqual(list, [b])
    }

    func testLoadReturnsEmptyWhenFileMissing() {
        let store = GaugeProjectsStore(storeURL: tempStoreURL)
        XCTAssertTrue(store.load().isEmpty)
    }
}
