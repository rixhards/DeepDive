//
//  ChatMessage.swift
//  DeepDive
//

import Foundation

enum MessageSender {
    case player
    case character
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let sender: MessageSender
    let timestamp: Date
}
