//
//  DebugFlags.swift
//  DeepDive
//
//  Development-only switches. Nothing here is diegetic — the shipping game has no HUD
//  (see docs/vision.md). Flip these off before release.

import Foundation

enum DebugFlags {
    /// Shows the sanity meter under the chat header. On while the sanity economy is being
    /// balanced on-device (spec 008); set to `false` to ship.
    static let showSanityMeter = true
}
