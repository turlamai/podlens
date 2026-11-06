import SwiftUI

// MARK: - Detail shell

struct DetailView: View {
    @EnvironmentObject private var store: PodLensStore
    @Binding var columnVisibility: NavigationSplitViewVisibility

    var body: some View {
        Group {
            if let episode = store.selectedEpisode {
                EpisodeDetailView(episode: episode, columnVisibility: $columnVisibility)
            } else {
                EmptyStateView(
                    icon: "text.book.closed",
                    title: L("selectEpisodeTitle"),
                    message: L("selectEpisode"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.canvas)
    }
}

struct EpisodeDetailView: View {
    @EnvironmentObject private var store: PodLensStore
    let episode: Episode
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Environment(\.openSettings) private var openSettings
    @State private var showUnderstand = false

    var body: some View {
        VStack(spacing: 0) {
            EpisodeHero(episode: episode,
                        columnVisibility: $columnVisibility,
                        onUnderstand: { showUnderstand = true },
                        openSettings: { openSettings() })
            Divider().overlay(Palette.hairline)
            TranscriptToolbar()
            Divider().overlay(Palette.hairline)
            TranscriptReader(episode: episode,
                             onUnderstand: { showUnderstand = true },
                             openSettings: { openSettings() })
        }
        .background(Palette.canvas)
        .sheet(isPresented: $showUnderstand) {
            UnderstandSheet(episode: episode) {
                showUnderstand = false
                store.startJob("pipeline", episode: episode)
            }
            .environmentObject(store)
        }
        .task {
            if store.security == nil { await store.refreshSecurity() }
        }
    }
}

// MARK: - Hero

struct EpisodeHero: View {
    @EnvironmentObject private var store: PodLensStore
    let episode: Episode
    @Binding var columnVisibility: NavigationSplitViewVisibility
    let onUnderstand: () -> Void
    let openSettings: () -> Void

    private var job: PodLensStore.Job? { store.runningJob(for: episode.id) }
    private var configured: Bool { store.security?.configured ?? true }

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            ArtworkView(url: store.selectedFeed?.artworkURL ?? "",
                        seed: store.selectedFeed?.title ?? episode.title,
                        cornerRadius: Radius.artwork)
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)

            VStack(alignment: .leading, spacing: 5) {
                Text(episode.title)
                    .font(Typeface.display)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                MetaLine(parts: [store.selectedFeed?.title ?? "",
                                 formatPubDate(episode.pubDisplay),
                                 formatDuration(Double(episode.durationSec) ?? 0)])

                if !episode.description.isEmpty {
                    Text(episode.description)
                        .font(Typeface.callout)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(2)
                        .padding(.top, 1)
                }

                actionRow
                    .padding(.top, Space.xxs)

                if let job {
                    jobRow(job)
                        .padding(.top, 2)
                } else if let hint = estimateHint {
                    Text(hint)
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkTertiary)
                        .padding(.top, 1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { geometry in
                ArtworkBackdrop(url: store.selectedFeed?.artworkURL ?? "",
                                seed: store.selectedFeed?.title ?? episode.title,
                                opacity: 0.24)
                    .overlay(Palette.canvas.opacity(0.35))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: Space.xs) {
            if understood {
                Label(L("understood"), systemImage: "checkmark.seal.fill")
                    .font(Typeface.caption.weight(.medium))
                    .foregroundStyle(Palette.positive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Palette.positive.opacity(0.10), in: Capsule())
            } else if configured {
                Button(action: onUnderstand) {
                    Label(L("pipeline"), systemImage: "wand.and.stars")
                }
                .buttonStyle(ProminentButtonStyle())
                .fixedSize()
                .disabled(job != nil)
                .help(estimateHint ?? L("pipeline"))
                .accessibilityIdentifier("UnderstandButton")
            } else {
                Button {
                    openSettings()
                } label: {
                    Label(L("configureAI"), systemImage: "key")
                }
                .buttonStyle(ProminentButtonStyle())
                .help(L("configureAIHint"))
            }

            Menu {
                if episode.downloaded {
                    Button(L("removeAudio"), role: .destructive) {
                        store.withEpisode(episode.id) { api in
                            _ = try? await api.episode_remove_audio(id: episode.id)
                        }
                    }
                } else {
                    Button(L("download")) {
                        store.startJob("download", episode: episode)
                    }
                }
                Button(episode.done ? L("markUnplayed") : L("markPlayed")) {
                    store.markEpisode(episode, done: !episode.done)
                }
                if let feed = store.selectedFeed {
                    Divider()
                    Button(feed.title) { store.sidebarItem = .feed(feed) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(L("more"))

            Spacer()

            Button {
                withAnimation(Motion.gentle) {
                    let next: NavigationSplitViewVisibility =
                        columnVisibility == .detailOnly ? .all : .detailOnly
                    columnVisibility = next
                    store.focusMode = next == .detailOnly
                }
            } label: {
                Image(systemName: columnVisibility == .detailOnly
                      ? "arrow.down.right.and.arrow.up.left"
                      : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityIdentifier("FocusListeningButton")
            .accessibilityLabel(columnVisibility == .detailOnly ? L("focusExit") : L("focusEnter"))
            .help(columnVisibility == .detailOnly ? L("focusExitHint") : L("focusEnterHint"))
        }
    }

    private func jobRow(_ job: PodLensStore.Job) -> some View {
        HStack(spacing: Space.xs) {
            ProgressView(value: Double(job.pct), total: 100)
                .progressViewStyle(.linear)
                .tint(Palette.accent)
                .frame(width: 132)
            Text(jobLabel(job))
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
            Button(L("cancel")) { store.cancelJob(for: episode.id) }
                .buttonStyle(.plain)
                .font(Typeface.micro.weight(.medium))
                .foregroundStyle(Palette.accent)
                .accessibilityIdentifier("CancelJobButton")
        }
        .accessibilityElement(children: .combine)
    }

    private func jobLabel(_ job: PodLensStore.Job) -> String {
        let stage: String
        switch job.kind {
        case "download": stage = L("downloading")
        case "transcribe": stage = L("transcribing")
        case "translate": stage = L("translating")
        case "summarize": stage = L("summarizing")
        default: stage = L("pipeline")
        }
        let detail = job.message.isEmpty ? "" : " · \(job.message)"
        return "\(stage) \(job.pct)%\(detail)"
    }

    private var understood: Bool {
        episode.transcriptStatus == "done"
            && episode.hasTranslation
            && (episode.summaryStatus == "done" || store.estimate?.summarized == true)
    }

    private var estimateHint: String? {
        guard let est = store.estimate, !est.summarized else { return nil }
        if est.transcriptKnown, let chars = est.chars {
            return String(format: L("pipelineCostKnown"), chars)
        }
        return L("pipelineCostUnknown")
    }
}

// MARK: - Toolbar

/// Three reading modes in the platform's segmented rhythm. A system Picker
/// stretches its intrinsic width with long localizations, which pushed the
/// leading segment under the content column; this keeps the control fixed.
struct ModeSelector: View {
    @Binding var selection: TranscriptMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TranscriptMode.allCases) { mode in
                Button {
                    withAnimation(Motion.quick) { selection = mode }
                } label: {
                    Text(mode.label)
                        .font(Typeface.micro.weight(.semibold))
                        .foregroundStyle(selection == mode ? .white : Palette.inkSecondary)
                        .frame(width: 66, height: 22)
                        .background(selection == mode ? Palette.accent : Color.clear,
                                    in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Palette.surfaceRaised, in: Capsule())
        .overlay { Capsule().strokeBorder(Palette.hairline, lineWidth: 0.6) }
        .frame(width: 206)
    }
}

struct TranscriptToolbar: View {
    @EnvironmentObject private var store: PodLensStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.xs) {
                modeControl
                Spacer()
                translateButton
                followButton(compact: false)
                currentButton(compact: false)
            }
            HStack(spacing: Space.xs) {
                modeControl
                Spacer()
                followButton(compact: true)
                currentButton(compact: true)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 7)
        .background(Palette.canvas)
    }

    @ViewBuilder
    private var modeControl: some View {
        if store.translationAvailable {
            ModeSelector(selection: $store.transcriptMode)
                .accessibilityLabel(L("readingMode"))
        } else {
            Text(L("originalOnly"))
                .font(Typeface.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private var translateButton: some View {
        Button {
            store.transcriptMode = .original
            openSettings()
        } label: {
            Image(systemName: "character.book.closed")
        }
        .buttonStyle(RoundIconButtonStyle())
        .help(L("translateInSettings"))
        .accessibilityLabel(L("translateInSettings"))
    }

    @ViewBuilder
    private func followButton(compact: Bool) -> some View {
        Button {
            store.followsTranscript.toggle()
            if store.followsTranscript { store.requestScrollToCurrent() }
        } label: {
            if compact {
                Image(systemName: "location.fill")
            } else {
                Label(L("followTranscript"), systemImage: "location.fill")
            }
        }
        .buttonStyle(QuietButtonStyle(promotes: store.followsTranscript))
        .accessibilityIdentifier("FollowTranscriptButton")
        .accessibilityLabel(L("followTranscript"))
        .accessibilityAddTraits(store.followsTranscript ? .isSelected : [])
        .help(L("followTranscriptHint"))
        .fixedSize()
    }

    @ViewBuilder
    private func currentButton(compact: Bool) -> some View {
        Button {
            store.followsTranscript = true
            store.requestScrollToCurrent()
        } label: {
            if compact {
                Image(systemName: "scope")
            } else {
                Label(L("returnToCurrent"), systemImage: "scope")
            }
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityIdentifier("ReturnToCurrentButton")
        .accessibilityLabel(L("returnToCurrent"))
        .help(L("returnToCurrentHint"))
        .fixedSize()
    }
}

// MARK: - Reading surface

struct TranscriptReader: View {
    @EnvironmentObject private var store: PodLensStore
    let episode: Episode
    let onUnderstand: () -> Void
    let openSettings: () -> Void
    @FocusState private var focusedSegment: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if let summary = store.summary {
                        SummaryCard(summary: summary)
                            .padding(.bottom, Space.md)
                    }

                    if store.segments.isEmpty {
                        transcriptPlaceholder
                            .frame(maxWidth: .infinity, minHeight: 260)
                    } else {
                        ForEach(store.segments) { segment in
                            SegmentRow(segment: segment,
                                       active: store.currentSegmentIndex() == segment.id,
                                       mode: store.transcriptMode,
                                       focused: $focusedSegment)
                                .id(segment.id)
                                .onTapGesture { activate(segment) }
                                .onKeyPress(.return) {
                                    activate(segment)
                                    return .handled
                                }
                                .onKeyPress(.space) {
                                    activate(segment)
                                    return .handled
                                }
                        }
                    }
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .frame(maxWidth: 780, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .onAppear { scrollToCurrent(proxy, animated: false) }
            .onChange(of: store.currentTime) { _, _ in
                guard store.followsTranscript else { return }
                scrollToCurrent(proxy, animated: true)
            }
            .onChange(of: store.scrollRequest) { _, value in
                guard value > 0 else { return }
                if let index = store.currentSegmentIndex() {
                    withAnimation(Motion.gentle) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }

    private func activate(_ segment: Segment) {
        store.followsTranscript = true
        store.seek(to: segment.start)
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let index = store.segmentToFollow() ?? store.currentSegmentIndex() else { return }
        if animated {
            withAnimation(Motion.gentle) { proxy.scrollTo(index, anchor: .center) }
        } else {
            proxy.scrollTo(index, anchor: .center)
        }
    }

    @ViewBuilder
    private var transcriptPlaceholder: some View {
        let configured = store.security?.configured ?? true
        if configured {
            EmptyStateView(
                icon: "text.bubble",
                title: L("noTranscriptTitle"),
                message: L("noTranscript"),
                actionTitle: L("pipeline"),
                action: onUnderstand)
        } else {
            EmptyStateView(
                icon: "key",
                title: L("needAPIKeyTitle"),
                message: L("needAPIKeyBody"),
                actionTitle: L("openSettings"),
                action: openSettings)
        }
    }
}

struct SegmentRow: View {
    let segment: Segment
    let active: Bool
    let mode: TranscriptMode
    @FocusState.Binding var focused: Int?
    @State private var hovering = false

    private var showOriginal: Bool { mode != .translation }
    private var showTranslation: Bool { mode != .original && !segment.translation.isEmpty }

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Text(formatClock(segment.start))
                .font(Typeface.mono(10))
                .foregroundStyle(active ? Palette.accent : Palette.inkTertiary)
                .frame(width: 44, alignment: .leading)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                if showOriginal {
                    Text(segment.text)
                        .font(Typeface.reading(17))
                        .foregroundStyle(active ? Palette.ink : Palette.ink.opacity(0.82))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if showTranslation {
                    Text(segment.translation)
                        .font(Typeface.body)
                        .foregroundStyle(active ? Palette.accentDeep : Palette.inkSecondary)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(active ? Palette.highlight.opacity(0.9)
                      : (hovering ? Palette.surfaceRaised.opacity(0.7) : Color.clear))
        }
        .overlay(alignment: .leading) {
            if active {
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: 2.5)
                    .padding(.vertical, 8)
            }
        }
        .contentShape(Rectangle())
        .focusable()
        .focused($focused, equals: segment.id)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("TranscriptSegment-\(segment.id)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(L("transcriptSeekHint"))
    }
}

// MARK: - Summary

struct SummaryCard: View {
    let summary: PodLensStore.Summary

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                Text(L("summaryTitle"))
                    .font(Typeface.micro.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Palette.accent)
                Spacer()
                if !summary.topics.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(summary.topics.prefix(4), id: \.self) { topic in
                            Text(topic)
                                .font(Typeface.micro)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Palette.highlight, in: Capsule())
                                .foregroundStyle(Palette.accentDeep)
                        }
                    }
                }
            }

            if !summary.tldr.isEmpty {
                Text(summary.tldr)
                    .font(Typeface.reading(18))
                    .lineSpacing(4)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !summary.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(summary.keyPoints.enumerated()), id: \.offset) { _, point in
                        HStack(alignment: .top, spacing: 7) {
                            Circle()
                                .fill(Palette.accent.opacity(0.65))
                                .frame(width: 4, height: 4)
                                .padding(.top, 7)
                            Text(point)
                                .font(Typeface.body)
                                .foregroundStyle(Palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !summary.quotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(summary.quotes.enumerated()), id: \.offset) { _, quote in
                        HStack(alignment: .top, spacing: 8) {
                            Rectangle()
                                .fill(Palette.accent.opacity(0.5))
                                .frame(width: 2)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("“\(quote.0)”")
                                    .font(Typeface.reading(15))
                                    .italic()
                                    .foregroundStyle(Palette.ink)
                                if !quote.1.isEmpty {
                                    Text(quote.1)
                                        .font(Typeface.caption)
                                        .foregroundStyle(Palette.inkSecondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: Space.md)
    }
}

// MARK: - Understand sheet

struct UnderstandSheet: View {
    @EnvironmentObject private var store: PodLensStore
    @Environment(\.dismiss) private var dismiss
    let episode: Episode
    let start: () -> Void

    private var estimate: PodLensStore.Estimate? { store.estimate }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Palette.highlight)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("pipeline")).font(Typeface.title)
                    Text(episode.title)
                        .font(Typeface.callout)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                }
            }

            VStack(spacing: 0) {
                stageRow(L("stageTranscribe"), done: estimate?.transcriptKnown ?? false,
                         detail: (estimate?.sentences).map { String(format: L("sentencesCount"), $0) } ?? L("stageNeededFirst"))
                Divider().overlay(Palette.hairline)
                stageRow(L("stageTranslate"), done: estimate?.translated ?? false,
                         detail: (estimate?.chars).map { String(format: L("charactersCount"), $0) } ?? L("stageDependsOnTranscript"))
                Divider().overlay(Palette.hairline)
                stageRow(L("stageSummarize"), done: estimate?.summarized ?? false,
                         detail: L("stageIncluded"))
            }
            .cardSurface(padding: Space.xs)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "creditcard")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.warning)
                Text(costNote)
                    .font(Typeface.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(L("cancel")) { dismiss() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button {
                    start()
                } label: {
                    Label(L("startUnderstanding"), systemImage: "arrow.right")
                }
                .buttonStyle(ProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.lg)
        .frame(width: 460)
        .background(Palette.canvas)
    }

    private func stageRow(_ title: String, done: Bool, detail: String) -> some View {
        HStack(spacing: Space.xs) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(done ? Palette.positive : Palette.inkTertiary)
            Text(title)
                .font(Typeface.callout.weight(.medium))
            Spacer()
            Text(done ? L("stageReady") : detail)
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Space.xs)
        .padding(.vertical, 7)
    }

    private var costNote: String {
        guard let estimate else { return L("pipelineCostUnknown") }
        if estimate.transcriptKnown, let chars = estimate.chars {
            return String(format: L("pipelineCostNote"), chars)
        }
        return L("pipelineCostNoteUnknown")
    }
}
