//
//  StoryRepository.swift
//  DeepDive
//

import Foundation

enum StoryRepositoryError: Error, Equatable {
    case missingFile
}

struct StoryRepository {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func load() throws -> Story {
        guard let url = bundle.url(forResource: "story", withExtension: "json") else {
            throw StoryRepositoryError.missingFile
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Story.self, from: data)
    }
}
