import XCTest
@testable import Bookkeeping

final class CategoryIconTests: XCTestCase {

    func testRecognizesKeyboardEmojiGlyphs() {
        XCTAssertTrue("🍜".containsEmojiGlyph)
        XCTAssertTrue("❤️".containsEmojiGlyph)
    }

    func testDoesNotTreatSFSymbolNameAsEmoji() {
        XCTAssertFalse("fork.knife".containsEmojiGlyph)
    }
}
