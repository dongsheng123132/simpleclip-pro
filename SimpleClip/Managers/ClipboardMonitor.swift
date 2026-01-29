import Foundation
import AppKit
import Combine
import ApplicationServices
import SwiftData

class ClipboardMonitor: NSObject, ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastActiveApp: NSRunningApplication?
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.lastChangeCount = NSPasteboard.general.changeCount
        super.init()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivation),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func handleAppActivation(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastActiveApp = app
        }
    }

    func startMonitoring() {
        DispatchQueue.main.async {
            self.timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkClipboard()
                }
            }
            self.timer?.tolerance = 0.5
            if let timer = self.timer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        let pasteboard = NSPasteboard.general

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            if let url = URL(string: string), url.scheme != nil {
                addItem(ClipboardItem(content: string, type: .url))
            } else {
                addItem(ClipboardItem(content: string, type: .text))
            }
        } else if let image = pasteboard.data(forType: .tiff), let imagePath = saveImage(image) {
            addItem(ClipboardItem(content: imagePath, type: .image))
        }
    }

    private func addItem(_ item: ClipboardItem) {
        // 确保在主线程操作 ModelContext
        if !Thread.isMainThread {
            Task { @MainActor in
                addItem(item)
            }
            return
        }
        
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.contentHash == item.contentHash },
            sortBy: []
        )
        descriptor.fetchLimit = 1
        if (try? modelContext.fetch(descriptor).first) != nil { return }
        modelContext.insert(item)
        try? modelContext.save()
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.type {
        case .text, .url:
            pasteboard.setString(item.content, forType: .string)
        case .image:
            if let image = NSImage(contentsOfFile: item.content) {
                pasteboard.writeObjects([image])
            }
        }
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func copyAndPaste(_ item: ClipboardItem) {
        copyToClipboard(item)
        pasteToFrontmostApp()
    }

    private func pasteToFrontmostApp() {
        if let app = lastActiveApp {
            app.activate(options: [])
            usleep(100000)
        } else {
            NSApp.hide(nil)
            usleep(100000)
        }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    func deleteItem(_ item: ClipboardItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        try? modelContext.save()
    }

    func clearHistory() {
        do {
            try modelContext.delete(model: ClipboardItem.self, where: #Predicate { !$0.isPinned })
            try modelContext.save()
        } catch {
            print("Failed to clear history: \(error)")
        }
    }

    private func saveImage(_ imageData: Data) -> String? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let clipboardDir = appSupport.appendingPathComponent("SimpleClip/Images")
        try? fileManager.createDirectory(at: clipboardDir, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).png"
        let filePath = clipboardDir.appendingPathComponent(filename)
        if let image = NSImage(data: imageData),
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: filePath)
            return filePath.path
        }
        return nil
    }
}
