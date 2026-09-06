import XCTest
@testable import Bookkeeping

final class BudgetServiceTests: XCTestCase {

    func testPermanentBudgetTakesPriorityOverLegacyMonthlyBudgets() {
        let legacy = Budget(month: "2026-08", amount: 3_000, isPermanent: false)
        let permanent = Budget(amount: 5_000)

        XCTAssertTrue(BudgetService.permanentBudget(from: [legacy, permanent]) === permanent)
    }

    func testNewestLegacyBudgetIsUsedConsistentlyBeforeMigration() {
        let older = Budget(month: "2026-07", amount: 3_000, isPermanent: false)
        let newer = Budget(month: "2026-08", amount: 5_000, isPermanent: false)

        XCTAssertTrue(
            BudgetService.permanentBudget(from: [older, newer]) === newer
        )
    }
}
