//
//  Story.swift
//  DeepDive
//

import Foundation

struct Story: Codable, Equatable {
    let startNodeID: String
    let initialState: [String: Int]?
    /// Node the engine jumps to the moment `sanity` hits 0, overriding the chosen option's
    /// destination. Optional — absent means sanity 0 has no special routing.
    let sanityZeroNodeID: String?
    let nodes: [StoryNode]

    init(
        startNodeID: String,
        initialState: [String: Int]? = nil,
        sanityZeroNodeID: String? = nil,
        nodes: [StoryNode]
    ) {
        self.startNodeID = startNodeID
        self.initialState = initialState
        self.sanityZeroNodeID = sanityZeroNodeID
        self.nodes = nodes
    }
}
