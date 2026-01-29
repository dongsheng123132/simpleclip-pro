import Foundation
import SwiftData
import NaturalLanguage
import UserNotifications
#if canImport(FoundationModels)
import FoundationModels
#endif

final class DailySummaryService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 若今日尚无日报则生成一条（主线程调用，内部在后台生成后回主线程写库）
    func tryEnsureTodayDigest() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        // 检查是否已有今日日报（在主线程 / Context 所在队列）
        var descriptor = FetchDescriptor<DailyDigest>(
            predicate: #Predicate<DailyDigest> { $0.date == startOfToday },
            sortBy: []
        )
        descriptor.fetchLimit = 1
        if (try? modelContext.fetch(descriptor).first) != nil {
            return
        }

        // 获取当日剪贴项（仅文本与 URL）
        let itemDescriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let allItems = try? modelContext.fetch(itemDescriptor) else { return }
        let todayItems = allItems.filter { calendar.isDate($0.timestamp, inSameDayAs: Date()) }
        let textAndUrlItems = todayItems.filter { $0.type == .text || $0.type == .url }
        let itemCount = textAndUrlItems.count
        
        if itemCount == 0 {
            let emptyDigest = DailyDigest(date: startOfToday, summary: "今日无剪贴记录。", itemCount: 0)
            modelContext.insert(emptyDigest)
            try? modelContext.save()
            return
        }
        
        // 在后台生成摘要文本（优先本地 Apple Intelligence，否则 NaturalLanguage）
        let contents = textAndUrlItems.map(\.content)
        
        // 使用 Task.detached 避免阻塞主线程，但后续写库必须回主线程
        Task.detached(priority: .userInitiated) {
            let summary = await Self.generateSummary(contents: contents)

            await MainActor.run { [weak self] in
                guard let self = self else { return }
                // 再次检查是否在生成期间已有日报被创建（避免竞态）
                let checkDescriptor = FetchDescriptor<DailyDigest>(
                    predicate: #Predicate<DailyDigest> { $0.date == startOfToday }
                )
                if (try? self.modelContext.fetch(checkDescriptor).first) == nil {
                    let digest = DailyDigest(date: startOfToday, summary: summary, itemCount: itemCount)
                    self.modelContext.insert(digest)
                    try? self.modelContext.save()
                    Self.sendDigestGeneratedNotification(itemCount: itemCount)
                }
            }
        }
    }

    /// 生成摘要：在 macOS 26+ 且 Apple Intelligence 可用时用 FoundationModels（摘要+决策建议），否则用 NaturalLanguage。全部本地，无网络。
    private static func generateSummary(contents: [String]) async -> String {
#if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if let summary = await generateSummaryWithFoundationModels(contents: contents) {
                return summary
            }
        }
#endif
        return generateSummaryWithNaturalLanguage(contents: contents)
    }

#if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func generateSummaryWithFoundationModels(contents: [String]) async -> String? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        let combined = contents.prefix(30).joined(separator: "\n\n")
        let truncated = combined.count > 6000 ? String(combined.prefix(6000)) + "…" : combined
        let prompt = """
        以下是一天内的剪贴板内容片段（每段用空行分隔）。请用一两段话总结今天剪贴的大致主题与重点，并在最后用一行「建议：」给出简短决策建议（例如：是否可清理、哪些值得固定、注意事项等）。只输出总结与建议，不要其他解释。

        内容：
        \(truncated)
        """

        do {
            let session = LanguageModelSession {
                "你是剪贴板助手。根据用户当天的剪贴内容做简短总结，并给出一句可操作的建议。用中文回复。"
            }
            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.3,
                maximumResponseTokens: 400
            )
            let response = try await session.respond(to: prompt, options: options)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
#endif

    /// 删除今日日报后重新生成（用于测试或手动刷新）
    func forceRegenerateTodayDigest() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DailyDigest>(
            predicate: #Predicate<DailyDigest> { $0.date == startOfToday },
            sortBy: []
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
        tryEnsureTodayDigest()
    }

    private static func sendDigestGeneratedNotification(itemCount: Int) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "今日剪贴摘要已生成"
            content.body = "共 \(itemCount) 条记录，可在 SimpleClip 工作日报中查看。"
            content.sound = .default
            let request = UNNotificationRequest(identifier: "dailyDigest-\(UUID().uuidString)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    /// 使用 NaturalLanguage 生成摘要：关键词、命名实体、链接列表。
    /// 完整段落摘要需 macOS 26+ 的 FoundationModels（Apple Intelligence）；当前为本地关键词提取。
    nonisolated private static func generateSummaryWithNaturalLanguage(contents: [String]) -> String {
        var keywords: Set<String> = []
        var urls: [String] = []
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])

        for text in contents {
            if let url = URL(string: text), url.scheme != nil {
                urls.append(text)
                continue
            }
            let lower = text.lowercased()
            if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
                urls.append(text)
                continue
            }
            tagger.string = text
            let range = text.startIndex..<text.endIndex
            tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, tokenRange in
                if tag == .noun || tag == .verb {
                    let word = String(text[tokenRange])
                    if word.count > 1, word.count < 30 {
                        keywords.insert(word)
                    }
                }
                return true
            }
            tagger.enumerateTags(in: range, unit: .word, scheme: .nameType, options: [.omitPunctuation, .omitWhitespace]) { tag, tokenRange in
                if tag == .personalName || tag == .placeName || tag == .organizationName {
                    let word = String(text[tokenRange])
                    if word.count > 1 {
                        keywords.insert(word)
                    }
                }
                return true
            }
        }

        let keywordList = Array(keywords).prefix(15).sorted()
        let urlList = Array(Set(urls)).prefix(10)

        var lines: [String] = []
        lines.append("今日共 \(contents.count) 条剪贴。")
        if !keywordList.isEmpty {
            lines.append("关键词：\(keywordList.joined(separator: "、"))")
        }
        if !urlList.isEmpty {
            lines.append("链接：\(urlList.joined(separator: " "))")
        }
        return lines.joined(separator: "\n")
    }
}
