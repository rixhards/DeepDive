//
//  Story.swift
//  DeepDive
//

import Foundation

struct Story: Codable, Equatable {
    let startNodeID: String
    let nodes: [StoryNode]
}
