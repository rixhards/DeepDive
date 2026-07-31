//
//  VignetteOverlay.swift
//  DeepDive
//
//  The sanity meter's replacement (spec 010). The edges of the screen close in as she comes
//  apart, and a cold cast bleeds over everything in the bottom band. Purely decorative: it
//  never takes a touch, and it holds no state of its own — `intensity` and `coldness` are
//  computed by the view model.

import SwiftUI

struct VignetteOverlay: View {
    /// 0 = barely there, 1 = pressing in.
    let intensity: Double
    /// Opacity of the cold cast laid over the whole screen.
    let coldness: Double

    var body: some View {
        ZStack {
            Theme.coldVeil
                .opacity(coldness)
                .blendMode(.softLight)

            RadialGradient(
                colors: [.clear, .black.opacity(intensity)],
                center: .center,
                // The dark ring starts closer to the middle the worse she gets.
                startRadius: 260 - (170 * intensity),
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        // Decoration must never eat a tap meant for the chat (spec 010, notas técnicas).
        .allowsHitTesting(false)
        .animation(Theme.degradationAnimation, value: intensity)
        .animation(Theme.degradationAnimation, value: coldness)
    }
}

#Preview("sanidade alta") {
    ZStack {
        Theme.background.ignoresSafeArea()
        VignetteOverlay(intensity: 0.06, coldness: 0)
    }
}

#Preview("sanidade baixa") {
    ZStack {
        Theme.background.ignoresSafeArea()
        VignetteOverlay(intensity: 0.7, coldness: 0.15)
    }
}
