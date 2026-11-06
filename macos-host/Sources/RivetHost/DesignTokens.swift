import SwiftUI

/// Compatibility shim for code that still asks for "design tokens".
/// The real, expanded system lives in DesignSystem.swift; these two names
/// remain because the roadmap and older comments reference them.
enum DesignTokens {
    static let accent = Palette.accent
    static let accentSoft = Palette.highlight
}
