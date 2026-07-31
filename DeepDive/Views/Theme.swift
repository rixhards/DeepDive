//
//  Theme.swift
//  DeepDive
//
//  Centralized colors and spacing (spec 010). Values are the redesign tokens, written out
//  explicitly: nothing here may resolve to a system default. `Color.accentColor` used to
//  paint the player's bubble, which rendered as Apple's #007AFF and made the game look like
//  Messages in dark mode — the one thing the visual language must not be.
//

import SwiftUI

enum Theme {
    // MARK: - Palette

    /// The page itself: a vertical gradient, near-black at the top, a shade warmer at the
    /// bottom. Flat black read as "app background"; this reads as depth.
    static let background = LinearGradient(
        colors: [Color(hex: 0x06080A), Color(hex: 0x0E1114)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Behind the header and the composer — slightly lifted off the gradient.
    static let headerBackground = Color(hex: 0x0B0F12)

    static let characterBubble = Color(hex: 0x161A1D)
    /// Desaturated petrol. Deliberately close to the character's bubble in weight: the
    /// player is a voice in the same dark, not a bright UI element on top of it.
    static let playerBubble = Color(hex: 0x2A3A42)

    /// The only warm colour in the game — the lamp she carries. Reserved for hairlines, the
    /// primary button and the send button. If it starts showing up anywhere else, it stops
    /// meaning anything.
    static let accentLamp = Color(hex: 0xE8A94B)

    static let primaryText = Color(hex: 0xE6EAED)
    static let timestampColor = Color.white.opacity(0.35)
    static let optionBackground = Color.white.opacity(0.06)
    /// Hairlines: dividers, the composer's underline, button outlines.
    static let hairline = Color.white.opacity(0.10)

    /// The cold cast that creeps in at low sanity.
    static let coldVeil = Color(hex: 0x0A1A22)

    // MARK: - Metrics

    static let bubbleCornerRadius: CGFloat = 14
    static let bubbleMaxWidthRatio: CGFloat = 0.75
    static let messageSpacing: CGFloat = 8
    /// Consecutive messages from the same sender sit closer together than a change of speaker.
    static let groupedMessageSpacing: CGFloat = 3
    static let screenPadding: CGFloat = 16

    /// How long the world takes to darken. Slow on purpose: a fast change would read as a
    /// meter moving, which is exactly what this replaces (spec 010).
    static let degradationAnimation: Animation = .easeInOut(duration: 1.8)
}

extension Color {
    /// 0xRRGGBB literal — the design tokens are written as hex, so they stay readable here.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
