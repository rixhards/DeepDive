//
//  Story.swift
//  DeepDive
//

import Foundation

struct Story: Codable, Equatable {
    let startNodeID: String
    let initialState: [String: Int]?
    let nodes: [StoryNode]

    init(startNodeID: String, initialState: [String: Int]? = nil, nodes: [StoryNode]) {
        self.startNodeID = startNodeID
        self.initialState = initialState
        self.nodes = nodes
    }
}
