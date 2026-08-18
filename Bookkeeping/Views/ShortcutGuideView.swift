import SwiftUI

/// 快捷指令搭建教程
struct ShortcutGuideView: View {
    var body: some View {
        List {
            Section("第一步：准备截图") {
                Text("iOS 不允许快捷指令直接截取当前屏幕。推荐把「轻点背面两下」设为截屏：")
                Label("设置 → 辅助功能 → 触控 → 轻点背面", systemImage: "1.circle")
                Label("轻点两下 → 选择「截屏」", systemImage: "2.circle")
                Text("付款时：先敲两下背面截屏，截图会自动存进相册。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("第二步：新建快捷指令「账本记账」") {
                Text("打开「快捷指令」App，新建一个快捷指令，依次添加：")
                Label("「获取最近的照片」", systemImage: "photo.on.rectangle")
                Label("「运行 账本 的『识别截图』」", systemImage: "bolt.fill")
                Label("「图片」点「选择」→「变量」→ 选「最近的照片」", systemImage: "photo")
                Text("运行后会自动打开 App 并进入「记一笔」页面，识别结果已预填，核对后保存即可。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("第三步：用背面触发") {
                Text("设置 → 辅助功能 → 触控 → 轻点背面：")
                Label("轻点三下 → 快捷指令 → 选「账本记账」", systemImage: "hand.tap.fill")
                Text("使用：付款页面先敲两下截屏，再敲三下，即自动识别记账。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("可选：分享面板直达") {
                Text("在快捷指令的详情里打开「在共享表单中显示」，付款截屏后点左下缩略图 → 分享 → 选「账本记账」，同样能自动记账。")
            }

            Section("可选：Siri 语音记账") {
                Text("对着 Siri 说「用账本识别记账」，会直接运行该快捷指令（需要先把快捷指令收藏到 Siri 或说出完整短语）。")
            }

            Section("提示") {
                Text("自动记账可能存在识别误差，可在「明细」里核对，错误的直接左滑删除。识别分类的关键词可在 App 代码的 PaymentParser 中自定义扩充。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("快捷指令搭建教程")
        .navigationBarTitleDisplayMode(.inline)
    }
}
