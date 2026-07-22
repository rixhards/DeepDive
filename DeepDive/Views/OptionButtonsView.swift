//
//  OptionButtonsView.swift
//  DeepDive
//

import SwiftUI

struct OptionButtonsView: View {
    let options: [ChatOption]
    let onSelect: (ChatOption) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(options) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        Text(option.text)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.optionBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius)
                            .stroke(Theme.optionBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius))
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 220)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        OptionButtonsView(
            options: [
                ChatOption(id: "a", text: "não sei onde estou"),
                ChatOption(id: "b", text: "me ajuda"),
            ],
            onSelect: { _ in }
        )
    }
}
