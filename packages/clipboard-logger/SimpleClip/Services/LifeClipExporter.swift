import Foundation
import SwiftData

/// Exports clipboard items to ~/.lifeclip/events/ as JSONL for the LifeClip ecosystem.
/// Runs on a 5-minute timer, exporting only new items since last export.
@MainActor
final class LifeClipExporter {
    private let modelContext: ModelContext
    private var timer: Timer?
    private var lastExportDate: Date

    private static let lifeclipDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".lifeclip/events")
    }()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.lastExportDate = Self.loadLastExportDate()
    }

    func startExporting() {
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: Self.lifeclipDir, withIntermediateDirectories: true)
        // Export immediately on start
        exportNewItems()
        // Then every 5 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.exportNewItems()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        NSLog("✓ LifeClip 导出服务已启动")
    }

    func stopExporting() {
        timer?.invalidate()
        timer = nil
    }

    private func exportNewItems() {
        let since = lastExportDate
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate<ClipboardItem> { item in
                item.timestamp > since
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        guard let items = try? modelContext.fetch(descriptor), !items.isEmpty else { return }

        // Group by date
        let calendar = Calendar.current
        var grouped: [String: [ClipboardItem]] = [:]
        for item in items {
            let dateStr = Self.dateString(item.timestamp)
            grouped[dateStr, default: []].append(item)
        }

        // Write to JSONL files
        for (dateStr, dayItems) in grouped {
            let fileURL = Self.lifeclipDir.appendingPathComponent("\(dateStr).jsonl")
            // Read existing hashes for dedup
            let existingHashes = Self.readExistingHashes(from: fileURL)

            var lines: [String] = []
            for item in dayItems {
                guard !existingHashes.contains(item.contentHash) else { continue }
                let event = Self.toLifeClipEvent(item)
                if let jsonData = try? JSONSerialization.data(withJSONObject: event),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    lines.append(jsonString)
                }
            }

            if !lines.isEmpty {
                let data = (lines.joined(separator: "\n") + "\n").data(using: .utf8) ?? Data()
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    if let handle = try? FileHandle(forWritingTo: fileURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? data.write(to: fileURL)
                }
                NSLog("📋 LifeClip: exported \(lines.count) items to \(dateStr).jsonl")
            }
        }

        lastExportDate = items.last?.timestamp ?? lastExportDate
        Self.saveLastExportDate(lastExportDate)
    }

    // MARK: - Helpers

    private static func toLifeClipEvent(_ item: ClipboardItem) -> [String: Any] {
        let typeStr: String
        switch item.type {
        case .text: typeStr = "text"
        case .url: typeStr = "url"
        case .image: typeStr = "image"
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return [
            "id": item.id.uuidString,
            "source": "clipboard",
            "type": typeStr,
            "timestamp": formatter.string(from: item.timestamp),
            "content": String(PIIRedactor.redact(item.content).prefix(500)),
            "metadata": [
                "isPinned": item.isPinned,
                "copyCount": item.copyCount
            ],
            "contentHash": item.contentHash
        ]
    }

    private static func readExistingHashes(from fileURL: URL) -> Set<String> {
        guard let data = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        var hashes = Set<String>()
        for line in data.split(separator: "\n") {
            if let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
               let hash = json["contentHash"] as? String {
                hashes.insert(hash)
            }
        }
        return hashes
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    // MARK: - Persistence

    private static let lastExportKey = "LifeClipLastExportDate"

    private static func loadLastExportDate() -> Date {
        UserDefaults.standard.object(forKey: lastExportKey) as? Date ?? Date.distantPast
    }

    private static func saveLastExportDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastExportKey)
    }
}
