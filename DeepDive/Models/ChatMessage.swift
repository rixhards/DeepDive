//
//  ChatMessage.swift
//  DeepDive
//

import Foundation

enum MessageSender: Codable {
    case player
    case character
}

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let text: String
    let sender: MessageSender
    let timestamp: Date

    init(id: UUID = UUID(), text: String, sender: MessageSender, timestamp: Date) {
        self.id = id
        self.text = text
        self.sender = sender
        self.timestamp = timestamp
    }
}
