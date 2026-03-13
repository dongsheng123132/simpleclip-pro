import Foundation
import FoundationModels

@main
struct LifeClipAIHelper {
    static func main() async {
        // --check flag: only check Apple Intelligence availability
        if CommandLine.arguments.contains("--check") {
            let available = SystemLanguageModel.default.isAvailable
            if available {
                print("apple-ai-available")
                Foundation.exit(0)
            } else {
                fputs("Apple Intelligence is not available on this device\n", stderr)
                Foundation.exit(1)
            }
        }

        // Read StructuredInsights JSON from stdin
        guard let inputData = Optional(FileHandle.standardInput.availableData),
              !inputData.isEmpty else {
            fputs("Error: No input data on stdin\n", stderr)
            Foundation.exit(1)
        }

        guard let inputJSON = String(data: inputData, encoding: .utf8) else {
            fputs("Error: Invalid UTF-8 input\n", stderr)
            Foundation.exit(1)
        }

        // Parse the JSON to extract key fields for prompt
        guard let parsed = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] else {
            fputs("Error: Invalid JSON input\n", stderr)
            Foundation.exit(1)
        }

        let date = parsed["date"] as? String ?? "未知日期"
        let period = parsed["period"] as? String ?? "daily"

        // Build prompt
        let prompt: String
        if period == "weekly" {
            prompt = """
            以下是我 \(date) 起一周的行为统计数据（JSON格式）。请用中文分析我的一周行为模式，给出有洞察力的总结和建议。

            要求：
            1. 分析主要时间花费方向和趋势变化
            2. 指出有价值的行为模式或习惯
            3. 给出 2-3 条具体可操作的建议
            4. 语气友好专业，像一个了解我的 AI 助手
            5. 控制在 400 字以内

            数据：
            \(inputJSON)
            """
        } else {
            prompt = """
            以下是我 \(date) 的行为统计数据（JSON格式）。请用中文分析我今天的行为模式，给出有洞察力的总结和建议。

            要求：
            1. 分析主要时间花费方向
            2. 指出跨源关联（比如浏览+AI对话的主题重叠）
            3. 发现主题切换的规律
            4. 给出 1-2 条具体可操作的建议
            5. 语气友好专业，像一个了解我的 AI 助手
            6. 控制在 300 字以内

            数据：
            \(inputJSON)
            """
        }

        // Call Apple Intelligence
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            fputs("Apple Intelligence is not available\n", stderr)
            Foundation.exit(1)
        }

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: String.self)
            print(response)
        } catch {
            fputs("AI generation failed: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }
}
