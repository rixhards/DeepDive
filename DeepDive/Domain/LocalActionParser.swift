//
//  LocalActionParser.swift
//  DeepDive
//
//  Deterministic verb/target extraction, no AI. Runs before the model and handles the common
//  phrasings outright — which also means the game is playable in the Simulator, where
//  Apple Intelligence doesn't exist.
//
//  Returns `nil` when it isn't confident, so the model gets a shot at the interesting cases.

import Foundation

enum LocalActionParser {

    private static let verbCues: [(Verb, [String])] = [
        // Order matters: the first cue found in the text wins, and more specific verbs
        // (inventory, talk) are checked before the generic ones.
        (.inventory, ["o que voce tem", "o que vc tem", "que itens", "seu inventario", "o que ta carregando",
                      "o que você tem", "com o que você tá", "tem alguma coisa com voce"]),
        (.talk, ["voce ta bem", "vc ta bem", "ta tudo bem", "como voce ta", "como vc ta", "ta machucada",
                 "voce aguenta", "calma", "respira", "to aqui", "to contigo", "voce consegue", "tudo certo"]),
        (.look, ["olha em volta", "olha ao redor", "descreve o ambiente", "descreve o lugar", "o que voce ve",
                 "o que vc ve", "onde voce esta", "onde vc ta", "onde voce ta", "como e o lugar", "olha em volta de novo"]),
        (.examine, ["examina", "observa", "repara", "inspeciona", "da uma olhada",
                    "descreve o", "descreve a", "ve o", "ve a",
                    // Bare "olha" is last so the specific .look phrasings above win the tie.
                    "olha"]),
        (.take, ["pega", "pegue", "recolhe", "guarda", "apanha"]),
        (.use, ["usa", "use", "toca", "encosta", "bate", "abre", "empurra", "forca", "corta", "queima",
                "acende", "apaga", "enfia", "mexe", "destranca", "arromba", "poe fogo", "joga"]),
        (.go, ["vai", "va", "anda", "segue", "entra", "atravessa", "sobe", "desce", "volta", "sai",
               "caminha", "avanca", "toma o", "segue pel"]),
        (.wait, ["espera", "nao faz nada", "fica parada", "fica ai", "nao se mexe", "para quieta", "aguarda"]),
    ]

    private static let hostileCues = [
        "cala a boca", "burra", "idiota", "imbecil", "para de chorar", "anda logo", "se mexe",
        "inutil", "vai logo caralho", "merda", "porra", "otaria", "estupida", "cala boca",
    ]

    static func parse(_ playerText: String, world: World) -> PlayerAction? {
        let text = playerText.folded
        guard !text.isEmpty else { return nil }

        let hostile = hostileCues.contains { text.contains($0.folded) }

        guard let (verb, cue) = firstVerb(in: text) else {
            // Hostility on its own is still a readable act, even with no verb.
            return hostile ? PlayerAction(verb: .talk, isHostile: true) : nil
        }

        // Everything after the verb cue is the player's description of the target.
        var remainder = ""
        if let range = text.range(of: cue.folded) {
            remainder = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Two orders are common in pt-BR and they mean the same thing:
        //   "usa a faca no feno"      → instrument first, then target
        //   "corta o feno com a faca" → target first, then instrument
        var target: String? = remainder.strippedArticles
        var instrument: String?

        if let range = remainder.range(of: " com ") {
            target = String(remainder[..<range.lowerBound]).strippedArticles
            instrument = String(remainder[range.upperBound...]).strippedArticles
        } else {
            for separator in [" no ", " na ", " nos ", " nas ", " em ", " contra "] {
                guard let range = remainder.range(of: separator) else { continue }
                instrument = String(remainder[..<range.lowerBound]).strippedArticles
                target = String(remainder[range.upperBound...]).strippedArticles
                break
            }
        }

        return PlayerAction(
            verb: verb,
            target: target?.isEmpty == true ? nil : target,
            instrument: instrument,
            isHostile: hostile
        )
    }

    private static func firstVerb(in text: String) -> (Verb, String)? {
        var best: (verb: Verb, cue: String, index: String.Index)?
        for (verb, cues) in verbCues {
            for cue in cues {
                guard let range = text.range(of: cue.folded) else { continue }
                // Prefer the earliest cue; ties go to whichever was listed first.
                if best == nil || range.lowerBound < best!.index {
                    best = (verb, cue, range.lowerBound)
                }
            }
            // A multi-word specific cue that matched at position 0 is as good as it gets.
            if let best, best.index == text.startIndex { return (best.verb, best.cue) }
        }
        guard let best else { return nil }
        return (best.verb, best.cue)
    }
}

private extension String {
    /// Drops leading articles/prepositions so "a porta de ferro" and "porta de ferro" match alike.
    var strippedArticles: String {
        var result = trimmingCharacters(in: .whitespacesAndNewlines)
        // Repeat: "pros símbolos" strips to "símbolos" in two passes ("pros " then nothing).
        let leading = ["pros ", "pras ", "pro ", "pra ", "para ", "nos ", "nas ", "no ", "na ",
                       "os ", "as ", "o ", "a ", "um ", "uma ", "do ", "da ", "de ", "em "]
        var changed = true
        while changed {
            changed = false
            for article in leading where result.hasPrefix(article) {
                result = String(result.dropFirst(article.count))
                changed = true
                break
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
