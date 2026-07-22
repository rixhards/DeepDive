//
//  StoryCondition.swift
//  DeepDive
//

import Foundation

struct StoryCondition: Codable, Equatable {
    let flag: String
    let equals: Bool
}

struct StoryEffect: Codable, Equatable {
    let flag: String
    let value: Bool
}
