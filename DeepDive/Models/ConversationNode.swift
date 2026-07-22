//
//  ConversationNode.swift
//  DeepDive
//

import Foundation

struct ConversationOption: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let nextNodeID: String
}

struct ConversationNode {
    let id: String
    let characterText: String
    let options: [ConversationOption]
}
