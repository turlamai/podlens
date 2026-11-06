import AppKit
import SwiftUI

typealias Episode = PodLensStore.Episode
typealias Feed = PodLensStore.Feed
typealias Segment = PodLensStore.Segment

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAddFeed = false

    var body: some View {
        Group {
            if model.ready {
                MainWindow()
            } else {
                BootView()
            }
        }
        .environmentObject(model.store)
        .sheet(isPresented: $showAddFeed) {
            AddFeedSheet()
                .environmentObject(model.store)
        }
        .sheet(isPresented: model.showSettingsBinding) {
            // Fallback for the in-window Settings command; the real path is
            // the native Settings scene (⌘,), which this window-level sheet
            // mirrors for older hosts.
            SettingsView()
                .environmentObject(model.store)
                .environmentObject(model)
        }
        .sheet(isPresented: Binding(
            get: { model.store.updateOutcome != nil },
            set: { if !$0 { model.store.updateOutcome = nil } })) {
            UpdateSheet()
                .environmentObject(model)
                .environmentObject(model.store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .podlensAddFeed)) { _ in
            showAddFeed = true
        }
    }
}

extension Notification.Name {
    static let podlensAddFeed = Notification.Name("podlens.addFeed")
    static let podlensFocusListening = Notification.Name("podlens.focusListening")
}

/// The window shell. One navigation model for every page: library on the
/// left, the selected lane in the middle, one reading surface on the right.
struct MainWindow: View {
    @EnvironmentObject private var store: PodLensStore

    /// Focus mode is a first-class layout state, not a split-view gesture:
    /// the two leading panes animate to zero width so the reading surface —
    /// and its scroll position, selection and player — never reload.
    private var focusBinding: Binding<NavigationSplitViewVisibility> {
        Binding(get: { store.focusMode ? .detailOnly : .all },
                set: { store.focusMode = $0 == .detailOnly })
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let sidebarWidth: CGFloat = store.focusMode
                    ? 0
                    : min(236, max(212, geometry.size.width * 0.185))
                let contentWidth: CGFloat = store.focusMode
                    ? 0
                    : min(500, max(430, geometry.size.width * 0.38))

                HStack(spacing: 0) {
                    SidebarView()
                        .frame(width: sidebarWidth)
                        .opacity(store.focusMode ? 0 : 1)
                        .clipped()
                        .allowsHitTesting(!store.focusMode)

                    Divider()
                        .opacity(store.focusMode ? 0 : 1)
                        .frame(width: store.focusMode ? 0 : 0.7)

                    ContentColumn()
                        .frame(width: contentWidth)
                        .opacity(store.focusMode ? 0 : 1)
                        .clipped()
                        .allowsHitTesting(!store.focusMode)

                    Divider()
                        .opacity(store.focusMode ? 0 : 1)
                        .frame(width: store.focusMode ? 0 : 0.7)

                    DetailView(columnVisibility: focusBinding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            PlayerBar()
        }
        .background(Palette.canvas)
        .overlay(alignment: .bottom) {
            if let message = store.toastMessage {
                ToastView(message: message) { store.dismissToast() }
                    .padding(.bottom, 104)
                    .padding(.horizontal, Space.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .podlensFocusListening)) { note in
            // Focus is an instant layout change. Animating the two pane
            // widths makes headless Intel compositing fall into Metal and
            // abort the app; state preservation matters more than the fade.
            let requested = note.userInfo?["focus"] as? Bool ?? !store.focusMode
            store.focusMode = requested
        }
    }
}

struct ToastView: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.accent)
            Text(message)
                .font(Typeface.callout)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.inkTertiary)
            .accessibilityLabel(L("dismiss"))
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, 8)
        .background(Palette.surface, in: Capsule())
        .overlay { Capsule().strokeBorder(Palette.hairline, lineWidth: 0.7) }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}

struct BootView: View {
    @EnvironmentObject private var store: PodLensStore

    var body: some View {
        VStack(spacing: Space.md) {
            BrandMark(size: 52)
            Text("PodLens")
                .font(Typeface.display)
                .foregroundStyle(Palette.ink)
            HStack(spacing: Space.xs) {
                ProgressView().controlSize(.small)
                Text(store.bootStatus.isEmpty ? L("booting") : store.bootStatus)
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.canvas)
    }
}

struct BrandMark: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: [Palette.accent, Palette.accentDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "waveform")
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject private var store: PodLensStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            list
            footer
        }
        .navigationTitle("PodLens")
    }

    private var list: some View {
        List {
            Section {
                SidebarNavRow(icon: "house", title: L("homeTab"),
                              selected: store.sidebarItem == .home) {
                    select(.home)
                }
                SidebarNavRow(icon: "sparkles.rectangle.stack", title: L("discover"),
                              selected: store.sidebarItem == .discover) {
                    select(.discover)
                }
            }

            Section(L("librarySection")) {
                SidebarNavRow(icon: "clock", title: L("recentlyUpdated"),
                              selected: store.sidebarItem == .recent) {
                    select(.recent)
                }
                SidebarNavRow(icon: "square.grid.2x2", title: L("showsTab"),
                              selected: store.sidebarItem == .shows) {
                    select(.shows)
                }
                SidebarNavRow(icon: "arrow.down.circle", title: L("downloadedTab"),
                              selected: store.sidebarItem == .downloaded) {
                    select(.downloaded)
                }
            }

            Section(L("subscriptionsSection")) {
                ForEach(store.feeds) { feed in
                    SidebarNavRow(icon: "dot.radiowaves.left.and.right",
                                  title: feed.title,
                                  subtitle: feed.latestTitle,
                                  artworkURL: feed.artworkURL,
                                  badge: feed.unplayed,
                                  selected: store.sidebarItem == .feed(feed)) {
                        select(.feed(feed))
                    }
                    .contextMenu {
                        Button(L("removeFeed"), role: .destructive) {
                            store.removeFeed(feed)
                        }
                    }
                }
                Button {
                    NotificationCenter.default.post(name: .podlensAddFeed, object: nil)
                } label: {
                    Label(L("addFeed"), systemImage: "plus")
                        .font(Typeface.callout)
                        .foregroundStyle(Palette.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 3, leading: 14, bottom: 3, trailing: 10))
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("PodLens")
    }

    private func select(_ item: SidebarItem) {
        store.sidebarItem = item
        if case .feed(let feed) = item { store.selectFeed(feed) }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.xxs) {
                Button {
                    NotificationCenter.default.post(name: .podlensAddFeed, object: nil)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(RoundIconButtonStyle())
                .help(L("addFeed"))
                .accessibilityLabel(L("addFeed"))

                Button {
                    store.refreshAll()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(RoundIconButtonStyle())
                .help(L("menuRefreshAll"))
                .accessibilityLabel(L("menuRefreshAll"))

                Spacer()

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(RoundIconButtonStyle())
                .help(L("menuSettings"))
                .accessibilityLabel(L("menuSettings"))
            }
            .padding(.horizontal, Space.xs)
            .padding(.vertical, 6)
            .background(Palette.surface)
            .hairlineTop()
        }
    }
}

struct SidebarNavRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var artworkURL: String? = nil
    var badge: Int = 0
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let artworkURL {
                    ArtworkView(url: artworkURL, seed: title, cornerRadius: 5)
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(selected ? Palette.accent : Palette.inkSecondary)
                        .frame(width: 18)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Typeface.callout.weight(selected ? .semibold : .regular))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Typeface.micro)
                            .foregroundStyle(Palette.inkTertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Spacer(minLength: 2)
                CountBadge(count: badge, emphasized: selected)
                    .layoutPriority(0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                selected ? Palette.highlight
                    : (hovering ? Palette.surfaceRaised.opacity(0.6) : Color.clear),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        .listRowBackground(Color.clear)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

// MARK: - Content routing

struct ContentColumn: View {
    @EnvironmentObject private var store: PodLensStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = pageTitle {
                Text(title)
                    .font(Typeface.hero)
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.md)
                    .padding(.bottom, Space.xxs)
                    .lineLimit(1)
            }
            Group {
                switch store.sidebarItem {
                case .home: HomeView()
                case .discover: DiscoverView()
                case .shows: ShowsGridPage()
                case .recent: RecentEpisodesPage()
                case .downloaded: DownloadedPage()
                case .feed: FeedEpisodesPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Palette.canvas)
    }

    private var pageTitle: String? {
        switch store.sidebarItem {
        case .home: return L("homeTab")
        case .discover: return L("discover")
        case .shows: return L("showsTab")
        case .recent: return L("recentlyUpdated")
        case .downloaded: return L("downloadedTab")
        case .feed: return nil // the feed header owns the title
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject private var store: PodLensStore

    var body: some View {
        if store.feeds.isEmpty {
            EmptyStateView(
                icon: "sparkles.rectangle.stack",
                title: L("welcomeTitle"),
                message: L("emptyHome"),
                actionTitle: L("goToDiscover"),
                action: { store.sidebarItem = .discover })
            .navigationTitle(L("homeTab"))
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Space.xl) {
                    if let next = store.upNext.first {
                        ContinueCard(item: next)
                    }

                    VStack(alignment: .leading, spacing: Space.sm) {
                        LaneTitle(title: L("upNextLane"))
                        UpNextLane()
                    }

                    VStack(alignment: .leading, spacing: Space.sm) {
                        LaneTitle(title: L("myShowsLane"),
                                  actionTitle: L("seeAll"),
                                  action: { store.sidebarItem = .shows })
                        ShowsGrid(shows: store.homeShows)
                    }

                    VStack(alignment: .leading, spacing: Space.sm) {
                        LaneTitle(title: L("latestEpisodesLane"),
                                  actionTitle: L("seeAll"),
                                  action: { store.sidebarItem = .recent })
                        VStack(spacing: 0) {
                            ForEach(Array(store.recentEpisodes.prefix(6))) { item in
                                EpisodeRow(data: EpisodeRowData(recent: item, showFeed: true),
                                           selected: store.selectedEpisode?.id == item.id,
                                           onOpen: { store.selectRecent(item, autoplay: false) },
                                           onPlay: { store.selectRecent(item) })
                                Divider().overlay(Palette.hairline)
                            }
                        }
                        .cardSurface(padding: Space.xxs)
                    }
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.md)
                .padding(.bottom, Space.xxl)
                .frame(maxWidth: 920, alignment: .leading)
            }
            .navigationTitle(L("homeTab"))
        }
    }
}

struct ContinueCard: View {
    @EnvironmentObject private var store: PodLensStore
    let item: RecentEpisode
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Space.lg) {
            ArtworkView(url: item.artworkURL, seed: item.feedTitle, cornerRadius: Radius.artwork)
                .frame(width: 128, height: 128)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(item.positionSec > 5 ? L("continueListening") : L("startListening"))
                    .font(Typeface.micro.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Palette.accent)

                Text(item.title)
                    .font(Typeface.title)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                MetaLine(parts: [item.feedTitle, formatPubDate(item.pubDisplay),
                                 formatDuration(item.duration)])

                if let fraction = progressFraction(position: item.positionSec, duration: item.duration) {
                    HStack(spacing: Space.xs) {
                        ProgressLine(fraction: fraction)
                            .frame(width: 132)
                        Text(formatRemaining(item.duration - item.positionSec))
                            .font(Typeface.mono(10))
                            .foregroundStyle(Palette.inkTertiary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.top, 2)
                }

                HStack(spacing: Space.xs) {
                    Button {
                        store.selectRecent(item)
                    } label: {
                        Label(store.playing && store.selectedEpisode?.id == item.id
                              ? L("pause") : L("play"),
                              systemImage: store.playing && store.selectedEpisode?.id == item.id
                              ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(ProminentButtonStyle())

                    Button {
                        store.selectRecent(item, autoplay: false)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(QuietButtonStyle())
                    .help(L("openEpisode"))
                    .accessibilityLabel(L("openEpisode"))
                }
                .padding(.top, Space.xxs)
            }

            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .background(Palette.highlight.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
                .strokeBorder(Palette.accent.opacity(hovering ? 0.35 : 0.16), lineWidth: 0.8)
        }
        .animation(Motion.quick, value: hovering)
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .onTapGesture { store.selectRecent(item, autoplay: false) }
    }
}

struct ProgressLine: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.hairline)
                Capsule().fill(Palette.accent)
                    .frame(width: max(3, geometry.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

struct UpNextLane: View {
    @EnvironmentObject private var store: PodLensStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Space.sm) {
                ForEach(store.upNext) { item in
                    UpNextCard(item: item)
                }
            }
            .padding(.vertical, Space.xxs)
        }
    }
}

struct UpNextCard: View {
    @EnvironmentObject private var store: PodLensStore
    let item: RecentEpisode
    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkBackdrop(url: item.artworkURL, seed: item.feedTitle, opacity: 0.9)
                .frame(width: 236, height: 132)
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.72)],
                           startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.feedTitle)
                    .font(Typeface.micro.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                Text(item.title)
                    .font(Typeface.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 9))
                    Text(formatDuration(item.duration))
                }
                .font(Typeface.micro.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.34), in: Capsule())
            }
            .padding(Space.sm)
        }
        .frame(width: 236, height: 132)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(.white.opacity(hovering ? 0.35 : 0.12), lineWidth: 0.8)
        }
        .contentShape(Rectangle())
        .onTapGesture { store.selectRecent(item, autoplay: false) }
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
        .scaleEffect(hovering ? 1.015 : 1)
        .contextMenu {
            Button(L("pipeline")) {
                store.selectRecent(item, autoplay: false)
                if let episode = store.selectedEpisode {
                    store.startJob("pipeline", episode: episode)
                }
            }
            Button(item.downloaded ? L("removeAudio") : L("download")) {
                if item.downloaded {
                    store.withEpisode(item.id) { api in
                        _ = try? await api.episode_remove_audio(id: item.id)
                    }
                } else {
                    store.withEpisode(item.id) { api in
                        _ = try? await api.episode_download(id: item.id)
                    }
                }
            }
            Button(item.done ? L("markUnplayed") : L("markPlayed")) {
                store.setRecentDone(item, done: !item.done)
            }
        }
    }
}

struct ShowsGrid: View {
    @EnvironmentObject private var store: PodLensStore
    let shows: [Feed]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 124), spacing: Space.sm)],
                  alignment: .leading, spacing: Space.md) {
            ForEach(shows) { feed in
                ShowTile(feed: feed)
            }
        }
    }
}

struct ShowTile: View {
    @EnvironmentObject private var store: PodLensStore
    let feed: Feed
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ArtworkView(url: feed.artworkURL, seed: feed.title, cornerRadius: Radius.artwork)
                    .aspectRatio(1, contentMode: .fit)
                if feed.unplayed > 0 {
                    CountBadge(count: feed.unplayed, emphasized: true)
                        .padding(6)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(feed.title)
                    .font(Typeface.callout.weight(.medium))
                    .lineLimit(1)
                Text(String(format: L("episodesCount"), feed.episodeCount))
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectFeed(feed)
            store.sidebarItem = .feed(feed)
        }
        .onHover { hovering = $0 }
        .hoverLift(scale: hovering ? 1.02 : 1)
        .contextMenu {
            Button(L("removeFeed"), role: .destructive) {
                store.removeFeed(feed)
            }
        }
    }
}

// MARK: - Library pages

struct RecentEpisodesPage: View {
    @EnvironmentObject private var store: PodLensStore

    var body: some View {
        Group {
            if store.recentEpisodes.isEmpty {
                EmptyStateView(icon: "clock", title: L("recentEmptyTitle"),
                               message: L("recentEmpty"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.recentEpisodes) { item in
                            EpisodeRow(data: EpisodeRowData(recent: item, showFeed: true),
                                       selected: store.selectedEpisode?.id == item.id,
                                       onOpen: { store.selectRecent(item, autoplay: false) },
                                       onPlay: { store.selectRecent(item) })
                            Divider().overlay(Palette.hairline)
                        }
                    }
                    .cardSurface(padding: Space.xxs)
                    .padding(Space.lg)
                }
            }
        }
        .navigationTitle(L("recentlyUpdated"))
    }
}

struct DownloadedPage: View {
    @EnvironmentObject private var store: PodLensStore

    var body: some View {
        Group {
            if store.downloadedEpisodes.isEmpty {
                EmptyStateView(icon: "arrow.down.circle", title: L("downloadedEmptyTitle"),
                               message: L("downloadedEmpty"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.downloadedEpisodes) { item in
                            EpisodeRow(data: EpisodeRowData(recent: item, showFeed: true),
                                       selected: store.selectedEpisode?.id == item.id,
                                       onOpen: { store.selectRecent(item, autoplay: false) },
                                       onPlay: { store.selectRecent(item) })
                            Divider().overlay(Palette.hairline)
                        }
                    }
                    .cardSurface(padding: Space.xxs)
                    .padding(Space.lg)
                }
            }
        }
        .navigationTitle(L("downloadedTab"))
    }
}

struct ShowsGridPage: View {
    @EnvironmentObject private var store: PodLensStore

    var body: some View {
        ScrollView {
            if store.feeds.isEmpty {
                EmptyStateView(icon: "square.grid.2x2", title: L("showsEmptyTitle"),
                               message: L("emptyHome"),
                               actionTitle: L("goToDiscover"),
                               action: { store.sidebarItem = .discover })
                    .frame(minHeight: 320)
            } else {
                ShowsGrid(shows: store.feeds)
                    .padding(Space.lg)
            }
        }
        .navigationTitle(L("showsTab"))
    }
}

struct FeedEpisodesPage: View {
    @EnvironmentObject private var store: PodLensStore

    var body: some View {
        VStack(spacing: 0) {
            if let feed = store.selectedFeed {
                FeedHeader(feed: feed)
                Divider().overlay(Palette.hairline)
            }
            if store.episodes.isEmpty {
                EmptyStateView(icon: "waveform", title: L("recentEmptyTitle"),
                               message: L("recentEmpty"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.episodes) { episode in
                            EpisodeRow(
                                data: EpisodeRowData(episode: episode,
                                                     artworkURL: store.selectedFeed?.artworkURL ?? ""),
                                selected: store.selectedEpisode?.id == episode.id,
                                onOpen: { store.selectEpisode(episode, autoplay: false) },
                                onPlay: { store.selectEpisode(episode) })
                                .contextMenu {
                                    Button(episode.done ? L("markUnplayed") : L("markPlayed")) {
                                        store.markEpisode(episode, done: !episode.done)
                                    }
                                    if episode.downloaded {
                                        Button(L("removeAudio"), role: .destructive) {
                                            store.withEpisode(episode.id) { api in
                                                _ = try? await api.episode_remove_audio(id: episode.id)
                                            }
                                        }
                                    }
                                }
                            Divider().overlay(Palette.hairline)
                        }
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.bottom, Space.lg)
                }
            }
        }
        .background(Palette.canvas)
        .navigationTitle(store.selectedFeed?.title ?? L("episodes"))
    }
}

struct FeedHeader: View {
    @EnvironmentObject private var store: PodLensStore
    let feed: Feed

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            ArtworkView(url: feed.artworkURL, seed: feed.title, cornerRadius: Radius.artwork)
                .frame(width: 78, height: 78)
                .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(feed.title)
                    .font(Typeface.title)
                    .lineLimit(2)
                Text(feed.author)
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                HStack(spacing: Space.xs) {
                    Text(String(format: L("episodesCount"), feed.episodeCount))
                    if feed.unplayed > 0 {
                        StatusDot()
                        Text(String(format: L("unplayedCount"), feed.unplayed))
                            .foregroundStyle(Palette.accent)
                    }
                }
                .font(Typeface.micro)
                .foregroundStyle(Palette.inkSecondary)
            }
            Spacer()
            Menu {
                Button(L("menuRefreshAll")) { store.refreshAll() }
                Divider()
                Button(L("removeFeed"), role: .destructive) { store.removeFeed(feed) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(L("more"))
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }
}

// MARK: - Episode row

struct EpisodeRowData {
    let id: String
    let title: String
    let showTitle: String
    let artworkURL: String
    let pubDisplay: String
    let duration: Double
    let position: Double
    let downloaded: Bool
    let transcriptStatus: String
    let summaryStatus: String
    let hasTranslation: Bool
    let done: Bool
    let description: String

    init(episode: Episode, artworkURL: String) {
        id = episode.id
        title = episode.title
        showTitle = ""
        self.artworkURL = artworkURL
        pubDisplay = episode.pubDisplay
        duration = Double(episode.durationSec) ?? 0
        position = episode.positionSec
        downloaded = episode.downloaded
        transcriptStatus = episode.transcriptStatus
        summaryStatus = episode.summaryStatus
        hasTranslation = episode.hasTranslation
        done = episode.done
        description = episode.description
    }

    init(recent: RecentEpisode, showFeed: Bool) {
        id = recent.id
        title = recent.title
        showTitle = showFeed ? recent.feedTitle : ""
        artworkURL = recent.artworkURL
        pubDisplay = recent.pubDisplay
        duration = recent.duration
        position = recent.positionSec
        downloaded = recent.downloaded
        transcriptStatus = recent.transcriptStatus
        summaryStatus = recent.summaryStatus
        hasTranslation = recent.hasTranslation
        done = recent.done
        description = recent.description
    }
}

struct EpisodeRow: View {
    let data: EpisodeRowData
    var selected = false
    let onOpen: () -> Void
    let onPlay: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            ArtworkView(url: data.artworkURL, seed: data.title, cornerRadius: 7)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(data.title)
                    .font(Typeface.body.weight(.semibold))
                    .foregroundStyle(data.done ? Palette.inkSecondary : Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                MetaLine(parts: [data.showTitle,
                                 formatPubDate(data.pubDisplay),
                                 formatDuration(data.duration)])

                if !data.description.isEmpty {
                    Text(data.description)
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                EpisodeStatusChips(downloaded: data.downloaded,
                                   transcriptStatus: data.transcriptStatus,
                                   summaryStatus: data.summaryStatus,
                                   hasTranslation: data.hasTranslation,
                                   done: data.done)

                if let fraction = progressFraction(position: data.position, duration: data.duration) {
                    ProgressLine(fraction: fraction)
                        .frame(height: 2.5)
                        .padding(.top, 3)
                }
            }

            Spacer(minLength: Space.xs)

            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(hovering || selected ? .white : Palette.accent)
                    .frame(width: 27, height: 27)
                    .background(
                        hovering || selected ? Palette.accent : Palette.highlight,
                        in: Circle())
            }
            .buttonStyle(.plain)
            .help(L("play"))
            .accessibilityLabel(L("play"))
            .padding(.top, 10)
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, 9)
        .background(
            selected ? Palette.highlight.opacity(0.9)
                : (hovering ? Palette.surface : Color.clear),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

// MARK: - Status chips / progress

struct EpisodeStatusChips: View {
    var downloaded = false
    var transcriptStatus = "none"
    var summaryStatus = "none"
    var hasTranslation = false
    var done = false

    var body: some View {
        HStack(spacing: 7) {
            if done {
                chip("checkmark.circle.fill", color: Palette.positive, help: L("done"))
            }
            if transcriptStatus == "running" {
                chip("waveform", color: Palette.accent, help: L("transcribing"))
            } else if transcriptStatus == "cancelled" {
                chip("pause.circle", color: Palette.warning, help: L("jobCancelled"))
            } else if transcriptStatus == "error" {
                chip("exclamationmark.triangle.fill", color: Palette.danger, help: L("jobFailed"))
            } else if transcriptStatus == "done" {
                chip("text.bubble", color: Palette.accent, help: L("tooltipTranscript"))
            }
            if hasTranslation {
                chip("character.bubble", color: currentTranslationColor, help: L("tooltipTranslated"))
            }
            if summaryStatus == "done" {
                chip("sparkles", color: Palette.accent, help: L("tooltipSummarized"))
            }
            if downloaded {
                chip("arrow.down.circle.fill", color: Palette.inkTertiary, help: L("tooltipDownloaded"))
            }
        }
        .font(.system(size: 10, weight: .medium))
    }

    private var currentTranslationColor: Color {
        hasTranslation ? Palette.accent : Palette.inkTertiary
    }

    private func chip(_ icon: String, color: Color, help: String) -> some View {
        Image(systemName: icon)
            .foregroundStyle(color)
            .help(help)
            .accessibilityLabel(help)
    }
}

// MARK: - Discover

struct DiscoverView: View {
    @EnvironmentObject private var store: PodLensStore
    @State private var query = ""
    @State private var category = "all"
    @FocusState private var searchFocused: Bool

    private var categories: [String] {
        var seen: [String] = []
        for entry in store.catalog where !seen.contains(entry.category) {
            seen.append(entry.category)
        }
        return seen
    }

    private var filteredCatalog: [PodLensStore.CatalogEntry] {
        category == "all" ? store.catalog : store.catalog.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().overlay(Palette.hairline)

            if store.isSearching {
                VStack(spacing: Space.xs) {
                    ProgressView()
                    Text(L("searching")).font(Typeface.callout).foregroundStyle(Palette.inkSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.searchError {
                EmptyStateView(icon: "wifi.exclamationmark", title: L("searchFailed"),
                               message: error)
            } else if !store.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.xxs) {
                        LaneTitle(title: L("searchResults"))
                            .padding(.bottom, Space.xs)
                        ForEach(store.searchResults) { entry in
                            CatalogRow(entry: entry)
                        }
                    }
                    .padding(Space.lg)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.md) {
                        Text(L("discoverNote"))
                            .font(Typeface.callout)
                            .foregroundStyle(Palette.inkSecondary)
                            .frame(maxWidth: 520, alignment: .leading)

                        categoryChips

                        ForEach(categories.filter { category == "all" || $0 == category }, id: \.self) { name in
                            let items = store.catalog.filter { $0.category == name }
                            if !items.isEmpty {
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Text(categoryLabel(name))
                                        .font(Typeface.headline)
                                        .foregroundStyle(Palette.ink)
                                    ForEach(items) { entry in
                                        CatalogRow(entry: entry)
                                    }
                                }
                            }
                        }
                    }
                    .padding(Space.lg)
                }
            }
        }
        .navigationTitle(L("discover"))
        .task { await store.loadCatalog() }
    }

    private var searchBar: some View {
        HStack(spacing: Space.xs) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
                TextField(L("searchPlaceholder"), text: $query)
                    .textFieldStyle(.plain)
                    .font(Typeface.body)
                    .focused($searchFocused)
                    .onSubmit { runSearch() }
                if !query.isEmpty {
                    Button {
                        query = ""
                        store.searchResults = []
                        store.searchError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("clearSearch"))
                }
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 7)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(searchFocused ? Palette.accent.opacity(0.5) : Palette.hairline,
                                  lineWidth: searchFocused ? 1 : 0.7)
            }

            Button(L("search")) { runSearch() }
                .buttonStyle(QuietButtonStyle())
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: L("allCategories"), value: "all")
                ForEach(categories, id: \.self) { name in
                    chip(title: categoryLabel(name), value: name)
                }
            }
        }
    }

    private func chip(title: String, value: String) -> some View {
        Button {
            withAnimation(Motion.quick) { category = value }
        } label: {
            Text(title)
                .font(Typeface.callout)
                .foregroundStyle(category == value ? .white : Palette.inkSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(category == value ? Palette.accent : Palette.surfaceRaised, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        searchFocused = false
        store.searchDirectory(trimmed)
    }

    private func categoryLabel(_ category: String) -> String {
        switch category {
        case "tech": return L("catTech")
        case "security": return L("catSecurity")
        case "science": return L("catScience")
        case "design": return L("catDesign")
        case "business": return L("catBusiness")
        case "news": return L("catNews")
        default: return category
        }
    }
}

struct CatalogRow: View {
    @EnvironmentObject private var store: PodLensStore
    let entry: PodLensStore.CatalogEntry
    @State private var hovering = false

    private var previewing: Bool {
        store.previewLoading && store.previewEpisode?.enclosureURL == entry.url
    }

    var body: some View {
        HStack(spacing: Space.sm) {
            ArtworkView(url: entry.artworkURL, seed: entry.title, cornerRadius: 8)
                .frame(width: 62, height: 62)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(Typeface.body.weight(.semibold))
                    .lineLimit(2)
                Text(entry.description)
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: Space.xs)
            if entry.added {
                Label(L("subscribed"), systemImage: "checkmark")
                    .font(Typeface.caption.weight(.medium))
                    .foregroundStyle(Palette.positive)
            } else {
                Button {
                    store.previewFromCatalog(entry)
                } label: {
                    if previewing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "headphones")
                    }
                }
                .buttonStyle(QuietButtonStyle())
                .help(L("preview"))
                .accessibilityLabel(L("preview"))
                .disabled(store.previewLoading)

                Button(L("subscribe")) { store.addFromCatalog(entry) }
                    .buttonStyle(QuietButtonStyle(promotes: true))
                    .fixedSize()
            }
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, 9)
        .background(hovering ? Palette.surface : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

// MARK: - Add feed

struct AddFeedSheet: View {
    @EnvironmentObject private var store: PodLensStore
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @FocusState private var urlFocused: Bool

    private var isValid: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.highlight)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("addFeed"))
                        .font(Typeface.title)
                    Text(L("addFeedSubtitle"))
                        .font(Typeface.callout)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField(L("feedURL"), text: $url)
                    .textFieldStyle(.plain)
                    .font(Typeface.body)
                    .focused($urlFocused)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 8)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .strokeBorder(urlFocused ? Palette.accent.opacity(0.55) : Palette.hairline,
                                          lineWidth: urlFocused ? 1 : 0.7)
                    }
                    .onSubmit { submit() }

                HStack(spacing: Space.xs) {
                    Button {
                        if let string = NSPasteboard.general.string(forType: .string) {
                            url = string.trimmingCharacters(in: .whitespacesAndNewlines)
                            urlFocused = true
                        }
                    } label: {
                        Label(L("pasteFromClipboard"), systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.plain)
                    .font(Typeface.caption)
                    .foregroundStyle(Palette.accent)

                    Text(L("addFeedExample"))
                        .font(Typeface.caption)
                        .foregroundStyle(Palette.inkTertiary)
                        .lineLimit(1)
                }
            }

            if let error = store.addFeedError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .textSelection(.enabled)
                }
                .font(Typeface.caption)
                .foregroundStyle(Palette.danger)
                .padding(Space.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.danger.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }

            HStack {
                Spacer()
                Button(L("cancel")) { dismiss() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button {
                    submit()
                } label: {
                    if store.addFeedBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(L("add"))
                    }
                }
                .buttonStyle(ProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || store.addFeedBusy)
            }
        }
        .padding(Space.lg)
        .frame(width: 500)
        .background(Palette.canvas)
        .onAppear {
            urlFocused = true
            store.addFeedError = nil
        }
    }

    private func submit() {
        guard isValid, !store.addFeedBusy else { return }
        Task {
            if await store.addFeedNow(url: url) == nil { dismiss() }
        }
    }
}

// MARK: - Update sheet

extension UpdateService.Manifest: @retroactive Identifiable {
    public var id: String { version }
}

struct UpdateSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Space.md) {
            BrandMark(size: 44)
            switch model.store.updateOutcome {
            case .some(.success(.available(let manifest))):
                Text(L("updateAvailableTitle")).font(Typeface.title)
                Text(String(format: L("updateAvailableBody"), manifest.version))
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.inkSecondary)
                HStack {
                    Button(L("updateLater")) { dismiss() }.buttonStyle(QuietButtonStyle())
                    Button(L("updateRestart")) {
                        dismiss()
                        Task { await model.installUpdate(manifest) }
                    }
                    .buttonStyle(ProminentButtonStyle())
                }
            case .some(.success(.upToDate)):
                Text(L("updateUpToDate")).font(Typeface.title)
                Button(L("dialogOk")) { dismiss() }
                    .buttonStyle(ProminentButtonStyle())
                    .keyboardShortcut(.defaultAction)
            case .some(.failure(let error)):
                Text(L("updateCheckFailed"))
                    .font(Typeface.title)
                Text(Self.message(error))
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .frame(maxWidth: 340)
                HStack {
                    Button(L("cancel")) { dismiss() }.buttonStyle(QuietButtonStyle())
                    Button(L("menuCheckUpdates")) {
                        model.checkForUpdates(manual: true)
                    }
                    .buttonStyle(ProminentButtonStyle())
                }
            case .none:
                EmptyView()
            }
        }
        .padding(Space.xl)
        .frame(width: 380)
        .background(Palette.canvas)
    }

    private static func message(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
