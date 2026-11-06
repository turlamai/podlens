import Foundation

/// Shared display formatting. Kept out of views so the podcast "10月16日"
/// / "Oct 16" convention, duration rounding and clock style are identical
/// everywhere.

private let pubDateParsers: [DateFormatter] = {
    let formats = ["E, d MMM yyyy HH:mm:ss Z",
                   "E, d MMM yyyy HH:mm:ss zzz",
                   "yyyy-MM-dd HH:mm:ss Z",
                   "E, d MMM yyyy",
                   "EEE, dd MMM yyyy HH:mm:ss Z",
                   "yyyy-MM-dd"]
    return formats.map { format in
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = format
        return parser
    }
}()

private let zhDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日"
    return formatter
}()

private let enDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "MMM d"
    return formatter
}()

/// Podcasts-style short date from the feed's RFC-822 timestamp; anything
/// unparsable passes through untouched.
func formatPubDate(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    for parser in pubDateParsers {
        if let date = parser.date(from: trimmed) {
            return (currentLanguage() == "zh" ? zhDayFormatter : enDayFormatter).string(from: date)
        }
    }
    return trimmed
}

/// "42m" / "1h 06m" — never a noisy seconds tail in list rows.
func formatDuration(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "" }
    let total = Int(seconds.rounded())
    if total >= 3600 {
        return String(format: L("hoursMinutesShort"), total / 3600, (total % 3600) / 60)
    }
    return String(format: L("minutesShort"), max(1, total / 60))
}

/// mm:ss or h:mm:ss for the player and transcript timestamps.
func formatClock(_ value: Double) -> String {
    guard value.isFinite, value >= 0 else { return "00:00" }
    let total = Int(value)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}

/// Remaining time shown on the trailing edge of the scrubber.
func formatRemaining(_ remaining: Double) -> String {
    let value = max(0, remaining)
    return "-" + formatClock(value)
}

/// "12%" for row progress lines, clamped and hidden when meaningless.
func progressFraction(position: Double, duration: Double) -> Double? {
    guard position > 5, duration > 0 else { return nil }
    return min(max(position / duration, 0), 1)
}
