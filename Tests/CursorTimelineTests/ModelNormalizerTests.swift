import CursorTimelineCore
import XCTest

final class ModelNormalizerTests: XCTestCase {
    func testOpusModel() {
        XCTAssertEqual(ModelNormalizer.normalize("claude-4.6-opus-high"), .opus)
    }

    func testSonnetModel() {
        XCTAssertEqual(ModelNormalizer.normalize("claude-4-sonnet"), .sonnet)
    }

    func testComposerModel() {
        XCTAssertEqual(ModelNormalizer.normalize("composer-1"), .composer)
    }

    func testGPTModel() {
        XCTAssertEqual(ModelNormalizer.normalize("gpt-5.5-high"), .gpt)
    }

    func testUnknownModel() {
        XCTAssertEqual(ModelNormalizer.normalize(nil), .other)
    }
}
