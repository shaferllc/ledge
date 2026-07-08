import XCTest
@testable import Ledge

final class ModuleTests: XCTestCase {
    func testEveryModuleHasMetadata() {
        for module in Module.allCases {
            XCTAssertFalse(module.title.isEmpty, "\(module) missing title")
            XCTAssertFalse(module.symbol.isEmpty, "\(module) missing symbol")
            XCTAssertFalse(module.blurb.isEmpty, "\(module) missing blurb")
        }
    }

    func testModuleIdsAreUnique() {
        let ids = Module.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "module ids must be unique")
    }

    func testModuleCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(Module.nowPlaying)
        let decoded = try JSONDecoder().decode(Module.self, from: data)
        XCTAssertEqual(decoded, .nowPlaying)
    }

    func testPanelSizeDimensions() {
        XCTAssertLessThan(PanelSize.small.width, PanelSize.medium.width)
        XCTAssertLessThan(PanelSize.medium.width, PanelSize.large.width)
        XCTAssertLessThan(PanelSize.small.moduleHeight, PanelSize.large.moduleHeight)
        for size in PanelSize.allCases {
            XCTAssertGreaterThan(size.width, 0)
            XCTAssertGreaterThan(size.moduleHeight, 0)
        }
    }
}
