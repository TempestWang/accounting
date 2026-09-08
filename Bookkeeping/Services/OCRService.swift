import UIKit
import Vision

/// Vision 返回的单个文本块及其在图片中的归一化坐标。
struct OCRTextBlock {
    let text: String
    let boundingBox: CGRect
}

/// Vision 文字识别封装（离线，支持中文）
enum OCRService {
    /// 识别图片中的全部文字，按阅读顺序换行拼接
    static func recognizeText(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await Task.detached(priority: .userInitiated) { () -> String in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                return ""
            }
            let blocks = (request.results ?? []).compactMap { observation -> OCRTextBlock? in
                guard let text = observation.topCandidates(1).first?.string else { return nil }
                return OCRTextBlock(text: text, boundingBox: observation.boundingBox)
            }
            return readingOrderText(from: blocks)
        }.value
    }

    /// Vision 在付款详情页经常按“左侧标签列全部读完，再读右侧值列”的顺序返回。
    /// 这里依据纵坐标重建视觉行，确保「商品 + 商品值」「收款方 + 商户名」保持在一起。
    static func readingOrderText(from blocks: [OCRTextBlock]) -> String {
        struct Row {
            var blocks: [OCRTextBlock]

            var minY: CGFloat { blocks.map(\.boundingBox.minY).min() ?? 0 }
            var maxY: CGFloat { blocks.map(\.boundingBox.maxY).max() ?? 0 }
            var midY: CGFloat { blocks.map(\.boundingBox.midY).reduce(0, +) / CGFloat(blocks.count) }

            func matches(_ block: OCRTextBlock) -> Bool {
                let overlap = min(maxY, block.boundingBox.maxY) - max(minY, block.boundingBox.minY)
                let referenceHeight = min(maxY - minY, block.boundingBox.height)
                return referenceHeight > 0 && overlap / referenceHeight >= 0.35
            }
        }

        let orderedBlocks = blocks
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.003 {
                    return $0.boundingBox.midY > $1.boundingBox.midY
                }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }

        var rows: [Row] = []
        for block in orderedBlocks {
            if let index = rows.indices
                .filter({ rows[$0].matches(block) })
                .min(by: { abs(rows[$0].midY - block.boundingBox.midY) < abs(rows[$1].midY - block.boundingBox.midY) }) {
                rows[index].blocks.append(block)
            } else {
                rows.append(Row(blocks: [block]))
            }
        }

        return rows
            .sorted { $0.midY > $1.midY }
            .map { row in
                row.blocks
                    .sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                    .map(\.text)
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
    }
}
