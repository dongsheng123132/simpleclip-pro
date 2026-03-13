import Foundation
import SwiftData
import CryptoKit

/// Exports clipboard events to LifeClip JSONL format.
/// Writes to ~/.lifeclip/events/YYYY-MM-DD.jsonl (append mode).
@MainActor
final class LifeClipExporter {
    private let modelContext: ModelContext
    private var timer: Timer?

    /// Key for UserDefaults: last export timestamp
    private static let lastExportDateKey = "lifeClipLastExportDate"
    /// Key for UserDefaults: total exported count
    private static let exportedCountKey = "lifeClipExportedCount"
    /// Key for UserDefaults: export enabled toggle
    static let enabledKey = "lifeClipExportEnabled"

    private static let eventsDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".lifeclip/events")
    }()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Timer

    func startIfEnabled() {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return }
        start()
    }

    func start() {
        timer?.invalidate()
        // Export immediately, then every 5 minutes
        exportNewItems()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.exportNewItems()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Export Logic

    func exportNewItems() {
        let lastExportDate = UserDefaults.standard.object(forKey: Self.lastExportDateKey) as? Date ?? Date.distantPast
        NSLog("LifeClip: exporting items since \(lastExportDate)")

        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate<ClipboardItem> { item in
                item.timestamp > lastExportDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        do {
            let items = try modelContext.fetch(descriptor)
            NSLog("LifeClip: found \(items.count) items to export")
            guard !items.isEmpty else { return }

        // Group by date string for per-day files
        let grouped = Dictionary(grouping: items) { item in
            Self.dateString(from: item.timestamp)
        }

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: Self.eventsDirectory, withIntermediateDirectories: true)

        // Track exported hashes to deduplicate within this batch
        var exportedHashes = Set<String>()
        var newExportCount = 0

        for (dateStr, dayItems) in grouped {
            let fileURL = Self.eventsDirectory.appendingPathComponent("\(dateStr).jsonl")

            // Load existing hashes from the file to avoid duplicates
            let existingHashes = Self.loadExistingHashes(from: fileURL)

            var lines: [String] = []
            for item in dayItems {
                let hash = item.contentHash
                if existingHashes.contains(hash) || exportedHashes.contains(hash) {
                    continue
                }
                if let line = Self.toJSONL(item: item) {
                    lines.append(line)
                    exportedHashes.insert(hash)
                    newExportCount += 1
                }
            }

            if !lines.isEmpty {
                Self.appendLines(lines, to: fileURL)
            }
        }

        if newExportCount > 0 {
            // Update last export date to the latest item's timestamp
            if let latestTimestamp = items.last?.timestamp {
                UserDefaults.standard.set(latestTimestamp, forKey: Self.lastExportDateKey)
            }
            let total = (UserDefaults.standard.integer(forKey: Self.exportedCountKey)) + newExportCount
            UserDefaults.standard.set(total, forKey: Self.exportedCountKey)
            NSLog("✅ LifeClip: exported \(newExportCount) clipboard events (\(total) total)")
        }
        } catch {
            NSLog("❌ LifeClip: fetch failed: \(error)")
        }
    }

    // MARK: - JSONL Formatting

    private static func toJSONL(item: ClipboardItem) -> String? {
        // Skip image items (file paths, not useful as text events)
        guard item.type != .image else { return nil }

        // Skip sensitive items if user opted in
        if item.isSensitive && UserDefaults.standard.bool(forKey: "exportSkipSensitive") {
            return nil
        }

        let content = PIIDetector.redact(String(item.decryptedContent.prefix(500)))
        let type = item.type.rawValue // "text" or "url"

        let event: [String: Any] = [
            "id": item.id.uuidString,
            "source": "clipboard",
            "type": type,
            "timestamp": iso8601String(from: item.timestamp),
            "content": content,
            "contentHash": item.contentHash,
            "metadata": [
                "isPinned": item.isPinned,
                "copyCount": item.copyCount
            ] as [String: Any],
            "tags": ["clipboard"]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: event, options: [.sortedKeys]),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }

    // MARK: - File Operations

    private static func appendLines(_ lines: [String], to fileURL: URL) {
        let text = lines.joined(separator: "\n") + "\n"
        guard let data = text.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Append mode
            guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private static func loadExistingHashes(from fileURL: URL) -> Set<String> {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }
        var hashes = Set<String>()
        for line in content.split(separator: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let hash = json["contentHash"] as? String else { continue }
            hashes.insert(hash)
        }
        return hashes
    }

    // MARK: - Helpers

    private static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    // MARK: - Status Info

    var lastExportDate: Date? {
        UserDefaults.standard.object(forKey: Self.lastExportDateKey) as? Date
    }

    var exportedCount: Int {
        UserDefaults.standard.integer(forKey: Self.exportedCountKey)
    }
}
