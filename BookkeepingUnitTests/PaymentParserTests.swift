import XCTest
@testable import Bookkeeping

final class PaymentParserTests: XCTestCase {

    func testExtractsTimeWithNumericDate() throws {
        let date = try XCTUnwrap(PaymentParser.parse("交易时间 2026-08-09 07:05").date)

        assertDate(date, year: 2026, month: 8, day: 9, hour: 7, minute: 5, second: 0)
    }

    func testExtractsTimeWithChineseDateAndTime() throws {
        let date = try XCTUnwrap(PaymentParser.parse("支付时间：2026年8月9日 18时07分").date)

        assertDate(date, year: 2026, month: 8, day: 9, hour: 18, minute: 7, second: 0)
    }

    func testExtractsTimeWhenOCRReturnsTimeBeforeDate() throws {
        let date = try XCTUnwrap(PaymentParser.parse("交易时间 18:07\n2026年8月9日").date)

        assertDate(date, year: 2026, month: 8, day: 9, hour: 18, minute: 7, second: 0)
    }

    func testExtractsTimeWithFullWidthColonAndSeconds() throws {
        let date = try XCTUnwrap(PaymentParser.parse("2026/08/09 12：34：56 付款成功").date)

        assertDate(date, year: 2026, month: 8, day: 9, hour: 12, minute: 34, second: 56)
    }

    func testPrefersSignedTransactionAmountOverBalance() {
        let result = PaymentParser.parse("""
        交易详情
        西安城市通发展有限责任公司
        - ¥100.00
        余额¥12,504.13
        交易时间 2026-09-03 21:57:44
        """)

        XCTAssertEqual(result.amount, Decimal(string: "100.00"))
        XCTAssertEqual(result.type, .expense)
    }

    func testPositiveAmountIsIncome() {
        let result = PaymentParser.parse("""
        转账详情
        +￥2,000.00
        账户余额 ￥12,504.13
        """)

        XCTAssertEqual(result.amount, Decimal(string: "2000.00"))
        XCTAssertEqual(result.type, .income)
    }

    private func assertDate(
        _ date: Date,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        XCTAssertEqual(components.year, year, file: file, line: line)
        XCTAssertEqual(components.month, month, file: file, line: line)
        XCTAssertEqual(components.day, day, file: file, line: line)
        XCTAssertEqual(components.hour, hour, file: file, line: line)
        XCTAssertEqual(components.minute, minute, file: file, line: line)
        XCTAssertEqual(components.second, second, file: file, line: line)
    }
}
