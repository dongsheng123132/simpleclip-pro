import Foundation
import NaturalLanguage

/// Standalone PII redactor for LifeClip.
/// Uses NSDataDetector (phone, address) + regex (email, API keys) + NLTagger (personal names).
/// 100% local processing — no network requests.
struct PIIRedactor {
    /// Redact PII from the given text. Returns sanitized text.
    static func redact(_ text: String) -> String {
        var result = text

        // 1. NSDataDetector: phone numbers, addresses
        let checkingTypes: NSTextCheckingResult.CheckingType = [.phoneNumber, .address]
        if let detector = try? NSDataDetector(types: checkingTypes.rawValue) {
            let matches = detector.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                if match.resultType == .phoneNumber {
                    result.replaceSubrange(range, with: "[phone]")
                } else if match.resultType == .address {
                    result.replaceSubrange(range, with: "[address]")
                }
            }
        }

        // 2. Regex: email addresses
        if let emailRegex = try? NSRegularExpression(pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}") {
            let range = NSRange(result.startIndex..., in: result)
            result = emailRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "[email]")
        }

        // 3. Regex: API keys and tokens
        if let skRegex = try? NSRegularExpression(pattern: "\\bsk-[A-Za-z0-9]{20,}\\b") {
            let range = NSRange(result.startIndex..., in: result)
            result = skRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "[api_key]")
        }
        if let ghpRegex = try? NSRegularExpression(pattern: "\\bghp_[A-Za-z0-9]{36,}\\b") {
            let range = NSRange(result.startIndex..., in: result)
            result = ghpRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "[api_key]")
        }

        // 4. Regex: Chinese ID card (18 digits)
        if let idRegex = try? NSRegularExpression(pattern: "\\b\\d{6}(19|20)\\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])\\d{3}[\\dXx]\\b") {
            let range = NSRange(result.startIndex..., in: result)
            result = idRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "[id_card]")
        }

        // 5. NLTagger: personal names
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = result
        let tagRange = result.startIndex..<result.endIndex
        var nameRanges: [Range<String.Index>] = []
        tagger.enumerateTags(in: tagRange, unit: .word, scheme: .nameType, options: [.omitPunctuation, .omitWhitespace, .joinNames]) { tag, tokenRange in
            if tag == .personalName {
                nameRanges.append(tokenRange)
            }
            return true
        }
        for range in nameRanges.reversed() {
            result.replaceSubrange(range, with: "[name]")
        }

        return result
    }
}
