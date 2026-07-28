//
//  HeuristicIntentMatcher.swift
//  DeepDive
//
//  Deterministic, AI-free first pass for intent matching: scores the player's text
//  against each option's text + hints by word overlap. Runs before (and is far cheaper
//  than) the Foundation Models fallback, and handles the common case — divergent but
//  clearly-related phrasing — without depending on model quality at all.

import Foundation

enum HeuristicIntentMatcher {
    /// Portuguese function words common enough to appear in nearly every option, so a
    /// match on these alone isn't meaningful. Listed post diacritic-folding.
    private static let stopwords: Set<String> = [
        "voce", "que", "nao", "e", "o", "a", "de", "do", "da", "em", "um", "uma",
        "eu", "me", "ta", "pra", "para", "por", "com", "os", "as", "no", "na", "se",
        "sua", "seu", "isso", "esta", "aqui", "ai", "meu", "minha", "mais", "ser",
        "vc", "voces",
    ]

    /// Returns the best-matching option id, or `nil` if nothing clears the confidence
    /// threshold or the top two candidates are tied (too ambiguous to guess between).
    static func bestMatch(for playerText: String, among options: [EngineOption], threshold: Double = 0.5) -> String? {
        let playerWords = normalize(playerText)
        guard !playerWords.isEmpty else { return nil }

        let scored = options
            .compactMap { option -> (id: String, score: Double)? in
                let vocabulary = normalize(option.text).union(option.hints.flatMap(normalize))
                let intersection = playerWords.intersection(vocabulary)
                guard !intersection.isEmpty else { return nil }
                return (option.id, Double(intersection.count) / Double(playerWords.count))
            }
            .sorted { $0.score > $1.score }

        guard let best = scored.first, best.score >= threshold else { return nil }
        if scored.count > 1, scored[1].score == best.score { return nil }
        return best.id
    }

    private static func normalize(_ text: String) -> Set<String> {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stopwords.contains($0) }
        return Set(words)
    }
}
