//
//  ClarificationMessages.swift
//  DeepDive
//

import Foundation

enum ClarificationMessages {
    private static let variants = [
        "não entendi... o que você quer que eu faça?",
        "pode repetir? não peguei bem",
        "desculpa, não entendi direito",
        "como assim? não sei o que fazer com isso",
        "não consegui entender... me explica de outro jeito?",
        "hmm, não captei. tenta de outro jeito?",
        "não rolou entender isso. fala diferente?",
    ]

    /// Picks a random variant, avoiding an immediate back-to-back repeat of `previous`
    /// so two consecutive misunderstandings don't read as the same canned line.
    static func random(excluding previous: String? = nil) -> String {
        let candidates = variants.count > 1 ? variants.filter { $0 != previous } : variants
        return candidates.randomElement() ?? variants[0]
    }
}
