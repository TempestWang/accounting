import SwiftUI
import PhotosUI
import UIKit

/// 从相册选择付款截图 → OCR → 预填记账表单
/// UI优化：根据设计稿调整按钮样式
struct ImageRecognitionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var recognizedText = ""
    @State private var parsed: ParsedPayment?
    @State private var showForm = false
    @State private var showNoAmount = false
    @State private var processingTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(DSColor.primary)
                        Text("从相册选择付款截图")
                            .font(Typography.headline)
                            .foregroundStyle(.primary)
                        Text("识别金额、商户、日期并自动填入记账表单")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                    .background(
                        RoundedRectangle(cornerRadius: DRadius.card, style: .continuous)
                            .fill(DSColor.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: DRadius.card, style: .continuous)
                                    .strokeBorder(DSColor.hairline, lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    )
                }
                .buttonStyle(DSScaleButtonStyle())

                if isProcessing {
                    ProgressView("正在识别…")
                }

                if !recognizedText.isEmpty {
                    DisclosureGroup("识别到的原始文字") {
                        Text(recognizedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("从截图识别记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                processingTask?.cancel()
                processingTask = Task { await loadAndParse(item) }
            }
            .onDisappear {
                processingTask?.cancel()
            }
            .sheet(isPresented: $showForm) {
                TransactionFormView(prefill: prefillData())
            }
            .alert("未识别到金额", isPresented: $showNoAmount) {
                Button("好", role: .cancel) {}
            } message: {
                Text("请确认截图内容清晰，或手动记一笔。")
            }
        }
    }

    // MARK: - 识别

    private func loadAndParse(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }

        guard !Task.isCancelled else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let text = await OCRService.recognizeText(in: image)
        guard !Task.isCancelled else { return }

        recognizedText = text
        let result = PaymentParser.parse(text)
        parsed = result
        pickerItem = nil  // 允许下次重新选择同一张图片
        if let amount = result.amount, amount > 0 {
            showForm = true
        } else {
            showNoAmount = true
        }
    }

    private func prefillData() -> PrefillData {
        let p = parsed
        return PrefillData(
            amountText: p?.amount.map { "\($0)" } ?? "",
            note: p?.merchant ?? "",
            categoryName: p?.categoryName,
            date: p?.date,
            type: p?.type ?? .expense,
            source: "分享识别"
        )
    }
}
