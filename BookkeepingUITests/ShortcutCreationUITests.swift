import XCTest

/// 快捷指令自动化测试：
/// 模拟器内自动创建「获取最新的照片 → 识别截图」快捷指令并运行，
/// 验证账本 App 被打开并自动弹出「记一笔」页面（预填识别结果）。
final class ShortcutCreationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 完整链路：创建快捷指令 → 运行 → 账本打开 → 记一笔页面出现
    func testRunRecognitionShortcut() throws {
        let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
        shortcuts.launch()
        sleep(3)

        // 新建快捷指令
        let createButton = shortcuts.buttons["创建快捷指令"]
        XCTAssertTrue(createButton.exists, "未找到创建按钮")
        createButton.tap()
        sleep(3)

        // 动作1：获取最新的照片
        let searchField = shortcuts.searchFields["搜索操作"]
        XCTAssertTrue(searchField.exists, "未找到搜索框")
        searchField.tap()
        searchField.typeText("获取最新的照片")
        sleep(2)
        let photoCell = shortcuts.cells["获取最新的照片"]
        XCTAssertTrue(photoCell.exists, "未找到照片动作")
        photoCell.tap()
        sleep(2)

        // 动作2：识别截图
        let searchField2 = shortcuts.searchFields["搜索操作"]
        XCTAssertTrue(searchField2.exists, "未找到第二个搜索框")
        searchField2.tap()
        searchField2.typeText("识别截图")
        sleep(2)
        let recognizeCell = shortcuts.cells["识别截图"]
        XCTAssertTrue(recognizeCell.exists, "未找到识别截图动作")
        recognizeCell.tap()
        sleep(2)

        // 确认图片参数已连接「最新照片」（快捷指令自动连接前一步输出）
        let paramButton = shortcuts.buttons["最新照片"]
        XCTAssertTrue(paramButton.exists, "图片参数未显示最新照片: \(shortcuts.debugDescription)")

        // 点「播放」运行快捷指令
        let playButton = shortcuts.buttons["播放"]
        XCTAssertTrue(playButton.exists, "未找到播放按钮")
        playButton.tap()

        // 处理可能的系统权限弹窗（照片访问）
        handlePermissionAlerts()

        // 等待账本 App 被打开（openAppWhenRun）
        let ledger = XCUIApplication(bundleIdentifier: "com.tempestwang.Bookkeeping")
        let ledgerLaunched = ledger.wait(for: .runningForeground, timeout: 30)
        XCTAssertTrue(ledgerLaunched, "账本 App 未在前台打开")

        // 断言「记一笔」页面弹出（保存按钮存在）
        sleep(3)
        let saveButton = ledger.buttons["保存"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 15), "未出现记一笔页面的保存按钮: \(ledger.debugDescription)")
    }

    /// 处理系统权限弹窗（允许照片访问等）
    private func handlePermissionAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<4 {
            let allowButton = springboard.buttons["允许"]
            if allowButton.waitForExistence(timeout: 3) {
                allowButton.tap()
                sleep(1)
            } else {
                break
            }
        }
    }
}
