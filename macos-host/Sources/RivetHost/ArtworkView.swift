import AppKit
import SwiftUI

/// Memory cache for show/episode artwork; disk caching rides on the shared
/// URLCache (sized once at startup in PodLensApp). Keys are artwork URLs.
/// Local files and file:// URLs resolve without the network so offline
/// fixtures (and the native acceptance run) render real covers.
@MainActor
enum ArtworkStore {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for raw: String) async -> NSImage? {
        let key = raw as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let image = localImage(trimmed) {
            cache.setObject(image, forKey: key)
            return image
        }
        guard let remote = URL(string: trimmed),
              let scheme = remote.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: remote)
            guard let image = NSImage(data: data) else { return nil }
            cache.setObject(image, forKey: key)
            return image
        } catch {
            return nil
        }
    }

    private static func localImage(_ path: String) -> NSImage? {
        if let url = URL(string: path), url.isFileURL {
            return NSImage(contentsOf: url)
        }
        if path.hasPrefix("/") {
            return NSImage(contentsOfFile: path)
        }
        return nil
    }

    /// Deterministic hue for cover placeholders — same show, same color,
    /// across launches and machines (Swift's hashValue is seeded per run).
    static func hue(for seed: String) -> Double {
        guard !seed.isEmpty else { return 0.06 }
        var value: UInt64 = 5381
        for scalar in seed.unicodeScalars {
            value = (value &* 33) &+ UInt64(scalar.value)
        }
        return Double(value % 360) / 360.0
    }
}

/// Rounded cover art with a designed placeholder: a warm gradient with the
/// show's initials and a small waveform, never a spinner alone.
struct ArtworkView: View {
    let url: String
    var seed: String = ""
    var cornerRadius: CGFloat = Radius.artwork
    @State private var image: NSImage?
    @State private var attempted = false

    var body: some View {
        ZStack {
            placeholder
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.6)
        }
        .task(id: url) {
            image = nil
            attempted = false
            let loaded = await ArtworkStore.image(for: url)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.quick) {
                image = loaded
                attempted = true
            }
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        let hue = ArtworkStore.hue(for: seed.isEmpty ? url : seed)
        return ZStack {
            LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.30, brightness: 0.86),
                    Color(hue: hue, saturation: 0.42, brightness: 0.66)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if seed.isEmpty {
                Image(systemName: "waveform")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text(initials(seed))
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }

    private func initials(_ text: String) -> String {
        let words = text.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "—" })
        let letters = words.prefix(2).compactMap { $0.first }.map(String.init)
        let joined = letters.joined().uppercased()
        return joined.isEmpty ? "PL" : joined
    }
}

/// A soft, blurred enlargement of the cover behind the episode header. Uses
/// the same cache as the thumbnail; returns nothing when art is unavailable
/// so the header simply sits on the canvas color.
struct ArtworkBackdrop: View {
    let url: String
    var seed: String = ""
    var opacity: Double = 0.42
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 46)
                    .opacity(opacity)
                    .overlay {
                        LinearGradient(
                            colors: [Palette.canvas.opacity(0.15), Palette.canvas.opacity(0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            } else {
                LinearGradient(
                    colors: [
                        Palette.highlight.opacity(0.9),
                        Palette.canvas.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .task(id: url) {
            let loaded = await ArtworkStore.image(for: url)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.gentle) { image = loaded }
        }
        .accessibilityHidden(true)
    }
}
