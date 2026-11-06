import SwiftUI
import RivetEmbedding
import RivetRuntime
import RivetSystem

@main
struct PodLensApp: App {
    @StateObject private var model = AppModel()

    init() {
        // Cover art streams through the shared session; without a real
        // disk cache every relaunch refetches the whole library's art.
        // The disk path must be absolute — a bare name lands in whatever
        // directory the app happened to start from.
        let megabyte = 1024 * 1024
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        URLCache.shared = URLCache(memoryCapacity: 32 * megabyte,
                                   diskCapacity: 256 * megabyte,
                                   diskPath: cacheDir.appendingPathComponent("podlens-artwork").path)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(model.language)
                .tint(Palette.accent)
                .environmentObject(model)
                .frame(minWidth: 1000, minHeight: 640)
                .task { model.start() }
        }
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L("addFeed")) {
                    NotificationCenter.default.post(name: .podlensAddFeed, object: nil)
                }
                .keyboardShortcut("n")
            }
            CommandGroup(after: .newItem) {
                Button(L("menuRefreshAll")) { model.store.refreshAll() }
                    .keyboardShortcut("r")
            }
            // Family menu convention: Check for Updates… lives in the App
            // menu directly below the system About item.
            CommandGroup(after: .appInfo) {
                Button(L("menuCheckUpdates")) { model.checkForUpdates(manual: true) }
                    .keyboardShortcut("u")
            }
            CommandMenu(L("menuGo")) {
                Button(L("homeTab")) { model.store.sidebarItem = .home }
                    .keyboardShortcut("1")
                Button(L("discover")) { model.store.sidebarItem = .discover }
                    .keyboardShortcut("2")
                Button(L("showsTab")) { model.store.sidebarItem = .shows }
                    .keyboardShortcut("3")
                Button(L("recentlyUpdated")) { model.store.sidebarItem = .recent }
                    .keyboardShortcut("4")
                Button(L("downloadedTab")) { model.store.sidebarItem = .downloaded }
                    .keyboardShortcut("5")
            }
            CommandMenu(L("menuPlayback")) {
                Button(model.store.playing ? L("pause") : L("play")) {
                    model.store.togglePlay()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(model.store.selectedEpisode == nil)

                Divider()

                Button(L("skipBack")) { model.store.skip(by: -15) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Button(L("skipForward")) { model.store.skip(by: 30) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])

                Menu(L("speed")) {
                    ForEach(PodLensStore.playbackRates, id: \.self) { rate in
                        Button(String(format: "%g×", rate)) { model.store.setRate(rate) }
                    }
                }

                Button(L("focusEnter")) {
                    NotificationCenter.default.post(
                        name: .podlensFocusListening, object: nil,
                        userInfo: ["focus": !model.store.focusMode])
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environmentObject(model)
                .environmentObject(model.store)
                .tint(Palette.accent)
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var ready = false
    @Published var bootStatus = L("booting") {
        didSet { store.bootStatus = bootStatus }
    }
    @Published var showSettings = false
    @Published var language = currentLanguage()

    var pendingUpdateManifest: UpdateService.Manifest? {
        if case .success(.available(let m)) = store.updateOutcome {
            return m
        }
        return nil
    }

    var showSettingsBinding: Binding<Bool> {
        Binding(get: { [weak self] in self?.showSettings ?? false },
                set: { [weak self] in self?.showSettings = $0 })
    }

    let store = PodLensStore()

    private var backend: EmbeddedRacketBackend?

    init() {
        if let lang = ProcessInfo.processInfo.environment["PODLENS_LANG"],
           !lang.trimmingCharacters(in: .whitespaces).isEmpty {
            setLanguage(lang)
            language = lang
        }
    }

    func applyLanguage(_ lang: String) {
        guard lang != language else { return }
        setLanguage(lang)
        language = lang
    }

    func start() {
        guard backend == nil else { return }
        do {
            let config = try Self.runtimeConfiguration()
            let backend = EmbeddedRacketBackend(configuration: config)
            self.backend = backend

            // start() only wires pipes and spawns the Racket thread (the
            // runtime boots off-main), so it is safe to call synchronously;
            // the plain Task below inherits start()'s MainActor isolation —
            // nothing non-Sendable crosses an actor boundary. The previous
            // Task.detached + MainActor.run form fails Swift 6.1's sendability
            // rules on the Intel (macos-15-intel) release runner.
            try backend.start(onEvent: { [weak self] name, value in
                guard let event = try? RivetEvent.decode(name: name, value: value) else { return }
                Task { @MainActor [weak self] in
                    self?.store.handleEvent(event)
                }
            })
            let api = RivetAPI(client: backend.client)
            Task { [weak self] in
                await self?.finishBoot(api: api)
            }
        } catch {
            ready = false
            bootStatus = L("backendError") + " \(error)"
        }
    }

    /// Main-actor boot completion (Task { } above inherits the isolation).
    private func finishBoot(api: RivetAPI) async {
        store.bind(api: api)
        ready = true
        bootStatus = L("ready")
        // Structured, sequential boot: credentials and home data land before
        // the resume and update checks, and no unstructured tasks race the RPCs.
        await store.refreshSecurity()
        await store.loadFeeds()
        await store.loadCatalog()
        await store.resumeLast()
        silentUpdateCheck()
        SnapshotService.runIfRequested(store: store, model: self)
    }

    func checkForUpdates(manual: Bool) {
        Task {
            let outcome = await UpdateServices.shared.check(manual: manual)
            await MainActor.run { store.updateOutcome = outcome }
        }
    }

    func installUpdate(_ manifest: UpdateService.Manifest) async {
        do {
            try await UpdateServices.shared.downloadAndInstall(manifest)
        } catch {
            store.statusLine = L("updateInstallFailed") + " \(error)"
        }
    }

    private func silentUpdateCheck() {
        Task {
            let outcome = await UpdateServices.shared.check(manual: false)
            if case .success(.available) = outcome {
                await MainActor.run { store.updateOutcome = outcome }
            }
        }
    }

    private static func runtimeConfiguration() throws -> EmbeddedRacketConfiguration {
        let executable = Bundle.main.executableURL
            ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL

        // Packaged apps keep Racket data in Contents/Resources. `raco rivet
        // dev` runs the staged executable directly, where runtime/res live
        // next to the executable.
        let roots = [
            Bundle.main.resourceURL,
            executable.deletingLastPathComponent()
        ].compactMap { $0 }

        for root in roots {
            let runtime = root.appendingPathComponent("runtime", isDirectory: true)
            let core = root.appendingPathComponent("res/core.zo")
            let required = [
                runtime.appendingPathComponent("petite.boot"),
                runtime.appendingPathComponent("scheme.boot"),
                runtime.appendingPathComponent("racket.boot"),
                core
            ]
            if required.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) {
                return EmbeddedRacketConfiguration(
                    executable: executable,
                    petiteBoot: required[0],
                    schemeBoot: required[1],
                    racketBoot: required[2],
                    core: core,
                    moduleName: RivetGeneratedConfig.moduleName,
                    entryName: RivetGeneratedConfig.entryName
                )
            }
        }

        throw HostError.missingRuntimeLayout(
            roots.map(\.path).joined(separator: ", ")
        )
    }
}

/// The app-wide update service, held at file scope instead of as an
/// AppModel stored property: the Intel release runner's older swiftc
/// (6.1.2) crashes in SILGen while emitting `UpdateService()` inside
/// AppModel members — the stored property initializer, the lazy getter
/// and a global `static let` initializer all crash (reproduced locally
/// with a swift.org 6.1.2 toolchain; the stack dies in
/// emitLazyGlobalInitializer → emitApply). A memoized computed property
/// keeps the lifetime the property had — exactly one instance, created
/// on first touch — without any global initializer to lower, and the
/// constructor is invoked with explicit arguments so the crash-prone
/// default-argument machinery stays out of the call site.
@MainActor
enum UpdateServices {
    private static var _shared: UpdateService?
    static var shared: UpdateService {
        if let shared = _shared { return shared }
        let shared = UpdateService(
            feedURL: UpdateService.manifestURL,
            sessionConfiguration: nil,
            keyBase64: UpdateService.publicKeyBase64,
            currentVersion: nil,
            bundleURL: nil)
        _shared = shared
        return shared
    }
}

enum HostError: Error, CustomStringConvertible {
    case missingRuntimeLayout(String)

    var description: String {
        switch self {
        case .missingRuntimeLayout(let roots):
            return "missing Rivet runtime/res layout under: \(roots)"
        }
    }
}
