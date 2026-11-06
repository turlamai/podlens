import SwiftUI

/// Window-level player. Apple Podcasts keeps transport global so browsing
/// never interrupts listening; PodLens keeps the same contract but gives the
/// scrubber a full-width lane and keeps secondary commands in menus.
struct PlayerBar: View {
    @EnvironmentObject private var store: PodLensStore

    private var hasEpisode: Bool { store.selectedEpisode != nil }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: Space.md) {
                nowPlaying
                    .frame(width: 238, alignment: .leading)

                VStack(spacing: 6) {
                    transport
                    scrubber
                }
                .frame(maxWidth: .infinity)

                utilities
                    .frame(width: 154, alignment: .trailing)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 9)
        .background(.bar)
        .hairlineTop()
    }

    // MARK: now playing

    @ViewBuilder
    private var nowPlaying: some View {
        if let episode = store.selectedEpisode {
            HStack(spacing: Space.xs) {
                ArtworkView(url: store.selectedFeed?.artworkURL ?? "",
                            seed: store.selectedFeed?.title ?? episode.title,
                            cornerRadius: 7)
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text(episode.title)
                        .font(Typeface.caption.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(store.npShow.isEmpty ? (store.selectedFeed?.title ?? "") : store.npShow)
                        .font(Typeface.micro)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack(spacing: Space.xs) {
                BrandMark(size: 30)
                    .opacity(0.55)
                Text(L("nothingPlaying"))
                    .font(Typeface.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }

    // MARK: transport

    private var transport: some View {
        HStack(spacing: 16) {
            if !store.chapters.isEmpty {
                Button {
                    store.skipChapter(-1)
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(RoundIconButtonStyle(size: 26))
                .disabled(!hasEpisode)
                .help(store.currentChapter()?.title ?? L("chapterPrev"))
            }

            Button {
                store.skip(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 15, weight: .medium))
            }
            .buttonStyle(RoundIconButtonStyle(size: 28))
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .disabled(!hasEpisode)
            .help(L("skipBack"))
            .accessibilityLabel(L("skipBack"))

            Button {
                store.togglePlay()
            } label: {
                Image(systemName: store.playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Palette.accent, in: Circle())
                    .shadow(color: Palette.accent.opacity(0.25), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("PlayPauseButton")
            .accessibilityLabel(store.playing ? L("pause") : L("play"))
            .keyboardShortcut(.space, modifiers: [])
            .disabled(!hasEpisode)
            .help(store.playing ? L("pause") : L("play"))

            Button {
                store.skip(by: 30)
            } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 15, weight: .medium))
            }
            .buttonStyle(RoundIconButtonStyle(size: 28))
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .disabled(!hasEpisode)
            .help(L("skipForward"))
            .accessibilityLabel(L("skipForward"))

            if !store.chapters.isEmpty {
                Button {
                    store.skipChapter(1)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(RoundIconButtonStyle(size: 26))
                .disabled(!hasEpisode)
                .help(L("chapterNext"))
            }
        }
    }

    private var scrubber: some View {
        HStack(spacing: Space.xs) {
            Text(formatClock(store.currentTime))
                .font(Typeface.mono(10))
                .foregroundStyle(hasEpisode ? Palette.inkSecondary : Palette.inkTertiary)
                .frame(width: 42, alignment: .trailing)
                .accessibilityIdentifier("PlayerPosition")

            Scrubber(
                progress: store.duration > 0
                    ? min(max(store.currentTime / store.duration, 0), 1) : 0,
                enabled: hasEpisode,
                onSeek: { fraction in
                    store.seek(to: fraction * max(store.duration, 1))
                })

            Text(hasEpisode
                 ? formatRemaining(max(store.duration - store.currentTime, 0))
                 : "--:--")
                .font(Typeface.mono(10))
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 44, alignment: .leading)
        }
    }

    // MARK: utilities

    private var utilities: some View {
        HStack(spacing: 2) {
            Menu {
                ForEach(PodLensStore.playbackRates, id: \.self) { rate in
                    Button {
                        store.setRate(rate)
                    } label: {
                        if rate == store.rate {
                            Label(rateLabel(rate), systemImage: "checkmark")
                        } else {
                            Text(rateLabel(rate))
                        }
                    }
                }
            } label: {
                Text(rateLabel(store.rate))
                    .font(Typeface.mono(10, weight: .medium))
                    .foregroundStyle(hasEpisode ? Palette.inkSecondary : Palette.inkTertiary)
                    .frame(width: 34, height: 24)
                    .background(Palette.surfaceRaised, in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(!hasEpisode)
            .help(L("speed"))
            .accessibilityLabel(L("speed"))

            Menu {
                Button(L("sleepOff")) { store.cancelSleepTimer() }
                Divider()
                ForEach([5, 10, 15, 30, 45, 60, 90], id: \.self) { minutes in
                    Button(String(format: L("sleepMinutes"), minutes)) {
                        store.startSleepTimer(minutes: minutes)
                    }
                }
            } label: {
                Image(systemName: store.sleepMinutesRemaining == nil ? "moon.zzz" : "moon.zzz.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(store.sleepMinutesRemaining == nil
                                     ? Palette.inkSecondary : Palette.accent)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(!hasEpisode)
            .help(store.sleepMinutesRemaining.map { String(format: L("sleepActive"), $0) } ?? L("sleep"))
            .accessibilityLabel(L("sleep"))
        }
    }

    private func rateLabel(_ rate: Float) -> String {
        String(format: "%g×", rate)
    }
}

/// Thin, draggable scrubber with a thumb that appears on hover — the same
/// reading as Apple Podcasts, without a chunky system slider.
struct Scrubber: View {
    let progress: Double
    let enabled: Bool
    let onSeek: (Double) -> Void
    @State private var hovering = false
    @State private var dragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let fraction = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.hairline)
                    .frame(height: 4)
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: max(4, width * fraction), height: 4)
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 10, height: 10)
                    .shadow(color: Palette.accent.opacity(0.3), radius: 3)
                    .offset(x: max(0, width * fraction - 5))
                    .opacity(hovering || dragging ? 1 : 0)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard enabled else { return }
                        dragging = true
                        onSeek(min(max(value.location.x / width, 0), 1))
                    }
                    .onEnded { _ in dragging = false }
            )
        }
        .frame(height: 16)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityElement()
        .accessibilityLabel(L("playbackPosition"))
        .accessibilityValue("\(Int(progress * 100))%")
        .accessibilityAdjustableAction { direction in
            guard enabled else { return }
            switch direction {
            case .increment: onSeek(min(progress + 0.02, 1))
            case .decrement: onSeek(max(progress - 0.02, 0))
            @unknown default: break
            }
        }
    }
}
