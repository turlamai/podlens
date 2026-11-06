import AppKit
import SwiftUI

/// Native Settings. Grouped by task instead of a raw key/value table: the
/// window talks about "Speech-to-text model", never `asr-model`, and never
/// prints a credential back into a text field or a log.
struct SettingsView: View {
    @EnvironmentObject private var store: PodLensStore
    @EnvironmentObject private var model: AppModel
    @State private var values: [String: String] = [:]
    @State private var apiKeyDraft = ""
    @State private var clearKey = false
    @State private var revealKey = false
    @State private var loaded = false
    @State private var savedMessage: String?
    @State private var errorMessage: String?
    @State private var testResult: ProviderProbe?
    @State private var testing = false
    @State private var tab: SettingsTab

    init() {
        let raw = ProcessInfo.processInfo.environment["PODLENS_SETTINGS_TAB"] ?? "general"
        _tab = State(initialValue: SettingsTab(rawValue: raw) ?? .general)
    }

    private enum SettingsTab: String, CaseIterable, Identifiable {
        case general, intelligence, advanced, about
        var id: String { rawValue }
        var label: String {
            switch self {
            case .general: return L("settingsGeneral")
            case .intelligence: return L("settingsAI")
            case .advanced: return L("settingsAdvanced")
            case .about: return L("settingsAbout")
            }
        }
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .intelligence: return "sparkles"
            case .advanced: return "slider.horizontal.3"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                generalPane.tabItem { Label(SettingsTab.general.label, systemImage: SettingsTab.general.icon) }
                    .tag(SettingsTab.general)
                intelligencePane.tabItem { Label(SettingsTab.intelligence.label, systemImage: SettingsTab.intelligence.icon) }
                    .tag(SettingsTab.intelligence)
                advancedPane.tabItem { Label(SettingsTab.advanced.label, systemImage: SettingsTab.advanced.icon) }
                    .tag(SettingsTab.advanced)
                aboutPane.tabItem { Label(SettingsTab.about.label, systemImage: SettingsTab.about.icon) }
                    .tag(SettingsTab.about)
            }
            .padding(.top, Space.sm)

            Divider().overlay(Palette.hairline)

            HStack(spacing: Space.xs) {
                if store.settingsSaving {
                    ProgressView().controlSize(.small)
                } else if let savedMessage {
                    Label(savedMessage, systemImage: "checkmark.circle.fill")
                        .font(Typeface.caption)
                        .foregroundStyle(Palette.positive)
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(Typeface.caption)
                        .foregroundStyle(Palette.danger)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                Spacer()
                Button(L("settingsClose")) { NSApp.keyWindow?.close() }
                    .buttonStyle(QuietButtonStyle())
                Button(L("saveChanges")) { save() }
                    .buttonStyle(ProminentButtonStyle())
                    .disabled(!loaded || store.settingsSaving || !hasChanges)
                    .accessibilityIdentifier("SettingsSaveButton")
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm)
            .background(.bar)
        }
        .frame(width: 660, height: 640)
        .background(Palette.canvas)
        .task { await load() }
    }

    // MARK: General

    private var generalPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                settingsGroup(L("settingsLibrary"), subtitle: nil) {
                    HStack(spacing: Space.xl) {
                        stat(L("showsTab"), "\(store.feeds.count)")
                        stat(L("episodes"), "\(store.feeds.reduce(0) { $0 + $1.episodeCount })")
                        Spacer()
                        Button(L("refresh")) { store.refreshAll() }
                            .buttonStyle(QuietButtonStyle())
                    }
                }

                settingsGroup(L("settingsGeneral"), subtitle: L("settingsGeneralHint")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("language"))
                            .font(Typeface.callout.weight(.medium))
                        SegmentButtons(
                            options: [("zh", "简体中文"), ("en", "English")],
                            selection: model.language) { lang in
                                model.applyLanguage(lang)
                                values["ui-lang"] = lang
                                invalidateStatus()
                            }
                            .frame(width: 196)
                        Text(L("languageHint"))
                            .font(Typeface.micro)
                            .foregroundStyle(Palette.inkTertiary)
                    }

                    Toggle(isOn: Binding(
                        get: { (values["check-updates-enabled"] ?? store.settingValue("check-updates-enabled")) != "false" },
                        set: { values["check-updates-enabled"] = $0 ? "true" : "false" })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("autoUpdates"))
                                .font(Typeface.callout.weight(.medium))
                            Text(L("autoUpdatesHint"))
                                .font(Typeface.micro)
                                .foregroundStyle(Palette.inkTertiary)
                        }
                    }
                    .toggleStyle(.switch)

                    HStack(spacing: Space.xs) {
                        Image(systemName: "bell")
                            .foregroundStyle(Palette.inkTertiary)
                        Text(L("refreshHint"))
                            .font(Typeface.micro)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
            .padding(Space.lg)
        }
    }

    // MARK: Intelligence

    private var intelligencePane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                settingsGroup(L("settingsProvider"), subtitle: L("settingsProviderHint")) {
                    SettingsField(label: L("apiBase"), hint: L("apiBaseHint"),
                                  text: binding("api-base"),
                                  identifier: "SettingsAPIBaseField")
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(L("apiKey"))
                                .font(Typeface.callout.weight(.medium))
                            Spacer()
                            if store.security?.configured == true {
                                Button(L("removeKey")) {
                                    clearKey = true
                                    apiKeyDraft = ""
                                    revealKey = false
                                }
                                .buttonStyle(.plain)
                                .font(Typeface.micro)
                                .foregroundStyle(Palette.danger)
                            }
                        }
                        HStack(spacing: 6) {
                            Group {
                                if revealKey {
                                    TextField(L("apiKeyPlaceholder"), text: $apiKeyDraft)
                                } else {
                                    SecureField(L("apiKeyPlaceholder"), text: $apiKeyDraft)
                                }
                            }
                            .textFieldStyle(.plain)
                            .font(Typeface.body)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, 7)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                                    .strokeBorder(Palette.hairline, lineWidth: 0.7)
                            }
                            .accessibilityLabel(L("apiKey"))
                            .accessibilityIdentifier("SettingsAPIKeyField")

                            Button {
                                revealKey.toggle()
                            } label: {
                                Image(systemName: revealKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(RoundIconButtonStyle())
                            .help(revealKey ? L("hideKey") : L("showKey"))
                        }
                        Text(clearKey ? L("keyWillBeRemoved")
                             : (store.security?.configured == true ? L("keySavedReplaceHint")
                                : L("keyEmptyHint")))
                            .font(Typeface.micro)
                            .foregroundStyle(clearKey ? Palette.danger : Palette.inkTertiary)

                        HStack(spacing: 5) {
                            Image(systemName: store.security?.secure == true ? "lock.fill" : "doc.badge.gearshape")
                                .font(.system(size: 9))
                            Text(storageNote)
                                .font(Typeface.micro)
                                .lineLimit(2)
                        }
                        .foregroundStyle(store.security?.secure == true ? Palette.positive : Palette.warning)
                    }
                }

                settingsGroup(L("settingsModels"), subtitle: nil) {
                    SettingsField(label: L("chatModel"), hint: L("chatModelHint"),
                                  text: binding("chat-model"),
                                  identifier: "SettingsChatModelField")
                    SettingsField(label: L("asrModel"), hint: L("asrModelHint"),
                                  text: binding("asr-model"),
                                  identifier: "SettingsASRModelField")
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("targetLanguage"))
                            .font(Typeface.callout.weight(.medium))
                        SegmentButtons(
                            options: [("zh", "简体中文"), ("en", "English")],
                            selection: values["target-lang"] ?? store.settingValue("target-lang")) { lang in
                                values["target-lang"] = lang
                                invalidateStatus()
                            }
                            .frame(width: 196)
                    }
                }

                settingsGroup(L("settingsConnection"), subtitle: L("settingsConnectionHint")) {
                    HStack(spacing: Space.xs) {
                        Button {
                            runTest()
                        } label: {
                            if testing {
                                Label(L("testingConnection"), systemImage: "hourglass")
                            } else {
                                Label(L("testConnection"), systemImage: "bolt.horizontal.circle")
                            }
                        }
                        .buttonStyle(QuietButtonStyle(promotes: true))
                        .disabled(testing || store.security?.configured != true || clearKey)

                        if let result = testResult {
                            HStack(spacing: 4) {
                                Image(systemName: result.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                Text(result.message)
                                    .lineLimit(3)
                                    .textSelection(.enabled)
                            }
                            .font(Typeface.micro)
                            .foregroundStyle(result.ok ? Palette.positive : Palette.danger)
                        }
                    }
                }
            }
            .padding(Space.lg)
        }
    }

    // MARK: Advanced

    private var advancedPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                settingsGroup(L("settingsPipeline"), subtitle: L("settingsPipelineHint")) {
                    StepperField(label: L("chunkSeconds"), hint: L("chunkSecondsHint"),
                                 value: binding("asr-chunk-seconds"), range: 120...1800, step: 60)
                    StepperField(label: L("maxChars"), hint: L("maxCharsHint"),
                                 value: binding("max-transcript-chars"), range: 4000...200000, step: 2000)
                    StepperField(label: L("searchLimit"), hint: L("searchLimitHint"),
                                 value: binding("search-limit"), range: 5...100, step: 5)
                }

                settingsGroup(L("settingsStorage"), subtitle: nil) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("dataFolder"))
                            .font(Typeface.callout.weight(.medium))
                        Text(dataFolderPath)
                            .font(Typeface.mono(10))
                            .foregroundStyle(Palette.inkSecondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        HStack(spacing: Space.xs) {
                            Button(L("revealInFinder")) {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: dataFolderPath)])
                            }
                            .buttonStyle(QuietButtonStyle())
                            Button(L("reloadLibrary")) {
                                Task { await store.loadFeeds(); await store.loadCatalog() }
                            }
                            .buttonStyle(QuietButtonStyle())
                        }
                    }
                }
            }
            .padding(Space.lg)
        }
    }

    // MARK: About

    private var aboutPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                settingsGroup(nil, subtitle: nil) {
                    HStack(spacing: Space.sm) {
                        BrandMark(size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PodLens")
                                .font(Typeface.title)
                            Text("v\(version)")
                                .font(Typeface.caption)
                                .foregroundStyle(Palette.inkSecondary)
                            Text(L("appTagline"))
                                .font(Typeface.caption)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    Text(L("aboutLicense"))
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkTertiary)
                    HStack(spacing: Space.md) {
                        Link(L("aboutWebsite"), destination: URL(string: "https://podlens.jrtx.site")!)
                        Link(L("aboutReportIssue"), destination: URL(string: "https://github.com/turlamai/podlens/issues")!)
                        Link(L("aboutReleases"), destination: URL(string: "https://github.com/turlamai/podlens/releases")!)
                    }
                    .font(Typeface.caption)
                    .foregroundStyle(Palette.accent)
                }
                settingsGroup(L("updateTitle"), subtitle: nil) {
                    Text(L("updateHint"))
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkSecondary)
                    HStack(spacing: Space.xs) {
                        Button(L("menuCheckUpdates")) {
                            model.checkForUpdates(manual: true)
                        }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityIdentifier("SettingsCheckUpdatesButton")
                        if case .some(.success(.upToDate)) = store.updateOutcome {
                            Text(L("updateUpToDate"))
                                .font(Typeface.micro)
                                .foregroundStyle(Palette.positive)
                        }
                    }
                }
            }
            .padding(Space.lg)
        }
    }

    // MARK: Shared pieces

    @ViewBuilder
    private func settingsGroup<Content: View>(_ title: String?,
                                              subtitle: String?,
                                              @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if let title {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Typeface.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typeface.micro)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: Space.sm)
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { values[key] ?? store.settingValue(key) },
                set: { values[key] = $0; invalidateStatus() })
    }

    private var hasChanges: Bool {
        clearKey
            || !apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || values["chat-model"] != originalValues["chat-model"]
            || values["asr-model"] != originalValues["asr-model"]
            || values["api-base"] != originalValues["api-base"]
            || values["target-lang"] != originalValues["target-lang"]
            || values["ui-lang"] != originalValues["ui-lang"]
            || values["check-updates-enabled"] != originalValues["check-updates-enabled"]
            || values["asr-chunk-seconds"] != originalValues["asr-chunk-seconds"]
            || values["max-transcript-chars"] != originalValues["max-transcript-chars"]
            || values["search-limit"] != originalValues["search-limit"]
    }

    @State private var originalValues: [String: String] = [:]

    private var storageNote: String {
        guard let security = store.security else { return L("storageUnknown") }
        if !security.configured {
            return L("storageNotConfigured")
        }
        if security.secure {
            return String(format: L("storageSecureNote"), security.label)
        }
        return String(format: L("storageFileNote"), security.label)
    }

    private var dataFolderPath: String {
        if let override = ProcessInfo.processInfo.environment["PODLENS_DATA_DIR"],
           !override.trimmingCharacters(in: .whitespaces).isEmpty {
            return override
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".podlens", isDirectory: true).path
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? RivetGeneratedConfig.version
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(Typeface.title)
                .monospacedDigit()
            Text(label)
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private func load() async {
        await store.loadSettings()
        for row in store.settingsRows where row.count >= 2 {
            let key = row[0]
            let value = row[1]
            if key == "api-key" { continue }
            // Backend ui-lang and the host language are the same setting in
            // this window; present the host's current choice.
            values[key] = key == "ui-lang" ? model.language : value
        }
        originalValues = values
        loaded = true
        errorMessage = store.settingsError
    }

    private func invalidateStatus() {
        savedMessage = nil
        if errorMessage != nil { errorMessage = nil }
        testResult = nil
    }

    private func save() {
        savedMessage = nil
        errorMessage = nil
        let payload = values
        let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let error = await store.saveSettings(payload, apiKey: key, clearKey: clearKey)
            if let error {
                errorMessage = error
            } else {
                savedMessage = L("settingsSaved")
                apiKeyDraft = ""
                clearKey = false
                revealKey = false
                await store.loadSettings()
                for row in store.settingsRows where row.count >= 2 && row[0] != "api-key" {
                    values[row[0]] = row[1]
                }
                originalValues = values
            }
        }
    }

    private func runTest() {
        testing = true
        testResult = nil
        Task {
            let result = await store.testProvider()
            testResult = result
            testing = false
        }
    }
}

// MARK: - Field primitives

struct SegmentButtons: View {
    let options: [(String, String)]
    let selection: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    onSelect(value)
                } label: {
                    Text(label)
                        .font(Typeface.caption.weight(.medium))
                        .foregroundStyle(selection == value ? .white : Palette.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(selection == value ? Palette.accent : Color.clear,
                                    in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Palette.surfaceRaised, in: Capsule())
        .overlay { Capsule().strokeBorder(Palette.hairline, lineWidth: 0.6) }
    }
}

struct SettingsField: View {
    let label: String
    var hint: String?
    @Binding var text: String
    var identifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(Typeface.callout.weight(.medium))
            TextField(label, text: $text)
                .textFieldStyle(.plain)
                .font(Typeface.body)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, 7)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 0.7)
                }
                .accessibilityLabel(label)
                .accessibilityIdentifier(identifier ?? "")
            if let hint, !hint.isEmpty {
                Text(hint)
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }
}

struct StepperField: View {
    let label: String
    var hint: String?
    @Binding var value: String
    let range: ClosedRange<Int>
    let step: Int

    private var number: Int {
        min(max(Int(value) ?? range.lowerBound, range.lowerBound), range.upperBound)
    }

    var body: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typeface.callout.weight(.medium))
                if let hint {
                    Text(hint)
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            Spacer()
            Stepper(value: Binding(
                get: { number },
                set: { value = String($0) }), in: range, step: step) {
                Text("\(number)")
                    .font(Typeface.mono(11))
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(width: 46, alignment: .trailing)
            }
        }
    }
}
