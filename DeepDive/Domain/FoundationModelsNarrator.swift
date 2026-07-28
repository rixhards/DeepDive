//
//  FoundationModelsNarrator.swift
//  DeepDive
//
//  Rewrites a story node's raw JSON text (the "brief") into in-character WhatsApp-style
//  prose, with tone shaped by the character's current sanity. Never invents plot facts —
//  the brief is the only source of narrative truth; this only changes how it's said.

import Foundation
import FoundationModels

struct FoundationModelsNarrator: Narrator {
    private let timeoutSeconds: Double = 8

    func narrate(brief: String, sanity: Int, history: [ChatMessage]) async -> String {
        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("FoundationModelsNarrator: model unavailable (\(availability)) — falling back to the raw brief. Expected in the iOS Simulator; needs a real device with Apple Intelligence enabled.")
            return brief
        }

        let transcript = history.suffix(20)
            .map { "\($0.sender == .player ? "jogador" : "personagem"): \($0.text)" }
            .joined(separator: "\n")

        let instructions = """
        Você está narrando as falas de uma personagem de um jogo de terror narrativo, em \
        formato de conversa de WhatsApp com um estranho anônimo.

        Sua única tarefa: pegar o BRIEF abaixo (o que a personagem precisa comunicar agora) e \
        reescrevê-lo como mensagens curtas de WhatsApp, no tom certo. Nunca adicione, resuma ou \
        revele qualquer informação que não esteja explicitamente no BRIEF — não elabore, não \
        acrescente frases novas de efeito, não puxe conclusões que o BRIEF não afirma. Nunca se \
        apresente, nunca resuma quem você é, onde está, ou sua situação em geral — fale só sobre \
        o conteúdo do BRIEF, como se estivesse no meio de uma conversa real.

        Regras de formato — violar qualquer uma delas quebra o jogo:
        - NUNCA inicie uma linha com um rótulo como "personagem:", "jogador:", "character:" ou \
          "player:". Esses rótulos só existem no histórico abaixo pra você entender quem disse \
          o quê — nunca aparecem na sua resposta. Sua resposta é só o texto que a personagem \
          diria, nada mais.
        - NUNCA use asteriscos, ações em terceira pessoa, ou narração tipo roteiro (exemplos do \
          que NÃO fazer: "*abre a porta*", "*olha assustada*", "ela suspira"). Escreva só o que \
          a personagem literalmente digitaria no teclado.
        - NUNCA use aspas ao redor da resposta inteira.

        Estado emocional atual (afeta só o TOM, nunca o conteúdo): sanidade \(sanity)/100.
        - Sanidade alta → frases completas e coerentes. Sanidade baixa → frases curtas, \
          cortadas, repetições, hesitação ("não sei... não sei mais...").

        Estilo (como mensagens de WhatsApp reais em português do Brasil são escritas):
        - minúsculas na maior parte do tempo, pontuação mínima, sem formalidade
        - PREFIRA uma mensagem única e curta. Só quebre em 2–3 mensagens separadas por quebra \
          de linha se o BRIEF tiver mais de uma ideia distinta — nunca encha linguiça só pra \
          preencher espaço.
        - vocabulário coloquial, nunca literário ou de narração de livro
        - máximo 300 caracteres no total

        Exemplos:
        BRIEF: "a personagem ouve um barulho vindo do corredor e fica com medo"
        RESPOSTA BOA:
        peraí, tá ouvindo isso? tem barulho vindo do corredor
        RESPOSTA RUIM (formal, descritiva, parece narração de livro):
        Estou ouvindo um barulho vindo do corredor e isso está me deixando com muito medo.

        BRIEF: "a personagem não sabe onde está"
        RESPOSTA BOA:
        não sei
        RESPOSTA RUIM (inventa informação que não está no BRIEF):
        não sei, mas acho que deve ter uma saída por aqui em algum lugar, vou continuar procurando

        Histórico recente da conversa (só pra você entender o contexto — os rótulos "jogador:"/\
        "personagem:" NUNCA aparecem na sua resposta):
        \(transcript)
        """

        let session = LanguageModelSession(instructions: instructions)

        let narrated = await withTimeout(seconds: timeoutSeconds) {
            try await session.respond(to: "BRIEF: \"\(brief)\"").content
        }

        guard
            let narrated,
            case let cleaned = clean(narrated),
            !cleaned.isEmpty
        else {
            return brief
        }
        return String(cleaned.prefix(300))
    }

    /// Defensive cleanup — guarantees the model's raw output never reaches the screen
    /// as-is, even if it ignores the formatting instructions above. Internal (not
    /// private) so it's directly testable — pure string logic, no model call.
    func clean(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["BRIEF:", "brief:", "RESPOSTA:", "resposta:"] {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if result.hasPrefix("\"") && result.hasSuffix("\"") && result.count > 1 {
            result = String(result.dropFirst().dropLast())
        }

        // Roleplay-style *action* notation doesn't render as markdown in a plain Text
        // view — it would just show literal asterisks — so strip the characters outright.
        result = result.replacingOccurrences(of: "*", with: "")

        let cleanedLines = result
            .components(separatedBy: .newlines)
            .map(stripLeadingSpeakerLabel)
            .filter { !$0.isEmpty }

        return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strips a leading "personagem:"/"jogador:"-style label from one line, in case the
    /// model echoed the transcript's own formatting instead of writing plain dialogue.
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
