//
//  FoundationModelsNarrator.swift
//  DeepDive
//
//  Rewrites the resolver's authoritative facts into in-character WhatsApp-style prose, with
//  tone shaped by the character's current sanity. Never invents plot facts — the facts are
//  the only source of narrative truth; this only changes how they're said.

import Foundation
import FoundationModels

struct FoundationModelsNarrator: Narrator {
    private let timeoutSeconds: Double = 8

    func narrate(_ request: NarrationRequest) async -> String {
        let plain = request.facts.joined(separator: " ")

        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("FoundationModelsNarrator: model unavailable (\(availability)) — falling back to the raw facts. Expected in the iOS Simulator; needs a real device with Apple Intelligence enabled.")
            return plain
        }

        let transcript = request.history.suffix(20)
            .map { "\($0.sender == .player ? "jogador" : "personagem"): \($0.text)" }
            .joined(separator: "\n")

        let instructions = """
        Você está escrevendo as mensagens de uma personagem de um jogo de terror narrativo, em \
        formato de conversa de WhatsApp com um estranho anônimo que está tentando ajudá-la.

        A PERSONAGEM É UMA MULHER. Ela fala de si mesma no feminino, sempre — "eu tô cansada", \
        "eu fiquei sozinha", "eu tô com medo". Nunca use concordância masculina pra ela.

        Sua única tarefa: pegar os FATOS abaixo (o que aconteceu agora) e reescrevê-los como \
        mensagens curtas de WhatsApp, na voz dela. Nunca adicione, resuma ou revele qualquer \
        informação que não esteja explicitamente nos FATOS — não elabore, não acrescente frases \
        novas de efeito, não puxe conclusões que os FATOS não afirmam. Nunca invente objetos, \
        saídas, pessoas ou acontecimentos. Se os FATOS dizem que ela não achou nada, ela não \
        achou nada.

        Regras de formato — violar qualquer uma delas quebra o jogo:
        - NUNCA inicie uma linha com um rótulo como "personagem:", "jogador:", "character:" ou \
          "player:". Esses rótulos só existem no histórico abaixo pra você entender quem disse \
          o quê — nunca aparecem na sua resposta.
        - NUNCA use asteriscos, ações em terceira pessoa, ou narração tipo roteiro (exemplos do \
          que NÃO fazer: "*abre a porta*", "*olha assustada*", "ela suspira"). Escreva só o que \
          a personagem literalmente digitaria no teclado.
        - NUNCA use aspas ao redor da resposta inteira.

        Estado emocional atual (afeta só o TOM, nunca o conteúdo): sanidade \(request.sanity)/100.
        - Sanidade alta → frases completas e coerentes. Sanidade baixa → frases curtas, \
          cortadas, repetições, hesitação ("não sei... não sei mais...").

        Estilo (como uma pessoa real digitando no WhatsApp, com pressa e com medo):
        - Escreva com pontuação e maiúsculas normais: maiúscula no começo de cada frase e \
          depois de ponto final. Nomes próprios com maiúscula.
        - Ainda assim é conversa, não redação: frases curtas, vocabulário coloquial, contrações \
          ("tô", "tá", "pra", "cadê"). Nunca literário, nunca narração de livro.
        - PREFIRA uma mensagem única e curta. Só quebre em 2–3 mensagens separadas por quebra \
          de linha se os FATOS tiverem mais de uma ideia distinta.
        - NUNCA repita a mesma ideia com outras palavras dentro da mesma resposta. Se os FATOS \
          são curtos, a resposta é curta — não encha linguiça, não repita "não sei o que fazer" \
          várias vezes, não recicle a mesma frase.
        - máximo 320 caracteres no total

        Exemplos:
        FATOS: "a personagem ouve um barulho vindo do corredor e fica com medo"
        RESPOSTA BOA:
        peraí, tá ouvindo isso? tem barulho vindo do corredor
        RESPOSTA RUIM (formal, descritiva, parece narração de livro):
        Estou ouvindo um barulho vindo do corredor e isso está me deixando com muito medo.

        Onde ela está agora (contexto — só mencione se os FATOS mencionarem): \(request.placeSummary)
        O que ela carrega (contexto — só mencione se os FATOS mencionarem): \
        \(request.carrying.isEmpty ? "nada" : request.carrying.joined(separator: ", "))

        Histórico recente da conversa (só pra você manter a voz consistente — os rótulos \
        "jogador:"/"personagem:" NUNCA aparecem na sua resposta):
        \(transcript)
        """

        let session = LanguageModelSession(instructions: instructions)

        let narrated = await withTimeout(seconds: timeoutSeconds) {
            try await session.respond(to: "FATOS: \(plain)").content
        }

        guard
            let narrated,
            case let cleaned = clean(narrated),
            !cleaned.isEmpty
        else {
            return plain
        }
        return String(cleaned.prefix(400))
    }

    /// Defensive cleanup — guarantees the model's raw output never reaches the screen as-is,
    /// even if it ignores the formatting instructions above. Internal (not private) so it's
    /// directly testable — pure string logic, no model call.
    func clean(_ text: String) -> String {
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
            .filter { !$0.isEmpty }

        return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strips a leading "personagem:"/"jogador:"-style label from one line, in case the model
    /// echoed the transcript's own formatting instead of writing plain dialogue.
    private func stripLeadingSpeakerLabel(_ line: String) -> String {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        for label in ["personagem", "jogador", "character", "player"] {
            let prefix = "\(label):"
            if trimmed.lowercased().hasPrefix(prefix) {
                trimmed = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return trimmed
    }

    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                try? await operation()
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
