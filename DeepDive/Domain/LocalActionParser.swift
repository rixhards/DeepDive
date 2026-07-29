//
//  LocalActionParser.swift
//  DeepDive
//
//  Deterministic verb/target extraction, no AI. Runs before the model and handles the common
//  phrasings outright — which also means the game is playable in the Simulator, where
//  Apple Intelligence doesn't exist.
//
//  Matching is **word-boundary aware**. Plain substring matching is a trap in Portuguese:
//  the cue "va" hides inside "descreva", "salva" and "lava", which silently turned
//  "descreva seus arredores" into a movement command.
//
//  Returns `nil` when it isn't confident, so the model gets a shot at the interesting cases.

import Foundation

enum LocalActionParser {

    /// Order matters twice over: the earliest match in the sentence wins, and ties go to
    /// whichever verb is listed first here. So specific phrasings come before generic ones.
    /// Split in three so the type-checker doesn't choke on one giant literal.
    private static let verbCues: [(Verb, [String])] = answerCues + senseCues + actionCues

    private static let answerCues: [(Verb, [String])] = [
        // Answers to a question she asked. Listed before .wait/.no-alikes that share words.
        (.wait, ["nao faz nada", "nao facas nada", "fica parada", "fica quieta", "fica ai",
                 "nao se mexe", "nao se mexa", "espera", "espere", "aguarda", "aguarde",
                 "nao anda", "nao ande", "para quieta"]),
        (.yes, ["sim", "isso", "pode ir", "pode sim", "vai fundo", "manda ver", "com certeza",
                "claro", "aham", "uhum", "faz isso", "faca isso", "confirma", "confirmo"]),
        (.no, ["nao", "melhor nao", "pare", "deixa", "deixe", "esquece", "esqueca",
               "cancela", "cancele", "recua", "desiste", "nem pensar", "de jeito nenhum"]),

    ]

    private static let senseCues: [(Verb, [String])] = [
        (.ask, ["quem e voce", "quem eh voce", "quem fala", "qual seu nome", "seu nome",
                "como voce se chama", "quem ta ai", "quem esta ai", "com quem eu falo",
                "com quem estou falando", "o que aconteceu", "o que houve", "como voce chegou",
                "voce lembra", "se lembra", "o que voce lembra", "que lugar e esse",
                "onde nos estamos", "o que e esse lugar", "ha quanto tempo", "quanto tempo faz",
                "que horas sao", "voce esta ferida", "voce ta ferida", "voce se machucou",
                "tem mais alguem", "voce esta sozinha", "voce ta sozinha", "tem alguem com voce",
                "voce me conhece", "voce sabe quem eu sou", "por que eu", "voce sabe onde ta",
                "voce faz ideia"]),

        (.inventory, ["o que voce tem", "o que vc tem", "que itens", "seu inventario", "inventario",
                      "o que ta carregando", "o que voce carrega", "o que tem contigo",
                      "o que tem com voce", "o que sobrou", "seus itens", "que voce tem ai"]),

        (.talk, ["voce ta bem", "vc ta bem", "ta tudo bem", "como voce ta", "como vc ta",
                 "ta machucada", "voce aguenta", "calma", "respira", "respire", "to aqui",
                 "to contigo", "voce consegue", "tudo certo", "nao te abandono", "fica calma",
                 "vai dar certo", "eu te ajudo", "confia em mim"]),

        (.listen, ["escuta", "escute", "ouve", "ouca", "presta atencao no som", "que som e esse",
                   "que barulho", "tem barulho", "fica em silencio e escuta"]),

        (.smell, ["cheira", "cheire", "que cheiro", "sente o cheiro", "tem cheiro"]),

        (.shout, ["grita", "grite", "chama", "chame", "berra", "berre", "pede ajuda", "pede socorro",
                  "fala alto", "chama por alguem", "grita por ajuda"]),

        (.hide, ["esconde", "esconda", "se esconde", "procura esconderijo", "sai de vista",
                 "fica escondida", "se protege"]),

        (.rest, ["descansa", "descanse", "senta", "sente se", "respira fundo", "recupera o folego",
                 "para pra descansar"]),

    ]

    private static let actionCues: [(Verb, [String])] = [
        (.look, ["olha em volta", "olha ao redor", "olhe em volta", "olhe ao redor",
                 "descreve o ambiente", "descreva o ambiente", "descreve o lugar", "descreva o lugar",
                 "descreve seus arredores", "descreva seus arredores", "descreve o que ve",
                 "descreva o que ve", "o que voce ve", "o que vc ve", "onde voce esta", "onde vc ta",
                 "onde voce ta", "como e o lugar", "me descreve", "me descreva", "da uma olhada em volta"]),

        (.examine, ["examina", "examine", "observa", "observe", "repara", "repare", "inspeciona",
                    "inspecione", "analisa", "analise", "da uma olhada", "de uma olhada",
                    "descreve", "descreva", "ve o", "ve a", "olha", "olhe"]),

        (.take, ["pega", "pegue", "recolhe", "recolha", "guarda", "guarde", "apanha", "apanhe",
                 "leva", "leve", "tira", "tire"]),

        (.use, ["usa", "use", "utiliza", "utilize", "toca", "toque", "encosta", "encoste",
                "bate", "bata", "abre", "abra", "abrir", "empurra", "empurre", "puxa", "puxe",
                "forca", "force", "corta", "corte", "queima", "queime", "acende", "acenda",
                "apaga", "apague", "enfia", "enfie", "mexe", "mexa", "revira", "revire",
                "destranca", "destranque", "arromba", "arrombe", "poe fogo", "bota fogo",
                "joga", "jogue", "atira", "encaixa", "encaixe", "gira", "gire", "tenta abrir",
                "procura", "procure", "vasculha", "vasculhe", "cava", "cave"]),

        (.go, ["vai", "va", "anda", "ande", "caminha", "caminhe", "segue", "siga", "segue em frente",
               "siga em frente", "entra", "entre", "atravessa", "atravesse", "sobe", "suba",
               "desce", "desca", "volta", "volte", "retorna", "retorne", "sai", "saia",
               "avanca", "avance", "corre", "corra", "foge", "fuja", "prossegue", "prossiga"]),
    ]

    private static let hostileCues = [
        "cala a boca", "cala boca", "burra", "idiota", "imbecil", "para de chorar",
        "anda logo", "se mexe logo", "inutil", "merda", "porra", "estupida", "otaria",
        "para de frescura", "deixa de ser", "voce e inutil",
    ]

    static func parse(_ playerText: String, world: World) -> PlayerAction? {
        // Punctuation would otherwise glue itself to the last word and defeat the
        // whole-word lookups below ("vc ta bem?" must still match "vc ta bem").
        let text = playerText.folded
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        // Padding lets every lookup below demand whole words on both sides.
        let padded = " \(text) "
        let hostile = hostileCues.contains { padded.contains(" \($0.folded) ") || text.contains($0.folded) }

        guard let match = firstVerb(in: padded) else {
            // Hostility on its own is still a readable act, even with no verb.
            return hostile ? PlayerAction(verb: .talk, isHostile: true) : nil
        }

        let remainder = String(padded[match.range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Two orders are common in pt-BR and they mean the same thing:
        //   "usa a faca no feno"      → instrument first, then target
        //   "corta o feno com a faca" → target first, then instrument
        var target: String? = remainder.strippedArticles
        var instrument: String?

        if let range = remainder.range(of: " com ") {
            target = String(remainder[..<range.lowerBound]).strippedArticles
            instrument = String(remainder[range.upperBound...]).strippedArticles
        } else {
            for separator in [" no ", " na ", " nos ", " nas ", " em ", " contra ", " dentro d"] {
                guard let range = remainder.range(of: separator) else { continue }
                instrument = String(remainder[..<range.lowerBound]).strippedArticles
                target = String(remainder[range.upperBound...]).strippedArticles
                break
            }
        }

        // "volta", "sobe", "desce" and "sai" are complete instructions on their own — the verb
        // *is* the direction, so it doubles as the target for exit matching.
        if match.verb == .go, target?.isEmpty != false {
            target = match.cue
        }

        return PlayerAction(
            verb: match.verb,
            target: target?.isEmpty == true ? nil : target,
            instrument: instrument,
            isHostile: hostile
        )
    }

    private static func firstVerb(in padded: String) -> (verb: Verb, cue: String, range: Range<String.Index>)? {
        var best: (verb: Verb, cue: String, range: Range<String.Index>)?

        for (verb, cues) in verbCues {
            for cue in cues {
                // The surrounding spaces are the whole point: they stop "va" from matching
                // inside "descreva".
                guard let range = padded.range(of: " \(cue.folded) ") else { continue }
                if best == nil || range.lowerBound < best!.range.lowerBound {
                    // Trim the padding spaces back off so the remainder starts cleanly.
                    let inner = padded.index(after: range.lowerBound)..<padded.index(before: range.upperBound)
                    best = (verb, cue, inner)
                }
            }
            // A cue that starts the sentence can't be beaten by anything later.
            if let best, best.range.lowerBound == padded.index(after: padded.startIndex) {
                return best
            }
        }
        return best
    }
}

private extension String {
    /// Drops leading articles/prepositions so "a porta de ferro" and "porta de ferro" match alike.
    var strippedArticles: String {
        var result = trimmingCharacters(in: .whitespacesAndNewlines)
        // Repeated: "pros símbolos" strips to "símbolos" in two passes.
        let leading = ["pros ", "pras ", "pro ", "pra ", "para ", "pelo ", "pela ", "nos ", "nas ",
                       "no ", "na ", "os ", "as ", "o ", "a ", "um ", "uma ", "do ", "da ", "de ",
                       "em ", "ate ", "até "]
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
