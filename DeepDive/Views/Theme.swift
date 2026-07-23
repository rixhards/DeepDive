//
//  Theme.swift
//  DeepDive
//
//  Centralized colors and spacing for the chat aesthetic.
//

import SwiftUI

enum Theme {
    static let background = Color.black
    static let headerBackground = Color(white: 0.1)
    static let characterBubble = Color(white: 0.16)
    static let playerBubble = Color.accentColor
    static let timestampColor = Color.white.opacity(0.5)
    static let optionBackground = Color.white.opacity(0.08)

    static let bubbleCornerRadius: CGFloat = 16
    static let bubbleMaxWidthRatio: CGFloat = 0.75
    static let messageSpacing: CGFloat = 8
    static let screenPadding: CGFloat = 12
}
