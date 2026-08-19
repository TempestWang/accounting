import XCTest
import SwiftUI
@testable import Bookkeeping

/// 主题引擎单元测试（不依赖 UI，用于可靠验证主题系统核心逻辑）：
/// 8 套主题数据、UserDefaults 持久化与重启恢复、外观模式映射、
/// 动态色板解析、渲染令牌等。
final class ThemeModelTests: XCTestCase {

    // MARK: - 主题数据

    func testAllThemesPresentAndUnique() {
        XCTAssertEqual(AppTheme.all.count, 8, "应内置 8 套主题")
        let ids = AppTheme.all.map(\.id)
        XCTAssertEqual(Set(ids).count, 8, "主题 id 必须唯一")
        XCTAssertEqual(Set(AppTheme.all.map(\.name)).count, 8, "主题名必须唯一")

        // 每套主题必须同时提供浅色 / 深色两套色板
        for theme in AppTheme.all {
            XCTAssertNotEqual(theme.light, theme.dark, "\(theme.name) 的深浅色板应不同")
        }
    }

    func testSupportedThemeIds() {
        let ids = Set(AppTheme.all.map(\.id))
        XCTAssertTrue(ids.isSuperset(of: ["apple", "midnight", "purple", "ocean",
                                          "forest", "sunset", "minimal", "gold"]))
    }

    func testThemeLookupAndFallback() {
        XCTAssertEqual(AppTheme.theme(for: "ocean")?.name, "Ocean 海洋")
        XCTAssertNil(AppTheme.theme(for: "not-exist"))
        XCTAssertEqual((AppTheme.theme(for: "not-exist") ?? .apple).id, "apple")
    }

    func testDefaultThemeIsApple() {
        // 使用隔离 defaults，避免测试间通过 ThemeManager.shared 相互污染
        let (suite, name) = makeIsolatedDefaults()
        defer { suite.removePersistentDomain(forName: name) }
        let manager = ThemeManager(defaults: suite)
        XCTAssertEqual(manager.theme.id, "apple")
        XCTAssertNil(manager.preferredColorScheme)
    }

    // MARK: - 持久化与重启恢复

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let name = "ThemeTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return (suite, name)
    }

    func testThemeSelectionPersistsAndRestores() {
        let (suite, name) = makeIsolatedDefaults()
        defer { suite.removePersistentDomain(forName: name) }

        let manager = ThemeManager(defaults: suite)
        XCTAssertEqual(manager.theme.id, "apple", "无记录时默认 Apple 主题")

        manager.select(theme: .sunset)
        XCTAssertEqual(suite.string(forKey: "app.theme.id"), "sunset")

        // 模拟 App 重启：新实例从同一 UserDefaults 恢复选择
        let restored = ThemeManager(defaults: suite)
        XCTAssertEqual(restored.theme.id, "sunset")
        XCTAssertEqual(restored.theme.name, "Sunset 日落")
    }

    func testAppearancePersistsAndRestores() {
        let (suite, name) = makeIsolatedDefaults()
        defer { suite.removePersistentDomain(forName: name) }

        let manager = ThemeManager(defaults: suite)
        XCTAssertEqual(manager.appearanceMode, .system, "无记录时默认跟随系统")

        manager.setAppearance(.dark)
        XCTAssertEqual(suite.string(forKey: "app.appearance.mode"), "dark")

        let restored = ThemeManager(defaults: suite)
        XCTAssertEqual(restored.appearanceMode, .dark)
        XCTAssertEqual(restored.preferredColorScheme, .dark)
    }

    // MARK: - 外观模式映射

    func testAppearanceModeMapping() {
        XCTAssertNil(AppearanceMode.system.preferredColorScheme, "跟随系统 → nil")
        XCTAssertEqual(AppearanceMode.light.preferredColorScheme, .light)
        XCTAssertEqual(AppearanceMode.dark.preferredColorScheme, .dark)
        XCTAssertEqual(AppearanceMode.allCases.count, 3)
    }

    // MARK: - 渲染令牌

    func testSelectThemeBumpsRenderToken() {
        let (suite, name) = makeIsolatedDefaults()
        defer { suite.removePersistentDomain(forName: name) }
        let manager = ThemeManager(defaults: suite)
        let before = manager.renderToken
        manager.select(theme: .ocean)
        XCTAssertGreaterThan(manager.renderToken, before, "切换主题应自增渲染令牌")
        XCTAssertEqual(manager.theme.id, "ocean")
    }

    func testAppearanceChangeDoesNotBumpRenderToken() {
        let (suite, name) = makeIsolatedDefaults()
        defer { suite.removePersistentDomain(forName: name) }
        let manager = ThemeManager(defaults: suite)
        let before = manager.renderToken
        manager.setAppearance(.light)
        XCTAssertEqual(manager.renderToken, before, "外观切换通过 preferredColorScheme 生效，无需全量重建")
    }

    // MARK: - 颜色数据

    func testRGBColorHexParsing() {
        let c = RGBColor(0x6B5CE7)
        XCTAssertEqual(c.r, 0x6B / 255, accuracy: 0.001)
        XCTAssertEqual(c.g, 0x5C / 255, accuracy: 0.001)
        XCTAssertEqual(c.b, 0xE7 / 255, accuracy: 0.001)
        XCTAssertEqual(RGBColor(0x000000, alpha: 1).b, 0, accuracy: 0.001)
        XCTAssertEqual(RGBColor(0xFFFFFF).r, 1, accuracy: 0.001)
        // 透明度
        let faded = RGBColor(0xFF0000, alpha: 0.5)
        XCTAssertEqual(faded.alpha, 0.5)
        XCTAssertEqual(faded.uiColor.cgColor.alpha, 0.5, accuracy: 0.01)
    }

    func testButtonTextContrastRule() {
        // Minimal 深色模式：按钮文字必须是黑色（白底按钮）
        XCTAssertEqual(AppTheme.minimal.dark.buttonText.r, 0, accuracy: 0.001)
        XCTAssertEqual(AppTheme.minimal.dark.buttonText.g, 0, accuracy: 0.001)
        XCTAssertEqual(AppTheme.minimal.dark.buttonText.b, 0, accuracy: 0.001)
        // 其他主题按钮文字为白色
        for theme in AppTheme.all where theme.id != "minimal" {
            XCTAssertEqual(theme.light.buttonText.r, 1, accuracy: 0.001)
            XCTAssertEqual(theme.dark.buttonText.r, 1, accuracy: 0.001)
        }
    }

    func testPaletteFieldsAreValidRGB() {
        for theme in AppTheme.all {
            for palette in [theme.light, theme.dark] {
                for color in [palette.primary, palette.secondary, palette.gradientStart,
                              palette.gradientEnd, palette.background, palette.card,
                              palette.heroCard, palette.heroGlow] {
                    XCTAssertGreaterThanOrEqual(color.r, 0)
                    XCTAssertLessThanOrEqual(color.r, 1)
                    XCTAssertGreaterThanOrEqual(color.g, 0)
                    XCTAssertLessThanOrEqual(color.g, 1)
                    XCTAssertGreaterThanOrEqual(color.b, 0)
                    XCTAssertLessThanOrEqual(color.b, 1)
                }
            }
        }
    }

    func testResolvedColorsAreConsistent() {
        for theme in AppTheme.all {
            let colors = theme.resolvedColors
            // 按钮渐变恒为两色（实心主题也退化为同色渐变）
            XCTAssertEqual(colors.buttonGradient.count, 2)
            // 结构层与品牌层语义独立（background 与 card 是不同动态色）
            XCTAssertNotEqual(colors.background, colors.card)
            XCTAssertNotEqual(colors.primary, colors.secondary)
        }
    }
}