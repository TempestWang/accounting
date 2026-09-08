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

    func testPrefersActualPaymentOverListedForeignCurrencyPrice() {
        let result = PaymentParser.parse("""
        Valve
        -17.60
        标价 2.60美元
        汇率 1美元=6.745189人民币
        商品 Steam Purchase 1710000175914983
        商户全称 Valve Corporation
        """)

        XCTAssertEqual(result.amount, Decimal(string: "17.60"))
        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.merchant, "Valve Corporation")
        XCTAssertEqual(result.paymentInfo, "Steam Purchase 1710000175914983")
        let note = PaymentParser.composedNote(merchant: result.merchant, paymentInfo: result.paymentInfo)
        XCTAssertEqual(note, "Steam Purchase 1710000175914983")
    }

    func testExtractsLongMerchantAndProductDescription() {
        let result = PaymentParser.parse("""
        账单详情
        西安曲江新区运来湘味快餐店（个体工商户）
        -18.63
        支付时间 2026-09-07 12:04:02
        商品说明 湘外婆快餐(曲江店)订单
        收款方全称 西安曲江新区运来湘味快餐店（个体工商户）
        """)

        XCTAssertEqual(result.amount, Decimal(string: "18.63"))
        XCTAssertEqual(result.merchant, "西安曲江新区运来湘味快餐店（个体工商户）")
        XCTAssertEqual(result.paymentInfo, "湘外婆快餐(曲江店)订单")
    }

    func testExtractsValveProductFromVisionColumnOrder() {
        let result = PaymentParser.parse("""
        15:12
        X
        账单
        全部账单
        Valve
        -17.60
        标价
        汇率
        外语凭证
        2.60美元
        1美元=6.745189人民币
        付款凭证
        当前状态
        支付时间
        商品
        商户全称
        收单机构
        支付方式
        交易单号
        商户单号
        支付成功
        2026年9月6日 20:52:59
        Steam Purchase 1710000175914983
        Valve Corporation
        Nuvei Global Services B.V.
        招商银行信用卡（0929）
        4500000374202609068743669732
        S2P1108676428
        """)

        XCTAssertEqual(result.amount, Decimal(string: "17.60"))
        XCTAssertEqual(result.merchant, "Valve Corporation")
        XCTAssertEqual(result.paymentInfo, "Steam Purchase 1710000175914983")
        XCTAssertEqual(PaymentParser.composedNote(merchant: result.merchant, paymentInfo: result.paymentInfo), "Steam Purchase 1710000175914983")
    }

    func testExtractsWeChatProductDescriptionFromVisionColumnOrder() {
        let result = PaymentParser.parse("""
        15:13
        账单详情
        西安曲江新区运来湘味快餐店（个体工商户）
        支付时间
        付款方式
        商品说明
        支付奖励
        收单机构
        清算机构
        -18.63
        交易成功
        2026-09-07 12:04:02
        招商银行信用卡（0929）＞
        湘外婆快餐（曲江店）订单
        立即领取6积分
        广州合利宝支付科技有限公司
        中国银联股份有限公司
        收款方全称
        西安曲江新区运来湘味快餐店（个体工商户）
        """)

        XCTAssertEqual(result.amount, Decimal(string: "18.63"))
        XCTAssertEqual(result.merchant, "西安曲江新区运来湘味快餐店（个体工商户）")
        XCTAssertEqual(result.paymentInfo, "湘外婆快餐（曲江店）订单")
        XCTAssertEqual(PaymentParser.composedNote(merchant: result.merchant, paymentInfo: result.paymentInfo), "湘外婆快餐（曲江店）订单")
    }

    func testRebuildsVisualRowsBeforeParsingPaymentDetails() {
        let blocks = [
            OCRTextBlock(text: "支付时间", boundingBox: CGRect(x: 0.06, y: 0.64, width: 0.12, height: 0.02)),
            OCRTextBlock(text: "商品说明", boundingBox: CGRect(x: 0.06, y: 0.56, width: 0.13, height: 0.02)),
            OCRTextBlock(text: "收款方全称", boundingBox: CGRect(x: 0.06, y: 0.40, width: 0.16, height: 0.02)),
            OCRTextBlock(text: "2026-09-07 12:04:02", boundingBox: CGRect(x: 0.31, y: 0.64, width: 0.25, height: 0.02)),
            OCRTextBlock(text: "湘外婆快餐（曲江店）订单", boundingBox: CGRect(x: 0.31, y: 0.56, width: 0.32, height: 0.02)),
            OCRTextBlock(text: "西安曲江新区运来湘味快餐店（个体工", boundingBox: CGRect(x: 0.31, y: 0.40, width: 0.50, height: 0.02)),
            OCRTextBlock(text: "商户）", boundingBox: CGRect(x: 0.31, y: 0.37, width: 0.08, height: 0.02)),
        ]

        let text = OCRService.readingOrderText(from: blocks)

        XCTAssertEqual(text, """
        支付时间 2026-09-07 12:04:02
        商品说明 湘外婆快餐（曲江店）订单
        收款方全称 西安曲江新区运来湘味快餐店（个体工
        商户）
        """)
    }

    func testExtractsWrappedMerchantFromSpatialReadingOrder() {
        let result = PaymentParser.parse("""
        账单详情
        西安曲江新区运来湘味快餐店（个体工商户）
        -18.63
        交易成功
        支付时间 2026-09-07 12:04:02
        付款方式 招商银行信用卡（0929）＞
        商品说明 湘外婆快餐（曲江店）订单
        收款方全称 西安曲江新区运来湘味快餐店（个体工
        商户）
        账单管理 已解锁“吃顿饭”贴纸，去兑换好礼
        """)

        XCTAssertEqual(result.amount, Decimal(string: "18.63"))
        XCTAssertEqual(result.merchant, "西安曲江新区运来湘味快餐店（个体工商户）")
        XCTAssertEqual(result.paymentInfo, "湘外婆快餐（曲江店）订单")
    }

    func testUsesLowerCurrencyAmountWhenCardsHaveNoAmountLabel() {
        let result = PaymentParser.parse("""
        第一位用户
        ¥99.00

        第二位用户
        ¥17.60
        """)

        XCTAssertEqual(result.amount, Decimal(string: "17.60"))
        XCTAssertEqual(result.merchant, "第二位用户")
    }

    func testExtractsMerchantFromBankServiceNotification() {
        let result = PaymentParser.parse("""
        服务号通知
        交易时间 尾号0929信用卡09月07日12:04
        交易金额 18.63人民币，点击查看详情
        交易商户 支付宝-西安曲江新区运来湘味快餐店（个体工商户）
        商品说明 湘外婆快餐(曲江店)订单
        可用额度 ￥67113.81
        """)

        XCTAssertEqual(result.amount, Decimal(string: "18.63"))
        XCTAssertEqual(result.merchant, "西安曲江新区运来湘味快餐店（个体工商户）")
        XCTAssertEqual(result.paymentInfo, "湘外婆快餐(曲江店)订单")
    }

    func testUsesLastTransactionCardInMultiCardNotification() {
        let result = PaymentParser.parse("""
        服务号通知
        交易时间 尾号0929信用卡09月07日11:04
        交易金额 117.47人民币，点击查看详情
        交易商户 拼多多支付-虾有虾途生鲜官方旗舰店
        可用额度 ￥67132.44
        12:04
        交易成功提醒
        交易时间 尾号0929信用卡09月07日12:04
        交易金额 18.63人民币，点击查看详情
        交易商户 支付宝-西安曲江新区运来湘味快餐店（个体工商户）
        可用额度 ￥67113.81
        """)

        XCTAssertEqual(result.amount, Decimal(string: "18.63"))
        XCTAssertEqual(result.merchant, "西安曲江新区运来湘味快餐店（个体工商户）")
        XCTAssertEqual(PaymentParser.composedNote(merchant: result.merchant, paymentInfo: result.paymentInfo), "西安曲江新区运来湘味快餐店（个体工商户）")
    }

    func testExtractsWeChatCardUserAsMerchant() {
        let result = PaymentParser.parse("""
        微信支付
        交易状态 支付成功，对方已收款
        查看交易详情
        昨天 20:52
        Valve
        使用招商银行信用卡(0929)支付
        ¥17.60
        账单详情
        07:21
        微信支付分
        「先享后付」服务取消通知
        """)

        XCTAssertEqual(result.amount, Decimal(string: "17.60"))
        XCTAssertEqual(result.merchant, "Valve")
        XCTAssertEqual(PaymentParser.composedNote(merchant: result.merchant, paymentInfo: result.paymentInfo), "Valve")
    }

    func testPreservesTransactionDetailDescriptionForNote() {
        let result = PaymentParser.parse("""
        交易明细
        支付宝-西安曲江新区运来湘味快餐店（个体工商户）
        入账中
        信用卡 0929
        交易地金额 18.63
        """)

        XCTAssertEqual(result.amount, Decimal(string: "18.63"))
        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.merchant, "西安曲江新区运来湘味快餐店")
        XCTAssertEqual(result.paymentInfo, "支付宝-西安曲江新区运来湘味快餐店")
        XCTAssertEqual(PaymentParser.composedNote(merchant: result.merchant, paymentInfo: result.paymentInfo), "支付宝-西安曲江新区运来湘味快餐店")
    }

    func testPrefersWrappedPaymentChannelDescriptionOverTrailingMerchantLine() {
        let result = PaymentParser.parse("""
        交易明细
        支付宝-西安曲江新区运来湘味快餐店（
        个体工商户）
        入账中
        交易地金额 18.63
        """)

        XCTAssertEqual(result.merchant, "西安曲江新区运来湘味快餐店")
    }

    func testLimitsComposedNoteToFiftyCharacters() {
        let longProduct = String(repeating: "商品", count: 30)
        let note = PaymentParser.composedNote(merchant: "商户", paymentInfo: longProduct)

        XCTAssertEqual(note.count, PaymentParser.maxNoteLength)
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
