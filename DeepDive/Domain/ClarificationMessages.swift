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
    ]

    static func random() -> String {
        variants.randomElement() ?? variants[0]
    }
}
