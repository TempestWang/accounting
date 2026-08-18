import AppIntents

/// 让「识别截图」意图出现在快捷指令 App 中，并附带 Siri 短语
struct LedgerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecognizeAndRecordIntent(),
            phrases: [
                "用\(.applicationName)识别截图记账",
                "\(.applicationName)识别截图",
            ],
            shortTitle: "识别截图",
            systemImageName: "text.viewfinder"
        )
    }
}
