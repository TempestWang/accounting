import SwiftUI

// MARK: - 外观模式

/// App 外观模式：跟随系统 / 强制浅色 / 强制深色。
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// 注入到根视图的 preferredColorScheme；.system 返回 nil 表示跟随系统
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - 主题管理器

/// 全局主题管理器（单例）：
/// - `@Published` 暴露当前主题与外观模式，任何视图通过
///   `@EnvironmentObject var theme: ThemeManager` 读取即可自动响应变化；
/// - 选择写入 UserDefaults，App 重启后自动恢复；
/// - `renderToken` 在主题切换时自增，根视图以它作为 `.id()`，
///   触发全 App 重建，让所有直接引用 `DSColor.*` 的既有页面即时生效。
///
/// 未标注 MainActor：原有颜色系统（DSColor 静态成员）在非主线程上下文
/// 也会被读取，保持非隔离可避免严格并发检查报错；SwiftUI 环境对象
/// 本身在主线程驱动，状态一致性由系统保证。
final class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    // MARK: 状态

    /// 当前主题 id
    @Published var themeID: String {
        didSet { defaults.set(themeID, forKey: Self.themeKey) }
    }

    /// 外观模式
    @Published var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Self.appearanceKey) }
    }

    /// 渲染令牌：主题切换时自增，供根视图 .id() 全量刷新
    @Published private(set) var renderToken = 0

    /// 主题设置面板是否展示（由「我的」页入口控制，sheet 挂在根视图上，
    /// 不随 renderToken 重建，保证选主题时页面不被顶掉）
    @Published var isThemeSettingsPresented = false

    // MARK: 派生值

    /// 当前主题
    var theme: AppTheme {
        AppTheme.theme(for: themeID) ?? .apple
    }

    /// 当前主题的解析后动态色（随有效外观自动切换 Light / Dark）
    var colors: ThemeColors {
        theme.resolvedColors
    }

    /// 注入根视图的外观偏好
    var preferredColorScheme: ColorScheme? {
        appearanceMode.preferredColorScheme
    }

    // MARK: 持久化

    private static let themeKey = "app.theme.id"
    private static let appearanceKey = "app.appearance.mode"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.themeID = defaults.string(forKey: Self.themeKey) ?? AppTheme.apple.id
        if let raw = defaults.string(forKey: Self.appearanceKey),
           let mode = AppearanceMode(rawValue: raw) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }
    }

    // MARK: 操作

    /// 切换主题（立即生效并持久化）
    func select(theme: AppTheme) {
        withSmoothAnimation(AppAnimation.smooth) {
            self.themeID = theme.id
            self.renderToken += 1
        }
    }

    /// 设置外观模式（立即生效并持久化）
    func setAppearance(_ mode: AppearanceMode) {
        withSmoothAnimation(AppAnimation.smooth) {
            self.appearanceMode = mode
        }
    }

    /// 打开/关闭主题设置面板
    func presentThemeSettings(_ show: Bool = true) {
        isThemeSettingsPresented = show
    }
}