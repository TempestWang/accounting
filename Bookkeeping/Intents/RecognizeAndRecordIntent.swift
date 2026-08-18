import AppIntents
import SwiftData
import SwiftUI
import UIKit

/// 快捷指令「识别截图」的入口：
/// 接收上一步骤的截图（image，可直接连接「获取最近的照片」等截屏变量），
/// 在 App 内 OCR + 解析后创建待确认账单并打开 App，
/// 自动进入现有「记一笔」页面预填识别结果，由用户核对修改后保存。
struct RecognizeAndRecordIntent: AppIntent {
    static var title: LocalizedStringResource = "识别截图"
    static var description = IntentDescription("识别付款截图的金额、商户、日期，并预填到「记一笔」页面。")
    static var isDiscoverable = true

    /// 运行后自动打开宿主 App（官方方案，覆盖冷启动 / 后台 / 已打开三种场景）
    static var openAppWhenRun: Bool { true }

    /// 图片：连接快捷指令上一步骤的截图（如「获取最近的照片」的输出）。
    /// connectToPreviousIntentResult 允许直接连接上一步骤结果（截屏变量）。
    @Parameter(title: "图片", inputConnectionBehavior: .connectToPreviousIntentResult)
    var image: IntentFile?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 从截图读取数据并做 OCR（let 一次性赋值，保证并发捕获安全）
        let screenshotData: Data?
        var recognizedText = ""
        if let image {
            screenshotData = image.data
            if let uiImage = UIImage(data: image.data) {
                recognizedText = await OCRService.recognizeText(in: uiImage)
            }
        } else {
            screenshotData = nil
        }

        // 没有可识别的截图：提示用户把上一步的截屏连接到图片参数
        guard !recognizedText.isEmpty else {
            return .result(dialog: IntentDialog(
                "没有可识别的截图。请在快捷指令中把「最近的照片」等截屏变量连接到「图片」参数后重试。"
            ))
        }

        // 解析 → 待确认账单（识别结果绝不直接写入正式 Transaction，
        // 由用户在「记一笔」页面核对修改后保存）
        let parsed = PaymentParser.parse(recognizedText)

        await MainActor.run {
            let context = AppModel.container.mainContext
            PresetData.seedIfNeeded(context: context)
            _ = TransactionImportService.createPending(
                from: parsed,
                screenshot: screenshotData,
                source: "快捷指令截图",
                in: context
            )
        }

        let dialog: String
        if let amount = parsed.amount, amount > 0 {
            dialog = "已识别账单 ¥\(DateFormatters.money(amount))，已打开「账本」，请在「记一笔」页面核对后保存。"
        } else {
            dialog = "已创建待确认账单（金额未识别），已打开「账本」，请在「记一笔」页面补充金额后保存。"
        }
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: dialog)))
    }
}