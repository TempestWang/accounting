import SwiftUI

// MARK: - 动画与交互动效

/// 全 App 统一的动效节奏：克制、流畅、符合 iOS 原生手感。
enum AppAnimation {
    /// 内容切换 / 选中状态的弹性格
    static let spring = Animation.spring(duration: 0.45, bounce: 0.22)
    /// 轻量反馈（按压、开关、小元素）
    static let smooth = Animation.easeOut(duration: 0.22)
    /// 区块过渡
    static let content = Animation.easeInOut(duration: 0.30)
    /// 大数字 / 主卡入场
    static let hero = Animation.spring(duration: 0.55, bounce: 0.18)
}

/// 全局便捷封装：withAnimation 的语义化版本
func withSmoothAnimation<Result>(_ animation: Animation = AppAnimation.smooth,
                                 _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(animation, body)
}

/// 按压反馈视图修饰：保证所有可点元素有统一的「按下缩小」反馈
struct PressFeedbackModifier: ViewModifier {
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(pressed ? 0.9 : 1)
            .animation(AppAnimation.smooth, value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in pressed = false }
            )
    }
}

extension View {
    /// 给任意可点击内容加上统一的按压反馈
    func pressFeedback() -> some View {
        modifier(PressFeedbackModifier())
    }
}

/// 统一按钮按压样式（ButtonStyle 版本，不影响现有 buttonStyle(.plain) 用法）
struct DSScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(AppAnimation.smooth, value: configuration.isPressed)
    }
}