# Arquitetura — Jogo de Terror Psicológico em Chat (iOS/Swift)

> **Documento histórico, arquivado em `docs/historical/`.** Isto é um briefing
> pré-implementação — foi escrito para orientar um agente ANTES do código existir, e **não
> descreve o sistema atual**. A arquitetura vigente é a simulação de mundo em Swift descrita em
> [`ADR-002`](../adr/ADR-002-world-simulation-in-swift.md). Mantido apenas como registro
> histórico da arquitetura originalmente planejada.
>
> **Divergências conhecidas entre este documento e o código atual:**
> - Declara `GameState { trustLevel: Int }`; o campo real é `sanity` (`trustLevel` tem zero
>   ocorrências no código — o `trust` foi removido no spec 008).
> - Diz "100% construído via Claude Code"; `README.md`/`CLAUDE.md` descrevem uma divisão onde o
>   Antigravity escreve specs, arquitetura e faz review, e o Claude Code implementa.
> - Recomenda "2 subagents: revisão e testes"; hoje existe apenas `spec-reviewer`, e não há
>   test target no projeto (removido no commit `d07fc52`).
> - Não menciona `LocalActionParser.swift` (290 linhas), que hoje decide quase todo o
>   comportamento em produção — o parser determinístico não existia quando isto foi escrito.

> Documento de handoff. Leia isto antes de começar a implementar.
> Objetivo do jogo: jogador troca mensagens de texto com uma personagem; a
> história avança conforme as respostas do jogador. Gênero: terror psicológico.

## Requisitos obrigatórios
- Foundation Models framework (ou Core ML como plano B/complemento) para
  interpretar linguagem natural e narrar
- App Intents + Shortcuts como parte real do design (não só requisito técnico)
- 100% construído via Claude Code, com boas práticas de mercado

## Princípio central
**O LLM nunca é dono do estado do jogo.** Ele só interpreta o que o jogador
tentou fazer/dizer e narra a consequência. Quem decide o que realmente
acontece é código Swift determinístico.

```
Texto do jogador
      ↓
LLM interpreta intenção (structured output via @Generable)
      ↓
Engine Swift decide o resultado (regras determinísticas)
      ↓
LLM narra o resultado dentro do tom da personagem
```

## O que são "beats"
Beat = ponto narrativo significativo, não uma troca de mensagem. É definido
por uma combinação de estado (localização + flags), autorado à mão por nós,
não gerado pelo modelo. O beat só avança quando a engine Swift decide que as
condições foram satisfeitas.

Beats são também a unidade natural de **gerenciamento de contexto**: resetar
a sessão do LanguageModelSession deve acontecer nas transições de beat, nunca
no meio de uma cena.

## Estrutura de estado (Swift, fonte da verdade)
```swift
struct GameState: Codable, Sendable {
    var currentBeat: BeatID
    var flags: Set<StoryFlag>
    var trustLevel: Int
    var turn: Int
    var isFinished: Bool
}

struct StoryMemory: Codable {
    var immutableFacts: [String]
    var currentObjectives: [String]
    var discoveredInformation: Set<String>
    var recentNarrative: [String]   // últimas trocas, não o histórico todo
}
```
O `GameState`/`StoryMemory` em Swift é o save file. A sessão do LLM é
descartável.

## Foundation Models — pontos técnicos confirmados
- Framework nativo Swift, roda on-device, sem custo de token, funciona offline
- Usa `@Generable` para gerar output estruturado (não pedir JSON solto)
- **Janela de contexto: 4096 tokens por sessão** (entrada + saída somadas).
  É fixo, não muda por device.
- Desde iOS 26.4: `SystemLanguageModel.default.contextSize` e métodos de
  contagem de tokens permitem gerenciar o orçamento proativamente, em vez de
  só reagir ao erro `exceededContextWindowSize`
- Guardrails de segurança são sempre aplicados e **não podem ser desativados**
  — podem recusar conteúdo sombrio mesmo em contexto ficcional. Teste cedo as
  cenas mais pesadas da história pra descobrir onde isso trava.
- `checkModelAvailability()` precisa tratar múltiplos casos (device não
  elegível, Apple Intelligence desligada, modelo baixando) — não é só um
  booleano disponível/indisponível

### Estratégia de contexto (evita o "loop" por falta de memória)
1. Nunca colar o histórico de chat inteiro no prompt
2. Resetar a sessão nos limites de beat
3. Reidratar a sessão nova só com: flags ativas + beat atual + resumo curto
   (1–2 frases) do que aconteceu de relevante
4. Monitorar `contextSize` proativamente antes de estourar

## App Intents + Shortcuts — uso no design
Não é só requisito técnico — usar pra reforçar a imersão de terror:
- `AppIntent` que permite Siri/Atalhos "falar" com a personagem fora do app
- Automação de Atalhos disparando notificação em horário aleatório, como se a
  personagem tivesse mandado mensagem sem o jogador abrir o app
- `AppShortcutsProvider` pra expor isso nos Atalhos sem configuração manual

## Divisão de responsabilidades
| Camada | Responsável |
|---|---|
| Mapa, causalidade, puzzles, personagens, fatos, finais | Autorado por nós |
| Interpretação de texto livre, falas, descrições, transições | Gerado pelo modelo |

## Stack
- SwiftUI (MVVM) + SwiftData (persistência)
- `LanguageModelSession` com `instructions` fixas (tom/persona) e
  `@Generable` para interpretação estruturada
- Tool calling: opcional, considerar só depois do MVP (guided generation é
  mais fácil de debugar/testar no início)

## Setup recomendado no Claude Code (projeto pequeno)
- 1 Skill de projeto documentando esta arquitetura e as convenções Swift
- 2 subagents: revisão (state machine / sessão do LLM) e testes
- Comandos slash pontuais (ex: `/new-beat`) em vez de framework
  multi-agente pronto de terceiros
