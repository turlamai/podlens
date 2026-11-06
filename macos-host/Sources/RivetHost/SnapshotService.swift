import AppKit
import SwiftUI

/// Offscreen evidence capture.
///
/// CI runners (and headless review machines) cannot grant Screen Recording
/// to `screencapture`, but a window can always render itself into a bitmap.
/// `PODLENS_SNAPSHOT_DIR` turns this on after boot: the app walks the core
/// surfaces at a requested window size, writes PNGs, then exits. It is a
/// review tool with no effect on normal launches.
@MainActor
enum SnapshotService {
    static func runIfRequested(store: PodLensStore, model: AppModel) {
        guard let dir = ProcessInfo.processInfo.environment["PODLENS_SNAPSHOT_DIR"],
              !dir.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let size = requestedSize()
        Task { @MainActor in
                await captureAll(store: store, model: model,
                             directory: URL(fileURLWithPath: dir), size: size)
                NSApp.terminate(nil)
        }
    }

    private static func requestedSize() -> NSSize {
        guard let raw = ProcessInfo.processInfo.environment["PODLENS_SNAPSHOT_SIZE"] else {
            return NSSize(width: 1280, height: 800)
        }
        let parts = raw.lowercased().split(separator: "x")
        if parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]) {
            return NSSize(width: width, height: height)
        }
        return NSSize(width: 1280, height: 800)
    }

    private static func captureAll(store: PodLensStore,
                                   model: AppModel,
                                   directory: URL,
                                   size: NSSize) async {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let window = await waitForWindow() else { return }
        window.setContentSize(NSSize(width: size.width, height: size.height))
        window.orderFrontRegardless()
        try? await Task.sleep(nanoseconds: 700_000_000)
        store.dismissToast()

        // Home
        store.sidebarItem = .home
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        capture(window: window, to: directory.appendingPathComponent("home.png"))

        // Feed episode list: the show that owns the finished transcript.
        if let item = store.recentEpisodes.first(where: { $0.transcriptStatus == "done" }),
           let feed = store.feeds.first(where: { $0.id == item.feedId }) {
            store.selectFeed(feed)
            store.sidebarItem = .feed(feed)
            try? await Task.sleep(nanoseconds: 900_000_000)
            capture(window: window, to: directory.appendingPathComponent("episodes.png"))
        }

        // Reading surface, focus mode on. Pick an episode with a finished
        // bilingual transcript so the evidence shows the product, not a
        // download placeholder.
        if let item = store.recentEpisodes.first(where: {
            $0.transcriptStatus == "done" && $0.hasTranslation
        }) ?? store.recentEpisodes.first {
            store.selectRecent(item, autoplay: false)
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            store.focusMode = true
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            capture(window: window, to: directory.appendingPathComponent("reading.png"))
            store.focusMode = false
        }

        // Discover
        store.sidebarItem = .discover
        try? await Task.sleep(nanoseconds: 900_000_000)
        capture(window: window, to: directory.appendingPathComponent("discover.png"))

        // Settings is a separate scene. Host its view directly so the
        // evidence does not depend on menu automation.
        if ProcessInfo.processInfo.environment["PODLENS_SNAPSHOT_SETTINGS"] != "0" {
            await captureSettings(store: store, model: model, directory: directory)
        }

        // Optional alternate size for responsive evidence.
        if let raw = ProcessInfo.processInfo.environment["PODLENS_SNAPSHOT_SIZE_ALT"] {
            let parts = raw.lowercased().split(separator: "x")
            if parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]) {
                window.setContentSize(NSSize(width: width, height: height))
                store.sidebarItem = .home
                try? await Task.sleep(nanoseconds: 900_000_000)
                capture(window: window, to: directory.appendingPathComponent("home-compact.png"))
            }
        }
    }

    private static func captureSettings(store: PodLensStore,
                                        model: AppModel,
                                        directory: URL) async {
        await store.loadSettings()
        let root = SettingsView()
            .environmentObject(store)
            .environmentObject(model)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 660, height: 640)
        let window = NSWindow(contentRect: hosting.frame,
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.contentView = hosting
        window.title = "Settings"
        window.orderFrontRegardless()
        try? await Task.sleep(nanoseconds: 900_000_000)
        capture(window: window, to: directory.appendingPathComponent("settings.png"))
        window.orderOut(nil)
        window.close()
    }

    private static func waitForWindow(timeout: TimeInterval = 20) async -> NSWindow? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }) {
                return window
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return NSApp.windows.first
    }

    private static func capture(window: NSWindow, to url: URL) {
        guard let view = window.contentView else { return }
        view.layoutSubtreeIfNeeded()
        let bounds = view.bounds
        guard bounds.width > 10, bounds.height > 10 else { return }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        view.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }
}
