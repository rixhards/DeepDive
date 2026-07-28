//
//  SanityMeterView.swift
//  DeepDive
//
//  Debug-only readout of the character's sanity, for balancing the economy on-device.
//  Gated by `DebugFlags.showSanityMeter` — delete this file and its call site to remove.

import SwiftUI

struct SanityMeterView: View {
    let sanity: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("🧠 sanidade")
                .font(.caption)
                .foregroundStyle(Theme.timestampColor)

            ProgressView(value: Double(sanity), total: 100)
                .tint(barColor)

            Text("\(sanity)/100")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.timestampColor)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 6)
        .background(Theme.headerBackground)
    }

    private var barColor: Color {
        switch sanity {
        case ..<30: .red
        case ..<60: .orange
        default: .green
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        SanityMeterView(sanity: 80)
        SanityMeterView(sanity: 45)
        SanityMeterView(sanity: 12)
    }
    .background(Theme.background)
}
