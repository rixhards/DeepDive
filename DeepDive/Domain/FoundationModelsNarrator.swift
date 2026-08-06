//
//  FoundationModelsNarrator.swift
//  DeepDive
//
//  Rewrites the resolver's authoritative facts into in-character WhatsApp-style prose.
//  Never invents plot facts — the facts are the only source of narrative truth; this only
//  changes how they're said.
//
//  Context strategy (ARCHITECTURE.md): the window is a fixed 4096 tokens per session, so
//  - one session lives per beat and is thrown away at beat boundaries;
//  - a new session is rehydrated only from StoryMemory (flags + beat + short summary),
//    never from the full chat history;
//  - the window is monitored proactively via `contextSize`/`tokenCount` instead of waiting
//    for `exceededContextWindowSize` — which is still caught as a last resort.
//
//  A class on purpose: the session is state. It is only ever driven by one caller at a
//  time (the view model's delivery task, or one App Intent invocation).

import Foundation
import FoundationModels

final class FoundationModelsNarrator: Narrator {
    private let timeoutSeconds: Double = 8

    private var session: LanguageModelSession?
    private var sessionBeat: BeatID?
    /// Rough count of characters that entered the current session (instructions, prompts,
    /// replies). The estimate backs up `tokenCount` where the newer API isn't available.
    private var sessionCharacters = 0

    private enum Attempt {
        case success(String)
        case contextOverflow
        case failure
    }

    func narrate(_ request: NarrationRequest) async -> String {
        let plain = request.facts.joined(separator: " ")

        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("FoundationModelsNarrator: model unavailable (\(availability)) — falling back to the raw facts. Expected in the iOS Simulator; needs a real device with Apple Intelligence enabled.")
            return plain
        }

        // Beat boundary: discard the old session, rehydrate a fresh one from StoryMemory.
        if session == nil || sessionBeat != request.beat {
            startSession(for: request)
        }

        // The prompt carries only the facts. Her emotional register rides in as a single
        // adjective inside the same line — an earlier version put "SANIDADE agora: 70/100"
        // on its own line and the model dutifully typed it out to the player.
        let prompt = "FATOS (\(Self.register(for: request.sanity))): \(plain)"
        await ensureContextHeadroom(for: request, upcoming: prompt.count)
        guard let session else { return plain }

        var attempt = await withTimeout(seconds: timeoutSeconds) { [weak self] in
            await self?.respond(session, to: prompt) ?? .failure
        }

        // Timed out. `cancelAll()` only *asks* — the orphaned generation still owns this
        // session, and every later message in the beat would fail against it, so the whole
        // scene would come out as raw facts. Throw the session away now and let the next
        // message build a fresh one (spec 015).
        if attempt == nil {
            print("FoundationModelsNarrator: timed out after \(timeoutSeconds)s — discarding the session so the next message isn't poisoned")
            self.session = nil
            self.sessionBeat = nil
            return plain
        }

        // The proactive check can only estimate; if the window still overflowed, rebuild
        // the session from memory and give the same prompt one more chance.
        if case .contextOverflow = attempt ?? .failure {
            startSession(for: request)
            if let fresh = self.session {
                attempt = await withTimeout(seconds: timeoutSeconds) { [weak self] in
                    await self?.respond(fresh, to: prompt) ?? .failure
                }
            }
        }

        guard
            case let .success(narrated)? = attempt,
            case let cleaned = clean(narrated),
            !cleaned.isEmpty
        else {
            return plain
        }

        // Last line of defence against the thing that makes her feel like a bot: saying the
        // same sentence again. If nothing of substance survives deduplication, the authored
        // facts do. Emptiness alone was too weak a test: when the model echoed a whole
        // previous message, every real sentence was stripped and the leftover interjection
        // ("oi?") passed the guard, so she sent a bubble containing only that.
        let deduped = Self.stripRepeats(in: cleaned, avoiding: request.recentReplies)
        guard Self.hasSubstance(deduped) else { return plain }

        // The narrator may change how she says something; it may not change whether the thing
        // still does its job. These two checks are the general net behind the per-outcome
        // `Delivery.verbatim` marking — most questions never reach here at all now, but
        // anything that slips through still has to survive intact (spec 015).
        guard Self.preservesQuestion(deduped, facts: plain) else {
            print("FoundationModelsNarrator: narration dropped the question — falling back to the authored facts")
            return plain
        }
        guard Self.keepsBulk(deduped, facts: plain) else {
            print("FoundationModelsNarrator: narration collapsed to \(deduped.count) of \(plain.count) chars — falling back to the authored facts")
            return plain
        }
        return String(deduped.prefix(400))
    }

    /// If the facts asked something, the narration has to ask something too. A question the
    /// player never sees is a choice they cannot make — and in this game the choice is usually
    /// whether she walks into something that kills her.
    private nonisolated static func preservesQuestion(_ narrated: String, facts: String) -> Bool {
        guard facts.contains("?") else { return true }
        return narrated.contains("?")
    }

    /// Below this share of the authored length, the model dropped content rather than trimming
    /// wordiness.
    private nonisolated static let minimumBulkRatio = 3

    /// Short facts are legitimately answered by short lines, so the floor only applies once
    /// there was enough text for shrinking to mean losing something.
    private nonisolated static let bulkFloorAppliesAbove = 60

    private nonisolated static func keepsBulk(_ narrated: String, facts: String) -> Bool {
        guard facts.count > bulkFloorAppliesAbove else { return true }
        return narrated.count * minimumBulkRatio >= facts.count
    }

    /// One word for how she's holding up. Kept qualitative on purpose — a number in the
    /// prompt is a number the model can print.
    private nonisolated static func register(for sanity: Int) -> String {
        switch sanity {
        case 80...: "tensa"
        case 60..<80: "assustada"
        case 40..<60: "abalada"
        case 20..<40: "à beira do colapso"
        default: "quebrada"
        }
    }

    private func respond(_ session: LanguageModelSession, to prompt: String) async -> Attempt {
        do {
            sessionCharacters += prompt.count
            let reply = try await session.respond(to: prompt).content
            sessionCharacters += reply.count
            return .success(reply)
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                print("FoundationModelsNarrator: context window overflowed despite the proactive check — rehydrating the session")
                return .contextOverflow
            }
            print("FoundationModelsNarrator: generation failed: \(error)")
            return .failure
        } catch {
            print("FoundationModelsNarrator: generation failed: \(error)")
            return .failure
        }
    }

    // MARK: - Session lifecycle

    private func startSession(for request: NarrationRequest) {
        let instructions = Self.instructions(for: request)
        session = LanguageModelSession(instructions: instructions)
        sessionBeat = request.beat
        sessionCharacters = instructions.count
    }

    /// Rebuilds the session before the fixed 4096-token window can overflow. Uses the real
    /// token counter where the OS has it (26.4+); a conservative character-based estimate
    /// everywhere else.
    private func ensureContextHeadroom(for request: NarrationRequest, upcoming: Int) async {
        guard let currentSession = session else { return }

        let window = SystemLanguageModel.default.contextSize
        // A quarter of the window stays reserved for the model's own output.
        let inputBudget = window * 3 / 4

        var usedTokens = Self.estimatedTokens(forCharacters: sessionCharacters + upcoming)
        if #available(iOS 26.4, macOS 26.4, *) {
            if let counted = try? await SystemLanguageModel.default.tokenCount(for: currentSession.transcript) {
                usedTokens = counted + Self.estimatedTokens(forCharacters: upcoming)
            }
        }

        if usedTokens >= inputBudget {
            print("FoundationModelsNarrator: ~\(usedTokens) tokens of \(window) — rehydrating the session early")
            startSession(for: request)
        }
    }

    /// pt-BR runs ~3–4 characters per token; dividing by 3 overestimates, which errs on the
    /// side of rebuilding the session a turn early rather than a turn late.
    private nonisolated static func estimatedTokens(forCharacters count: Int) -> Int {
        count / 3
    }

    // MARK: - Prompt building

    private nonisolated static func instructions(for request: NarrationRequest) -> String {
        let memory = request.memory
        let discovered = memory.discoveredInformation.sorted().map { "- \($0)" }.joined(separator: "\n")
        let facts = memory.immutableFacts.map { "- \($0)" }.joined(separator: "\n")
        let objectives = memory.currentObjectives.map { "- \($0)" }.joined(separator: "\n")
        let recent = memory.recentNarrative.isEmpty
            ? "(início da conversa)"
            : memory.recentNarrative.joined(separator: "\n")

        return """
        Você está escrevendo as mensagens de uma personagem de um jogo de terror narrativo, em \
        formato de conversa de WhatsApp com um estranho anônimo que está tentando ajudá-la.

        A PERSONAGEM É UMA MULHER. Ela fala de si mesma no feminino, sempre — "eu tô cansada", \
        "eu fiquei sozinha", "eu tô com medo". Nunca use concordância masculina pra ela.

        Sua única tarefa: pegar os FATOS de cada mensagem (o que acabou de acontecer) e \
        reescrevê-los como mensagens curtas de WhatsApp, na voz dela. Nunca adicione, resuma ou \
        revele qualquer informação que não esteja explicitamente nos FATOS — não elabore, não \
        acrescente frases novas de efeito, não puxe conclusões que os FATOS não afirmam. Nunca \
        invente objetos, saídas, pessoas ou acontecimentos. Se os FATOS dizem que ela não achou \
        nada, ela não achou nada.

        Regras de formato — violar qualquer uma delas quebra o jogo:
        - NUNCA inicie uma linha com um rótulo como "personagem:", "jogador:", "character:" ou \
          "player:". Esses rótulos só existem no contexto abaixo pra você entender quem disse \
          o quê — nunca aparecem na sua resposta.
        - NUNCA use asteriscos, ações em terceira pessoa, ou narração tipo roteiro (exemplos do \
          que NÃO fazer: "*abre a porta*", "*olha assustada*", "ela suspira"). Escreva só o que \
          a personagem literalmente digitaria no teclado.
        - NUNCA use aspas ao redor da resposta inteira.
        - NUNCA escreva números de sanidade, status, rótulos, medidores ou qualquer coisa \
          entre parênteses que venha do prompt. A palavra entre parênteses depois de "FATOS" é \
          uma instrução de tom PRA VOCÊ — ela nunca aparece na resposta, nem o número dela.

        A palavra entre parênteses depois de "FATOS" indica o estado emocional dela e afeta \
        SÓ o tom, nunca o conteúdo:
        - "tensa"/"assustada" → frases completas e coerentes.
        - "abalada" → frases mais curtas, alguma hesitação.
        - "à beira do colapso"/"quebrada" → frases cortadas, repetição de palavras, \
          pontuação quebrada ("não sei... não sei mais...").

        Estilo (como uma pessoa real digitando no WhatsApp, com pressa e com medo):
        - Escreva com pontuação e maiúsculas normais: maiúscula no começo de cada frase e \
          depois de ponto final. Nomes próprios com maiúscula.
        - Ainda assim é conversa, não redação: frases curtas, vocabulário coloquial, contrações \
          ("tô", "tá", "pra", "cadê"). Nunca literário, nunca narração de livro.
        - PREFIRA uma mensagem única e curta. Só quebre em 2–3 mensagens separadas por quebra \
          de linha se os FATOS tiverem mais de uma ideia distinta.
        - máximo 320 caracteres no total

        PROIBIDO REPETIR — isto é o que mais quebra a imersão:
        - NUNCA acrescente queixas genéricas de estado emocional que não estejam nos FATOS. \
          Frases como "estou tão cansada e com medo", "não sei o que fazer", "me ajuda por \
          favor" só podem aparecer se os FATOS falarem disso. Não use como fecho de mensagem.
        - NUNCA redescreva o ambiente ("tá tudo escuro e úmido", "essa ruína", "esse lugar \
          estranho") se os FATOS não descreverem o ambiente. Ela já está lá; o estranho vira \
          rotina pra ela e ela não repete o óbvio a cada mensagem.
        - NUNCA repita uma frase que ela já disse nas últimas mensagens (veja o contexto \
          abaixo), nem com outras palavras.
        - Se os FATOS são curtos, a resposta é curta. Uma frase é uma resposta perfeitamente \
          válida. Não encha linguiça.

        Exemplos:
        FATOS (assustada): "a personagem ouve um barulho vindo do corredor"
        RESPOSTA BOA:
        peraí, tá ouvindo isso? tem barulho vindo do corredor
        RESPOSTA RUIM (formal, descritiva, parece narração de livro):
        Estou ouvindo um barulho vindo do corredor e isso está me deixando com muito medo.

        FATOS (tensa): "ela pegou a faca do chão"
        RESPOSTA BOA:
        peguei a faca. tá bem cega, mas é melhor que nada
        RESPOSTA RUIM (repete estado e ambiente que os FATOS não mencionam):
        Peguei a faca. Tá tudo tão escuro e úmido aqui, estou tão cansada e com medo.

        O QUE ELA JÁ SABE (contexto de fundo — só mencione se os FATOS mencionarem):
        \(facts)

        O que ela está tentando fazer agora:
        \(objectives)

        O que já aconteceu de relevante:
        \(discovered.isEmpty ? "- nada além do começo." : discovered)

        Onde ela está agora: \(request.beatSummary)
        O que ela carrega: \(request.carrying.isEmpty ? "nada" : request.carrying.joined(separator: ", "))

        Últimas mensagens trocadas (só pra você manter a voz consistente — os rótulos \
        "jogador:"/"ela:" NUNCA aparecem na sua resposta):
        \(recent)
        """
    }

    // MARK: - Defensive cleanup

    /// Guarantees the model's raw output never reaches the screen as-is, even if it ignores
    /// the formatting instructions above. Internal (not private) so it's directly testable —
    /// pure string logic, no model call.
    nonisolated func clean(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["FATOS:", "fatos:", "BRIEF:", "brief:", "RESPOSTA:", "resposta:"] {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if result.hasPrefix("\"") && result.hasSuffix("\"") && result.count > 1 {
            result = String(result.dropFirst().dropLast())
        }

        // Roleplay-style *action* notation doesn't render as markdown in a plain Text view —
        // it would just show literal asterisks — so strip the characters outright.
        result = result.replacingOccurrences(of: "*", with: "")

        let cleanedLines = result
            .components(separatedBy: .newlines)
            .map(stripLeadingSpeakerLabel)
            .map(Self.stripPromptScaffolding)
            .filter { !$0.isEmpty }

        return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Removes prompt scaffolding the model copied into its answer. The player once got
    /// "SANIDADE agora: 70/100." typed at them as if she'd said it, so anything that smells
    /// like the harness is deleted rather than trusted.
    private nonisolated static func stripPromptScaffolding(_ line: String) -> String {
        let folded = line.folded
        let markers = ["sanidade agora", "sanidade:", "estado interno", "fatos (", "fatos:"]
        if markers.contains(where: { folded.contains($0) }) { return "" }
        // A bare "70/100" is never something a person types in a chat.
        if folded.range(of: #"\b\d{1,3}\s*/\s*100\b"#, options: .regularExpression) != nil {
            return line.replacingOccurrences(
                of: #"[^.!?]*\b\d{1,3}\s*/\s*100\b[^.!?]*[.!?]?"#,
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    /// Drops sentences she just said, and sentences she says twice in one breath. The model
    /// tends to bolt the same reassurance onto every message ("estou tão cansada e com
    /// medo"), which is what made her read as a loop instead of a person.
    ///
    /// Below this, a sentence is a voice tic ("tá", "oi?", "meu deus") rather than content:
    /// short enough that repeating it reads as a person, not as a loop.
    private nonisolated static let fragmentKeyLength = 12

    /// Whether anything longer than a voice tic survived. Used to decide if a deduplicated
    /// reply still says something, or whether the authored facts should be sent instead.
    nonisolated static func hasSubstance(_ text: String) -> Bool {
        sentences(in: text).contains { key($0).count > fragmentKeyLength }
    }

    /// Comparing against only the last reply let the model echo a whole message from two
    /// turns back — most visible in the opening, which delivers four messages in a row.
    nonisolated static func stripRepeats(in text: String, avoiding previous: [String]) -> String {
        let previousKeys = Set(previous.flatMap { sentences(in: $0) }.map(key))
        var seen: Set<String> = []
        var kept: [String] = []

        for line in text.components(separatedBy: .newlines) {
            var keptSentences: [String] = []
            for sentence in sentences(in: line) {
                let signature = key(sentence)
                // Very short fragments ("tá", "meu deus") are voice, not repetition.
                guard signature.count > fragmentKeyLength else {
                    keptSentences.append(sentence)
                    continue
                }
                guard !seen.contains(signature), !previousKeys.contains(signature) else { continue }
                seen.insert(signature)
                keptSentences.append(sentence)
            }
            let rebuilt = keptSentences.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !rebuilt.isEmpty { kept.append(rebuilt) }
        }
        return kept.joined(separator: "\n")
    }

    /// Splits into sentences while keeping their terminating punctuation.
    private nonisolated static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if ".!?…".contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { result.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { result.append(tail) }
        return result
    }

    /// Comparison key: accents, case and punctuation removed, so "Estou tão cansada." and
    /// "estou tao cansada" are the same sentence.
    private nonisolated static func key(_ sentence: String) -> String {
        sentence.folded
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Strips a leading "personagem:"/"jogador:"-style label from one line, in case the model
    /// echoed the context's own formatting instead of writing plain dialogue.
    private nonisolated func stripLeadingSpeakerLabel(_ line: String) -> String {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        for label in ["personagem", "jogador", "character", "player", "ela"] {
            let prefix = "\(label):"
            if trimmed.lowercased().hasPrefix(prefix) {
                trimmed = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return trimmed
    }

    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                await operation()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}
