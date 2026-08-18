import XCTest

/// 数据刷新链路 UI 测试（与数据修复配套）：
/// 1. 记一笔保存后，首页/明细页无需手动刷新立即显示；
/// 2. 明细页「收入 / 支出」Tab 能正确过滤出对应类型的数据；
/// 3. 删除后立即消失；编辑后立即更新。
final class DataRefreshUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 完整链路：添加支出/收入 → 首页立即更新 → 明细 Tab 正确过滤 → 编辑/删除立即生效
    func testFullDataRefreshChain() throws {
        let app = XCUIApplication()
        app.launch()

        // 处理可能残留的「待确认账单」弹出（直接取消）
        let cancelButton = app.buttons["取消"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
        }

        // MARK: 明细页添加一笔支出
        app.tabBars.buttons["明细"].tap()
        tapAddButton(in: app)
        XCTAssertTrue(
            app.navigationBars["记一笔"].waitForExistence(timeout: 5),
            "记一笔表单未弹出"
        )
        enter(amount: "38", in: app)
        app.buttons["保存"].tap()

        // 保存后「全部」列表立即可见，无需刷新
        let expenseAmount = "-¥38.00"
        XCTAssertTrue(
            app.staticTexts[expenseAmount].waitForExistence(timeout: 5),
            "保存支出后明细页未立即显示: \(app.debugDescription)"
        )

        // 支出 Tab：应显示该支出
        app.buttons["支出"].tap()
        XCTAssertTrue(
            app.staticTexts[expenseAmount].waitForExistence(timeout: 5),
            "支出 Tab 未显示支出数据"
        )

        // 收入 Tab：不应显示支出
        app.buttons["收入"].tap()
        XCTAssertFalse(app.staticTexts[expenseAmount].exists, "收入 Tab 错误显示了支出数据")
        XCTAssertTrue(app.staticTexts["暂无账目"].waitForExistence(timeout: 5), "收入 Tab 应为空")

        // MARK: 明细页添加一笔收入
        tapAddButton(in: app)
        XCTAssertTrue(app.navigationBars["记一笔"].waitForExistence(timeout: 5), "记一笔表单未弹出")
        // 注意：表单的类型分段与列表页筛选分段都含「收入」，取最上层（后出现）的那个
        let incomeButtons = app.segmentedControls.buttons.matching(identifier: "收入")
        XCTAssertTrue(incomeButtons.count > 0, "未找到收入类型按钮")
        let formIncome = incomeButtons.element(boundBy: incomeButtons.count - 1)
        XCTAssertTrue(formIncome.waitForExistence(timeout: 5), "表单内未找到收入类型")
        // 表单弹入动画中元素可能短暂不可点击：改按坐标点击（命中屏幕最上层控件）
        formIncome.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        enter(amount: "100", in: app)
        app.buttons["保存"].tap()

        let incomeAmount = "+¥100.00"
        XCTAssertTrue(
            app.staticTexts[incomeAmount].waitForExistence(timeout: 5),
            "保存收入后收入 Tab 未立即显示"
        )

        // 切到支出 Tab：只应有支出，无收入
        app.buttons["支出"].tap()
        XCTAssertTrue(app.staticTexts[expenseAmount].waitForExistence(timeout: 5), "支出 Tab 丢失支出数据")
        XCTAssertFalse(app.staticTexts[incomeAmount].exists, "支出 Tab 错误显示了收入数据")

        // 切回收入 Tab：只应有收入
        app.buttons["收入"].tap()
        XCTAssertTrue(app.staticTexts[incomeAmount].waitForExistence(timeout: 5), "收入 Tab 丢失收入数据")
        XCTAssertFalse(app.staticTexts[expenseAmount].exists, "收入 Tab 错误显示了支出数据")

        // 全部 Tab：两者都在
        app.buttons["全部"].tap()
        XCTAssertTrue(app.staticTexts[expenseAmount].waitForExistence(timeout: 5), "全部 Tab 缺支出")
        XCTAssertTrue(app.staticTexts[incomeAmount].exists, "全部 Tab 缺收入")

        // MARK: 首页立即更新（无需手动刷新）
        app.tabBars.buttons["首页"].tap()
        XCTAssertTrue(
            app.staticTexts["¥38.00"].waitForExistence(timeout: 5),
            "首页本月支出未立即更新: \(app.debugDescription)"
        )
        XCTAssertTrue(
            app.staticTexts["¥100.00"].waitForExistence(timeout: 5),
            "首页本月收入未立即更新"
        )
        XCTAssertTrue(
            app.staticTexts[expenseAmount].waitForExistence(timeout: 5),
            "首页最近流水未立即显示支出"
        )
        XCTAssertTrue(app.staticTexts[incomeAmount].exists, "首页最近流水未立即显示收入")

        // MARK: 编辑后立即更新
        app.tabBars.buttons["明细"].tap()
        app.buttons["全部"].tap()
        let incomeCell = app.staticTexts[incomeAmount]
        XCTAssertTrue(incomeCell.waitForExistence(timeout: 5), "编辑前未找到收入行")
        incomeCell.tap()
        XCTAssertTrue(app.navigationBars["编辑账目"].waitForExistence(timeout: 5), "编辑表单未弹出")
        replace(amountIn: app, newText: "120")
        app.buttons["保存"].tap()

        let updatedIncome = "+¥120.00"
        XCTAssertTrue(
            app.staticTexts[updatedIncome].waitForExistence(timeout: 5),
            "编辑保存后列表未立即更新"
        )
        XCTAssertFalse(app.staticTexts[incomeAmount].exists, "编辑后旧金额仍残留")

        // MARK: 删除后立即消失
        let expenseCell = app.staticTexts[expenseAmount]
        XCTAssertTrue(expenseCell.waitForExistence(timeout: 5), "删除前未找到支出行")
        expenseCell.swipeLeft()
        let deleteButton = app.buttons["删除"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "未出现删除按钮: \(app.debugDescription)")
        deleteButton.tap()
        XCTAssertFalse(
            app.staticTexts[expenseAmount].waitForExistence(timeout: 2),
            "删除后支出未立即消失"
        )

        // 首页联动确认
        app.tabBars.buttons["首页"].tap()
        XCTAssertFalse(app.staticTexts[expenseAmount].exists, "首页仍显示已删除的支出")
    }

    // MARK: - 工具

    /// 等待元素变为可点击状态（用于表单弹入动画等场景）
    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, "元素在超时前未变为可点击: \(element)")
    }

    /// 明细页右上角 / 首页底部悬浮的「记一笔」入口
    private func tapAddButton(in app: XCUIApplication) {
        let addButton = app.buttons["记一笔"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "未找到记一笔入口: \(app.debugDescription)")
        addButton.tap()
    }

    /// 在金额输入框键入金额（表单中第一个文本框）
    private func enter(amount: String, in app: XCUIApplication) {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "未找到金额输入框")
        field.tap()
        field.typeText(amount)
    }

    /// 编辑时替换金额为 newText（先清空再输入）
    private func replace(amountIn app: XCUIApplication, newText: String) {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "未找到金额输入框")
        field.tap()
        // 全选删除
        field.press(forDuration: 1.2)
        let selectAll = app.menuItems["全选"]
        if selectAll.waitForExistence(timeout: 2) {
            selectAll.tap()
        }
        field.typeText(XCUIKeyboardKey.delete.rawValue)
        field.typeText(newText)
    }
}

/// 统计页数据刷新验证：新增交易后统计数字立即更新，周期切换重建后数据仍在。
final class StatisticsRefreshUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testStatisticsUpdatesImmediately() throws {
        let app = XCUIApplication()
        app.launch()

        // 处理可能残留的「待确认账单」弹出（直接取消）
        let cancelButton = app.buttons["取消"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
        }

        // 明细页添加一笔支出 ¥500
        app.tabBars.buttons["明细"].tap()
        let addButton = app.buttons["记一笔"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "未找到记一笔入口")
        addButton.tap()
        XCTAssertTrue(app.navigationBars["记一笔"].waitForExistence(timeout: 5), "记一笔表单未弹出")
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "未找到金额输入框")
        field.tap()
        field.typeText("500")
        app.buttons["保存"].tap()

        // 统计页：本月支出立即显示 ¥500.00（无需手动刷新）
        app.tabBars.buttons["统计"].tap()
        XCTAssertTrue(
            app.staticTexts["¥500.00"].firstMatch.waitForExistence(timeout: 5),
            "新增支出后统计页未立即更新: \(app.debugDescription)"
        )

        // 月度 ↔ 年度来回切换后（重建查询）数据仍在
        app.buttons["年度"].tap()
        XCTAssertTrue(app.staticTexts["¥500.00"].firstMatch.waitForExistence(timeout: 5), "年度视图未显示支出")
        app.buttons["月度"].tap()
        XCTAssertTrue(app.staticTexts["¥500.00"].firstMatch.waitForExistence(timeout: 5), "切回月度后数据丢失")

        // 增加一笔收入 ¥200 后统计页立即显示
        app.tabBars.buttons["明细"].tap()
        let addButton2 = app.buttons["记一笔"].firstMatch
        XCTAssertTrue(addButton2.waitForExistence(timeout: 5), "未找到记一笔入口")
        addButton2.tap()
        XCTAssertTrue(app.navigationBars["记一笔"].waitForExistence(timeout: 5), "记一笔表单未弹出")
        let incomeButtons = app.segmentedControls.buttons.matching(identifier: "收入")
        XCTAssertTrue(incomeButtons.count > 0, "未找到收入类型按钮")
        let formIncome = incomeButtons.element(boundBy: incomeButtons.count - 1)
        XCTAssertTrue(formIncome.waitForExistence(timeout: 5), "表单内未找到收入类型")
        formIncome.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let field2 = app.textFields.firstMatch
        XCTAssertTrue(field2.waitForExistence(timeout: 5), "未找到金额输入框")
        field2.tap()
        field2.typeText("200")
        app.buttons["保存"].tap()

        app.tabBars.buttons["统计"].tap()
        XCTAssertTrue(
            app.staticTexts["¥200.00"].firstMatch.waitForExistence(timeout: 5),
            "新增收入后统计页未立即更新: \(app.debugDescription)"
        )
    }
}