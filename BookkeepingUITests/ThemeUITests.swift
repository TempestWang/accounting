import XCTest

/// 主题系统端到端验证：
/// 打开主题设置 → 切换主题（实时更新）→ 切外观模式 → 关闭回「我的」页
/// → 重启 App 后主题保持（UserDefaults 持久化）。
///
/// 注意：本用例依赖 XCUITest 合成点击，请在 Xcode GUI（⌘U）或常规模拟器环境
/// 运行；部分 iOS 26 模拟器 + 命令行 runner 下存在「点击不落」的已知抖动，
/// 核心逻辑请以 BookkeepingUnitTests/ThemeModelTests（纯单元测试）为准。
final class ThemeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testThemeSwitchLiveUpdateAndPersistence() throws {
        dismissPendingFormIfNeeded()   // 兜底：若有待确认账单弹出的「记一笔」，先关闭
        openThemeSettings()

        // 顶部实时预览卡：应显示「已应用」+ 当前主题名
        XCTAssertTrue(app.staticTexts["已应用"].waitForExistence(timeout: 5),
                      "主题页顶部应显示实时预览与「已应用」状态")

        // 点击 Midnight 主题卡片 → 立即应用
        let midnightCard = app.buttons["theme.card.midnight"]
        XCTAssertTrue(midnightCard.waitForExistence(timeout: 5), "应显示 Midnight 主题卡片")
        midnightCard.tap()

        // 实时预览更新为本主题
        XCTAssertTrue(app.staticTexts["Midnight 夜空"].firstMatch.waitForExistence(timeout: 5),
                      "点击卡片后预览区应实时显示 Midnight 夜空")

        // 外观：切深色 → 切回跟随系统（确认不崩溃、正常交互）
        let darkRow = app.buttons["appearance.dark"]
        XCTAssertTrue(darkRow.waitForExistence(timeout: 5), "应显示外观：深色模式选项")
        darkRow.tap()
        app.buttons["appearance.system"].tap()

        // 关闭主题设置
        app.buttons["完成"].tap()

        // 回到「我的」页：入口显示当前主题名（实时更新）
        XCTAssertTrue(app.staticTexts["Midnight 夜空"].firstMatch.waitForExistence(timeout: 5),
                      "「我的」页主题入口应显示 Midnight 夜空")

        // 重启 App：主题选择持久化
        app.terminate()
        app.launch()
        dismissPendingFormIfNeeded()

        openThemeSettings()
        XCTAssertTrue(app.staticTexts["Midnight 夜空"].firstMatch.waitForExistence(timeout: 5),
                      "重启后主题应保持 Midnight 夜空")
    }

    /// 兜底：待确认账单（快捷指令截图识别遗留）会在启动时自动弹出
    /// 「记一笔」表单，遮挡 TabBar；点「取消」关闭它（关闭即删除该待确认账单）
    private func dismissPendingFormIfNeeded() {
        let cancel = app.buttons["取消"]
        if cancel.waitForExistence(timeout: 3) {
            cancel.tap()
            let form = app.navigationBars["记一笔"]
            _ = form.waitForNonExistence(timeout: 5)
        }
    }

    /// 打开「我的」→「主题设置」面板
    private func openThemeSettings() {
        let tab = app.tabBars.firstMatch.buttons["我的"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "应显示「我的」Tab")
        tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let row = app.buttons["settings.theme"]
        if !row.waitForExistence(timeout: 5) {
            print("=== DEBUG HIERARCHY ===")
            print(app.debugDescription)
        }
        XCTAssertTrue(row.exists, "「我的」页应显示主题设置入口")
        // 元素坐标系在此模拟器上不可靠（a11y 帧不含 padding），改用屏幕坐标直点行中心
        // （行 frame 稳定为 {{32, 326}, {337, 28}}）
        let tap = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 201, dy: 340))
        tap.tap()

        let navBar = app.navigationBars["主题设置"]
        if !navBar.waitForExistence(timeout: 5) {
            print("=== DEBUG SHEET HIERARCHY ===")
            print(app.debugDescription)
        }
        XCTAssertTrue(navBar.exists, "应弹出主题设置页（sheet）")
    }
}