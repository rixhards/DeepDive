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

nonisolated enum LocalActionParser {

    /// Order matters twice over: the earliest match in the sentence wins, and ties go to
    /// whichever verb is listed first here. So specific phrasings come before generic ones.
    /// Split in three so the type-checker doesn't choke on one giant literal.
    private static let verbCues: [(Verb, [String])] = answerCues + greetCues + senseCues + actionCues

    /// Words that turn the clause after them into a prohibition. Deliberately **not** cues of
    /// the verb `.no`: reading a bare "não" as the verb made "não tenha medo, eu tô aqui"
    /// cancel whatever she was standing at the edge of (spec 013).
    private static let bareNegators: Set<String> = ["nao", "nunca", "jamais", "nem"]

    /// How many words may sit between a negator and the verb it negates.
    private static let negationReach = 3

    private static let answerCues: [(Verb, [String])] = [
        // Answers to a question she asked. Listed before .wait/.no-alikes that share words.
        (.wait, ["nao faz nada", "nao facas nada", "fica parada", "fica quieta", "fica ai",
                 "nao se mexe", "nao se mexa", "espera", "espere", "aguarda", "aguarde",
                 "nao anda", "nao ande", "para quieta"]),
        (.yes, ["sim", "isso", "pode ir", "pode sim", "vai fundo", "manda ver", "com certeza",
                "claro", "aham", "uhum", "faz isso", "faca isso", "confirma", "confirmo",
                "pode entrar", "pode abrir", "entra sim", "vai sim", "tenho certeza"]),
        // Bare "nao"/"nunca" are handled by the negation pass, not here — otherwise they win
        // on position and swallow the verb they were modifying.
        (.no, ["melhor nao", "pare", "deixa", "deixe", "esquece", "esqueca",
               "cancela", "cancele", "recua", "desiste", "nem pensar", "de jeito nenhum"]),

    ]

    /// Hello, and "ok/beleza/entendi". She opens the game with "oi? tem alguém aí?" — the
    /// player answering "oi" used to get "eu não entendi o que é pra eu fazer".
    private static let greetCues: [(Verb, [String])] = [
        (.greet, ["oi", "ola", "opa", "eae", "e ai", "fala", "alo", "bom dia", "boa tarde",
                  "boa noite", "ok", "okay", "ta bom", "tudo bem entao", "beleza", "blz",
                  "entendi", "certo", "ta certo", "valeu", "obrigado", "obrigada", "tranquilo"]),
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
                "voce faz ideia",
                // The player asking for direction. Common in the first minute, and it used to
                // fall through to "eu não entendi" (spec 013).
                "o que eu faco", "o que eu devo fazer", "o que fazer", "e agora", "me ajuda",
                "alguma ideia", "o que voce acha", "o que a gente faz", "por onde comeco"]),

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
                 "onde voce ta", "como e o lugar", "me descreve", "me descreva", "da uma olhada em volta",
                 // Phrasings the support page teaches but the parser never knew (spec 013).
                 "o que voce ta vendo", "o que vc ta vendo", "o que ta vendo", "o que voce esta vendo",
                 "o que voce enxerga", "o que tem ai", "o que tem aqui", "o que tem em volta",
                 "me diz o que tem", "me diz o que voce ve", "o que voce consegue ver"]),

        (.examine, ["examina", "examine", "observa", "observe", "repara", "repare", "inspeciona",
                    "inspecione", "analisa", "analise", "da uma olhada", "de uma olhada",
                    "descreve", "descreva", "ve o", "ve a", "olha", "olhe"]),

        // Searching is its own act: "olha pro feno" describes it, "revira o feno" digs in it.
        // These used to live in `.use`, which is how "procura uma saída" reached the
        // touch-the-scenery fallback and put her hand in the water (spec 013).
        (.search, ["procura", "procure", "vasculha", "vasculhe", "cava", "cave",
                   "revira", "revire", "remexe", "remexa", "da uma procurada", "ve se tem",
                   "olha se tem", "fuca", "fuce"]),

        // Knocking must beat the generic "use" cues: it's the difference between surviving
        // the hay room and not.
        (.knock, ["bate", "bata", "bater", "da uma batida", "de uma batida", "toca na porta"]),

        // Burning must also beat "use": searching the hay finds the key, burning it is a death.
        (.burn, ["queima", "queime", "poe fogo", "põe fogo", "bota fogo", "toca fogo",
                 "ateia fogo", "ateie fogo", "incendeia", "incendeie"]),

        (.take, ["pega", "pegue", "recolhe", "recolha", "guarda", "guarde", "apanha", "apanhe",
                 "leva", "leve", "tira", "tire"]),

        (.use, ["usa", "use", "utiliza", "utilize",
                "abre", "abra", "abrir", "empurra", "empurre", "puxa", "puxe",
                "forca", "force", "corta", "corte", "acende", "acenda",
                "apaga", "apague", "enfia", "enfie", "mexe", "mexa",
                "destranca", "destranque", "arromba", "arrombe",
                "joga", "jogue", "atira", "encaixa", "encaixe", "gira", "gire", "tenta abrir"]),

        // Listed after `.burn` on purpose: "toca fogo no feno" must stay a burn, and a cue that
        // starts the sentence wins outright, so burn has to be consulted first.
        (.touch, ["toca", "toque", "encosta", "encoste", "apalpa", "tateia", "poe a mao",
                  "bota a mao", "passa a mao", "sente a textura"]),

        (.go, ["vai", "va", "anda", "ande", "caminha", "caminhe", "segue", "siga", "segue em frente",
               "siga em frente", "entra", "entre", "atravessa", "atravesse", "sobe", "suba",
               "desce", "desca", "volta", "volte", "retorna", "retorne", "sai", "saia",
               "avanca", "avance", "corre", "corra", "foge", "fuja", "prossegue", "prossiga"]),
    ]

    /// The two tones the local pass can read without a model. Anything neither list catches
    /// is neutral — the FoundationModels parser refines this for the phrasings it handles.
    private static let distressingCues = [
        // Insults
        "cala a boca", "cala boca", "burra", "idiota", "imbecil", "para de chorar",
        "anda logo", "se mexe logo", "inutil", "merda", "porra", "estupida", "otaria",
        "para de frescura", "deixa de ser", "voce e inutil", "cala essa boca",
        // Threats and cruelty
        "voce vai morrer", "ninguem vai te salvar", "voce nao sai mais dai", "morre",
        "se mata", "voce ja morreu", "espero que morra", "voce merece",
        // Abandonment — the player saying, in any words, that they won't help
        "nao ligo", "nao me importo", "nao quero ajudar", "nao vou te ajudar",
        "nao vou ajudar", "me deixa em paz", "problema seu", "resolve sozinha",
        "resolve isso sozinha", "se vira", "vira sozinha", "desisto de voce", "desisto",
        "nao interessa", "tanto faz", "pouco me importa", "nem quero saber",
        "nao é meu problema", "nao e meu problema", "fodase", "foda se", "to fora",
        "estou fora", "nao vou responder", "vou embora", "cansei de voce", "sai fora",
    ]

    private static let supportiveCues = [
        "calma", "fica calma", "respira", "respire", "vai dar certo", "voce consegue",
        "to aqui", "to contigo", "estou aqui", "estou contigo", "nao te abandono",
        "confia em mim", "conta comigo", "voce e forte", "coragem", "forca",
        "nao desiste", "eu te ajudo", "vou te tirar dai", "aguenta firme", "tenho orgulho",
        // Reassurance phrased as a negation. These are the warmest things a player types, and
        // every one of them used to read as hostility because the distressing cue matched as a
        // bare substring inside them (spec 013).
        "nao desisto", "nao vou desistir", "nao te deixo", "nao vou te deixar",
        "nao vou embora", "nao vou sumir", "nao vou te abandonar", "nao te largo",
        "nao tenha medo", "nao precisa ter medo", "nao se preocupa", "nao se preocupe",
        "nao se desespera", "nao se desespere", "nao chora", "nao vai morrer", "nao morre",
        "nao vou parar", "nao desista", "vou ficar aqui", "fico aqui", "to do seu lado",
    ]

    /// Splits a message into the acts it actually contains, in order.
    ///
    /// Punctuation counts. In Portuguese the comfort comes first and is separated by a comma —
    /// "calma, pega a faca" — so while `,` and `.` weren't separators, the comfort cue won on
    /// position and the instruction next to it was thrown away (spec 013).
    ///
    /// It is also no longer all-or-nothing: parts that don't carry a verb are dropped, as long
    /// as at least one part does. Requiring *every* part to be actionable meant one unparsed
    /// fragment vetoed the whole split and silently killed the instruction beside it.
    static func splitClauses(_ playerText: String) -> [String] {
        let whole = [playerText]
        // Longest first, so " e depois " never splits as " e " leaving a stray "depois".
        // Punctuation goes last: single characters can't collide with the phrases above.
        let separators = [" e depois ", " e daí ", " e aí ", " depois disso ", ", depois ",
                          " depois ", " então ", " em seguida ", " e logo ", " e ", "; ", " após ",
                          ", ", ". ", "! ", "? ", ",", ".", "!", "?"]

        // Separators are matched on the original string with folding options, so the indices
        // are the player's own — no offset arithmetic between two different strings.
        var parts: [String] = []
        var remaining = playerText
        var separator: String?
        while parts.count < TurnRunner.maxClauses - 1 {
            let found = separators.compactMap { candidate -> (String, Range<String.Index>)? in
                guard let range = remaining.range(
                    of: candidate,
                    options: [.diacriticInsensitive, .caseInsensitive]
                ) else { return nil }
                return (candidate, range)
            }
            // Earliest match wins; ties go to the longest separator (they're listed longest first).
            guard let hit = found.min(by: { $0.1.lowerBound < $1.1.lowerBound }) else { break }
            separator = hit.0
            parts.append(String(remaining[..<hit.1.lowerBound]))
            remaining = String(remaining[hit.1.upperBound...])
        }
        guard separator != nil else { return whole }
        parts.append(remaining)

        let trimmed = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Keep the parts that stand on their own as an instruction. A bare yes/no is not an
        // act — "sim e pode ir" is one answer, not two — so those don't count either.
        let actionable = trimmed.filter { part in
            guard let verb = parse(part, state: GameState())?.verb else { return false }
            return ![.unknown, .yes, .no].contains(verb)
        }
        // Nothing survived: hand the whole message over so the single-clause path (and the
        // model behind it) still gets its shot.
        guard !actionable.isEmpty else { return whole }
        return actionable.count > 1 ? actionable : whole
    }

    static func parse(_ playerText: String, state: GameState) -> PlayerAction? {
        // Punctuation would otherwise glue itself to the last word and defeat the
        // whole-word lookups below ("vc ta bem?" must still match "vc ta bem").
        let text = playerText.folded
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        // Padding lets every lookup below demand whole words on both sides.
        let padded = " \(text) "
        let tone = classifyTone(padded: padded)

        guard let match = firstVerb(in: padded) else {
            // A pure emotional message with no verb is still a readable act. This is checked
            // before the bare-negator fallback below, so "não desisto de você" lands as comfort
            // rather than as a refusal.
            if tone != .neutral { return PlayerAction(verb: .talk, tone: tone) }
            // Nothing but a negation: that really is an answer of "no".
            if firstNegator(in: padded) != nil { return PlayerAction(verb: .no, tone: tone) }
            return nil
        }

        // "não entra na água" is the verb `.go` that she must NOT perform — not the verb `.no`.
        let isProhibition = negatorPrecedes(padded, match.range)

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
            tone: tone,
            isProhibition: isProhibition
        )
    }

    /// The tone of a whole message, read once. `TurnRunner` uses this so a message split into
    /// clauses is charged for how it lands exactly once, on the message, not per clause.
    static func messageTone(of playerText: String) -> Tone {
        let text = playerText.folded
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return .neutral }
        return classifyTone(padded: " \(text) ")
    }

    /// Whole-word only, and negation-aware. The old version also accepted a bare substring
    /// match, so "desisto" fired inside "não desisto de você" and a promise never to give up
    /// on her cost sanity and counted toward the abandonment death (spec 013).
    private static func classifyTone(padded: String) -> Tone {
        // A negated hostile phrase is not hostile. Checked first so "não vou embora" can't be
        // read as "vou embora".
        if matches(distressingCues, in: padded, ignoringNegated: true) { return .distressing }
        if matches(supportiveCues, in: padded, ignoringNegated: false) { return .supportive }
        return .neutral
    }

    /// Whether any cue occurs as a whole word. When `ignoringNegated` is on, an occurrence
    /// preceded by "não"/"nunca"/"jamais" doesn't count.
    private static func matches(_ cues: [String], in padded: String, ignoringNegated: Bool) -> Bool {
        cues.contains { cue in
            guard let range = padded.range(of: " \(cue.folded) ") else { return false }
            guard ignoringNegated else { return true }
            let inner = padded.index(after: range.lowerBound)..<range.upperBound
            return !negatorPrecedes(padded, inner)
        }
    }

    /// Position of the first bare negator, if the text has one.
    private static func firstNegator(in padded: String) -> Range<String.Index>? {
        bareNegators
            .compactMap { padded.range(of: " \($0) ") }
            .min { $0.lowerBound < $1.lowerBound }
    }

    /// Is there a "não"/"nunca"/"jamais" close enough before `range` to be negating it?
    /// Bounded by `negationReach` words so a negation early in a long sentence doesn't reach
    /// across the whole thing.
    private static func negatorPrecedes(_ padded: String, _ range: Range<String.Index>) -> Bool {
        let before = padded[padded.startIndex..<range.lowerBound]
        let words = before.split(separator: " ").map(String.init)
        return words.suffix(negationReach).contains { bareNegators.contains($0) }
    }

    private static func firstVerb(in padded: String) -> (verb: Verb, cue: String, range: Range<String.Index>)? {
        // Raw (space-padded) ranges throughout, so positions compare like with like — mixing
        // in the trimmed range made a longer cue at the same position always "win", which
        // broke the documented earliest-then-first-listed contract.
        var best: (verb: Verb, cue: String, raw: Range<String.Index>)?

        for (verb, cues) in verbCues {
            for cue in cues {
                // The surrounding spaces are the whole point: they stop "va" from matching
                // inside "descreva".
                guard let range = padded.range(of: " \(cue.folded) ") else { continue }
                if best == nil || range.lowerBound < best!.raw.lowerBound {
                    best = (verb, cue, range)
                }
            }
            // A cue that starts the sentence can't be beaten by anything later.
            if let best, best.raw.lowerBound == padded.startIndex {
                break
            }
        }

        guard let best else { return nil }
        // Trim the padding spaces back off so the remainder starts cleanly.
        let inner = padded.index(after: best.raw.lowerBound)..<padded.index(before: best.raw.upperBound)
        return (best.verb, best.cue, inner)
    }
}

nonisolated private extension String {
    /// Drops leading articles/prepositions so "a porta de aço" and "porta de aço" match alike.
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
