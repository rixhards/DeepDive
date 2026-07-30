# DeepDive — Instrução de Refatoração Completa

> **Para:** Claude Code (Fable 5)
> **De:** Richard (product owner)
> **Data:** 2026-07-29
> **Objetivo:** Refatorar o projeto inteiro, reduzindo o escopo e corrigindo bugs.
>
> **Fontes de verdade (na raiz do projeto):**
> - `ARCHITECTURE.md` — stack técnica, princípios, estrutura de estado, Foundation Models, App Intents
> - `GAME_SCOPE.md` — conteúdo narrativo, cenas, itens, mecânicas, finais
>
> Este documento traduz ambos em instruções executáveis de implementação.
> **Não expanda o escopo.** Não adicione cenas, itens, finais ou personagens além dos listados.

---

## 1. O Que É o DeepDive

Um jogo de **terror psicológico narrativo** para **iOS nativo** (iOS 26+, SwiftUI), jogado inteiramente por uma interface de chat estilo WhatsApp. O jogador guia, por mensagens, uma **mulher anônima** presa numa cidade impossível inspirada no mito de Ratanabá. O jogador nunca vive a história — ele manda mensagens e lê o que acontece.

**A personagem é MULHER.** Toda concordância em pt-BR é no feminino: "eu tô cansada", "eu fiquei sozinha", "eu tô com medo". Não invente nome para ela.

**Nyarlathotep** é a entidade do jogo. Use como referência de tom (irracionalidade, loucura instantânea ao avistá-lo) — **nunca cite a obra de Lovecraft diretamente** no texto do jogo.

**Idiomas:**
- Código, identificadores, comentários, docs → **Inglês**
- Texto narrativo in-game → **Português do Brasil (pt-BR)**

---

## 2. Regras Invioláveis

1. **AI nunca controla estado de jogo.** Foundation Models só interpretam (ActionParser) e narram (Narrator). O Game Engine (ActionResolver) decide tudo. O LLM propõe; a engine dispõe.
2. **Zero dependências externas.** Apenas frameworks Apple (SwiftUI, Foundation, SwiftData, FoundationModels, AVFoundation, AppIntents).
3. **Narrativa é dado declarativo.** Todo texto narrativo vive em `WorldMap.swift` como declarações — beats, features, items, endings. Sem prose em views ou control flow.
4. **Sem pessoas reais como personagens.**
5. **Não expanda o escopo.** Não adicione cenas, itens, finais ou personagens além dos listados no GAME_SCOPE.md.

---

## 3. Arquitetura

### 3.1 Princípio Central (de ARCHITECTURE.md)

```
Texto do jogador
      ↓
LLM interpreta intenção (structured output via @Generable)
      ↓
Engine Swift decide o resultado (regras determinísticas)
      ↓
LLM narra o resultado dentro do tom da personagem
```

### 3.2 Diagrama de Camadas

```
Presentation (SwiftUI)
  ChatView · MessageBubble · ComposerView · MenuView · EndingRevealView
         ↕ @Observable
  ChatViewModel
         ↓ free text                    ↑ narrated reply
  ActionParser (text → verb + target + tone)
         ↓
  ActionResolver (deterministic world simulation)
         ↕
  GameState + StoryMemory (authoritative state)
  WorldMap (all narrative prose, declarative)
         ↓
  Narrator (facts → in-character pt-BR prose)
         ↓
  SessionRepository (SwiftData persistence)
         ↓
  AudioManager (AVFoundation — menu + ending music)
         ↓
  App Intents + Shortcuts (Siri integration)
```

### 3.3 Estrutura de Estado (Nova — substituir a struct `World` atual)

Conforme definido em ARCHITECTURE.md, o estado deve ser **separado em duas structs**:

```swift
/// Authoritative game state. The AI reads this but never writes to it.
struct GameState: Codable, Sendable {
    var currentBeat: BeatID        // Where she is right now
    var flags: Set<StoryFlag>      // Boolean flags (knockedWoodDoor, knifeBroken, etc.)
    var sanity: Int                // 0–100, starts at 80
    var turn: Int                  // Counts turns for varied responses
    var isFinished: Bool           // True when an ending is reached
    var inventory: Set<ItemID>     // Items she carries
    var lampFuel: Int              // Lamp fuel remaining (starts ~5)
    var ending: Ending?            // Which ending was reached
    var pending: PendingChoice?    // Irreversible move awaiting confirmation
    var visited: Set<BeatID>       // Beats already visited
    var comfortsTaken: Int         // How many times she's been reassured
    var symbolReadings: Int        // How many times she's studied carvings
}

/// Context for the LLM session. Discardable — rebuilt from GameState at beat boundaries.
struct StoryMemory: Codable {
    var immutableFacts: [String]         // Core facts that never change (setting, premise)
    var currentObjectives: [String]      // What she's trying to do right now
    var discoveredInformation: Set<String> // Things learned during play
    var recentNarrative: [String]        // Last few exchanges, NOT the full history
}
```

**`GameState` + `StoryMemory` in Swift is the save file. A sessão do LLM é descartável.**

> [!IMPORTANT]
> `trustLevel` NÃO EXISTE. Foi removido. Só `sanity`.

### 3.4 BeatID (substituir PlaceID)

O conceito de "beat" é a unidade de progressão do jogo. Cada beat corresponde a uma localização/cena:

```swift
enum BeatID: String, Codable, CaseIterable {
    case salao         // Salão Principal (spawn)
    case waterTrail    // Trilha na Água (fatal)
    case trifurcacao   // Trifurcação (hub)
    case corridor      // Corredor Escuro
    case steelDoor     // Outro lado da Porta de Aço (caverna → saída)
    case hayRoom       // Sala da Porta de Madeira
}
```

Renomear `PlaceID` → `BeatID` em todo o código. Renomear `Place` → `Beat` (ou manter `Place` internamente se fizer mais sentido — o identificador canônico é `BeatID`).

---

## 4. Foundation Models — Pontos Técnicos (de ARCHITECTURE.md)

### 4.1 Capacidades Confirmadas
- Framework nativo Swift, roda on-device, sem custo de token, funciona offline
- Usa `@Generable` para gerar output estruturado
- **Janela de contexto: 4096 tokens por sessão** (entrada + saída somadas). É fixo.
- Desde iOS 26.4: `SystemLanguageModel.default.contextSize` e métodos de contagem de tokens para gerenciamento proativo
- Guardrails de segurança são sempre aplicados e **não podem ser desativados** — podem recusar conteúdo sombrio. Por isso, mortes e cenas pesadas devem ser **conteúdo fixo pré-autorado**, NÃO gerado pelo modelo
- `checkModelAvailability()` precisa tratar múltiplos casos (device não elegível, Apple Intelligence desligada, modelo baixando)

### 4.2 Estratégia de Contexto (IMPLEMENTAR AGORA)

> [!IMPORTANT]
> Isto é uma mudança significativa em relação ao código atual. Implementar conforme ARCHITECTURE.md.

1. **Nunca colar o histórico de chat inteiro no prompt.** O código atual passa `messages.suffix(20)` — isso vai estourar o contexto rapidamente.
2. **Resetar a `LanguageModelSession` nos limites de beat** (quando a personagem muda de cena/beat).
3. **Reidratar a sessão nova** só com: flags ativas + beat atual + resumo curto (1–2 frases) do que aconteceu de relevante (usar `StoryMemory`).
4. **Monitorar `contextSize` proativamente** usando `SystemLanguageModel.default.contextSize` antes de estourar, em vez de só reagir ao erro `exceededContextWindowSize`.

### 4.3 Classificação de Tom do Jogador (Mudança no ActionParser)

O GAME_SCOPE.md define que o impacto das mensagens do jogador na sanidade deve usar **geração guiada com enum fechado**. Expandir o `InterpretedAction` existente:

```swift
@Generable
struct InterpretedAction {
    @Guide(description: "The verb...")
    var verb: String

    @Guide(description: "The target...")
    var target: String

    @Guide(description: "The instrument...")
    var instrument: String

    @Guide(description: """
    The emotional tone of the player's message toward the character. \
    Use "supportive" for encouragement, comfort, reassurance, or positive words. \
    Use "distressing" for hostile, cruel, insulting, dismissive, or dark messages. \
    Use "neutral" for instructions, questions, or anything that is neither supportive nor distressing.
    """)
    var tone: String  // "supportive" | "neutral" | "distressing"
}
```

**Remover `isHostile: Bool`.** Substituir por `tone` com 3 valores. O Swift mapeia deterministicamente:
- `supportive` → sanity +2
- `neutral` → sanity ±0
- `distressing` → sanity -4

O LLM **só classifica**; o número é determinístico.

---

## 5. Mapa de Beats (Cenas)

### 5.1 Mapa Visual

```
                    ┌──────────────┐
                    │ Salão        │ (spawn point)
                    │ Principal    │
                    └──────┬───────┘
                           │
               ┌───────────┴───────────┐
               │                       │
     ┌─────────▼─────────┐   ┌────────▼────────┐
     │ Trilha na Água    │   │ Trifurcação     │
     │ (FATAL)           │   │ (hub central)    │
     └───────────────────┘   └────────┬─────────┘
                                      │
                        ┌─────────────┼─────────────┐
                        │             │             │
              ┌─────────▼──┐   ┌──────▼─────┐  ┌───▼────────────┐
              │ Corredor   │   │ Porta de   │  │ Sala da Porta  │
              │ Escuro     │   │ Aço (exit) │  │ de Madeira     │
              └────────────┘   └────────────┘  └────────────────┘
```

### 5.2 Descrições Detalhadas

#### Salão Principal (`salao`) — Spawn Point
- **Descrição:** Ruína irracional: construções de pedra antigas, algumas de cabeça para baixo no teto, pilares, árvores, goteiras, umidade.
- **Dois caminhos:** trilha na água, estrada de paralelepípedos até a trifurcação.
- **Cena NEUTRA** — sem perigo.
- **Features:** pilares (com entalhes), água (parada, estranha), árvores (tortas), teto (alto, goteiras), símbolos/entalhes, estrada de paralelepípedos.
- **Arrival:** Ela acorda confusa e assustada. Tem lampião na mão (já aceso). Pede ajuda.
- **A faca está no chão** deste lugar, no caminho em direção à trifurcação.
- **Exits:** waterTrail, trifurcacao

#### Trilha na Água (`waterTrail`) — SEMPRE FATAL
- **Descrição:** Ambiente úmido tipo gruta. Água calma, vai ficando profunda até a barriga.
- **PendingChoice:** Ela pergunta antes de entrar. Se confirma → morte garantida.
- **Comportamento:** Água profunda → algo se mexe de forma irracional → criatura ataca → morte.
- **Ending:** `.death`

#### Trifurcação (`trifurcacao`) — Hub Central
- **Descrição:** 3 caminhos — corredor escuro (esquerda), porta de aço trancada (centro), porta de madeira sem trava (direita).
- **Cena NEUTRA** — sem perigo.
- **Features:** porta de madeira (arranhões), porta de aço/ferro (maciça, fechadura grande), corredor escuro.
- **Sound:** corrente de ar assobiando do corredor, arrastado atrás da porta de madeira.
- **Exits:** corridor, steelDoor (requer chave), hayRoom, salao (volta)

#### Corredor Escuro (`corridor`)
- **Descrição:** Longo, tipo túnel de catacumba velha. Nunca dá pra ver o fim, mesmo com luz.
- **Com lampião ACESO → PendingChoice → MORTE:** Corredor infinito, som sinistro, som dos dois lados, trava, silêncio.
- **Com lampião APAGADO → BYPASS:** Sai do outro lado, ao lado da porta de aço → `steelDoor` → Fuga (por sanidade).
- **Ending (aceso):** `.death`

#### Além da Porta de Aço (`steelDoor`) — Caminho para Fuga
- **Descrição:** Caverna com menos umidade. No fim, luz que leva à floresta amazônica.
- **Comportamento:** Chegou aqui → final de Fuga ativado (variante por sanidade).
- **Ending:** `.escape` (3 variantes)

#### Sala da Porta de Madeira (`hayRoom`) — Chave + Perigos
- **Descrição:** Sala apertada, claustrofóbica, cheia de feno. O feno bloqueia visão.
- **Mecânica da porta:**
  - NÃO bateu antes de entrar → criatura escondida no feno → puxa ela → `.death`
  - BATEU antes de entrar → criatura foi embora → seguro entrar
- **A CHAVE está aqui**, brilhando no feno.
- **Morte extra (fogo):** Atear fogo no feno com lampião → porta tranca, fumaça, asfixia → `.death`
- **Exit:** trifurcacao (volta)

### 5.3 Regra de Retorno

A personagem pode voltar de qualquer cena atual para o **Salão** ou **Trifurcação** (cenas neutras) a qualquer momento que o jogador disser "voltar" — inclusive antes de uma cena de morte, como forma de escapar.

---

## 6. Itens

### 6.1 ItemID Enum

```swift
enum ItemID: String, Codable, CaseIterable {
    case knife   // Faca simples
    case lamp    // Lampião
    case key     // Chave da porta de aço
}
```

> [!CAUTION]
> **Remove `ItemID.seal`** (disco de pedra). Não existe mais no jogo.

### 6.2 Detalhes

| Item | Onde encontrar | Usos | Aliases |
|------|---------------|------|---------|
| **Faca** | Chão do Salão, a caminho da trifurcação | 1) Cortar feno → chave com segurança (faca perdida) 2) Lockpick porta de aço → faca quebra, porta continua trancada | faca, lâmina, canivete |
| **Lampião** | Com ela ao acordar, já aceso | Toggle aceso/apagado. Consome combustível por cena se aceso. ~5 cenas de fuel. | lampião, lamparina, lanterna, luz |
| **Chave** | Sala da porta de madeira, brilhando no feno | Abre porta de aço → rota da fuga | chave, chavinha |

### 6.3 Mecânica de Pegar a Chave

- **Com a faca** → Corta feno, chave OK, faca perdida no feno. Sem penalidade.
- **Com mãos nuas** → Chave OK, mas arranhada por algo no feno. **Sanidade -20.**

---

## 7. Mecânicas

### 7.1 Lampião — Combustível

- Constante nomeada e testável (ex: `static let initialLampFuel = 5`). Não número espalhado pelo código.
- Estado: `aceso` / `apagado` (flag no GameState).
- Consome 1 fuel por troca de beat se aceso.
- Quando fuel = 0 → apaga sozinho, não pode reacender.
- Personagem avisa quando fuel está baixo.
- **Sempre pergunta** se deve seguir com lampião aceso ou apagado antes de beats como corredor, trilha, sala do feno.

### 7.2 Sanidade

- Escala 0–100, inicia em **80**.
- **Impacto do tom do jogador** (via `@Generable` tone classification):
  - `supportive` → +2
  - `neutral` → ±0
  - `distressing` → -4
- **Impacto de eventos:**
  - Pegar chave com mãos: **-20**
  - Examinar coisas perturbadoras: **-2 a -8**
  - Gritar: **-2 a -6**
  - Estudar símbolos (escala): **-4, -8, -13, -18**
- Quando = 0 → Ending `.madness`
- **Sem proteção anti-farm** por enquanto (aceitável nesta fase).

### 7.3 Confirmação Obrigatória (PendingChoice)

Antes de **qualquer ação ou transição perigosa**, a personagem pergunta. Nenhuma morte acontece sem confirmação explícita do jogador. Inclui:
- Seguir por caminho fatal (água, corredor)
- Pegar chave com as mãos
- Lockpick na porta de aço
- Acender/apagar lampião antes de área escura
- Atear fogo no feno

### 7.4 Mensagens Não-Lineares

A personagem pode mandar 2, 3+ mensagens em sequência (`beats` no Outcome) quando faz sentido: reagir + descrever + perguntar, ou cenas de morte que se desenrolam em múltiplas mensagens.

### 7.5 Mortes são Conteúdo Fixo

> [!IMPORTANT]
> **Todas as cenas de morte são pré-autoradas (roteiro fixo).** O LLM narra dentro desse roteiro, variando apenas frases de transição/reação — **nunca decide o desfecho nem inventa a cena.** Isso evita bloqueio de guardrail do Foundation Models e garante timing do clímax. Mesmo tratamento para o final de Loucura.

---

## 8. Finais (Endings)

### 8.1 Ending Enum

```swift
enum Ending: String, Codable {
    case escape     // Fuga (o único final bom)
    case death      // Morte (4 cenários diferentes)
    case madness    // Loucura (sanidade = 0)
}
```

> [!IMPORTANT]
> Renomear: `taken` → `death`, `surrender` → `madness` em todo o código.

### 8.2 Fuga (`escape`) — Único Final Bom

| Sanidade | Resultado |
|----------|-----------|
| ≥ 80 | Foge ilesa. Final positivo. |
| 40–79 | Foge, mas transtornada. Carrega o trauma. |
| < 40 | **Recusa ir embora.** Quer "explorar mais". Jogo encerra. (Variante do escape, não ending separado.) |

**Rota alternativa:** Corredor com lampião apagado → bypass para steelDoor → mesma lógica de sanidade.

### 8.3 Morte (`death`) — 4 Cenários

| # | Cenário | Trigger |
|---|---------|---------|
| 1 | Morte na água | Confirmar entrada na trilha |
| 2 | Morte no corredor | Entrar com lampião aceso |
| 3 | Morte monstro (hayRoom) | Entrar sem bater na porta antes |
| 4 | Morte fogo (hayRoom) | Atear fogo no feno após bater na porta |

### 8.4 Loucura (`madness`)

Sanidade = 0: ela diz que não quer sair, que ali é bom, quer ficar para sempre. Fala em "língua" sem sentido com símbolos estranhos. Roteiro fixo.

---

## 9. Telas de Final

Cada final tem tela exclusiva com frase curta **original** (sem citação direta de nenhuma obra):

| Final | Inspiração de tom | Regra |
|-------|------------------|-------|
| Fuga | Lendas sobre Ratanabá / cidades perdidas | 1 frase original |
| Loucura | "O Rei de Amarelo" (Robert W. Chambers) | 1 frase original |
| Morte | Contos de Lovecraft (incompreensão cósmica) | Sortear entre até 5 frases originais |

> Fique à vontade para gerar essas frases; serão refinadas depois.

---

## 10. App Intents + Shortcuts (de ARCHITECTURE.md)

### 10.1 Objetivo

Não é só requisito técnico — usar para reforçar a imersão de terror:

- `AppIntent` que permite Siri/Atalhos "falar" com a personagem fora do app
- Automação de Atalhos disparando notificação em horário aleatório, como se a personagem tivesse mandado mensagem sem o jogador abrir o app
- `AppShortcutsProvider` para expor isso nos Atalhos sem configuração manual

### 10.2 Implementação

- Criar um `AppIntent` que aceita uma mensagem do jogador e retorna a resposta da personagem
- Usar `AppShortcutsProvider` para registrar os atalhos
- A resposta segue o mesmo pipeline: parser → resolver → narrator
- O GameState deve ser acessível fora do contexto do app (via shared container ou UserDefaults suite)

---

## 11. Áudio

### 11.1 Som Ambiente

- **Onde toca:** Menu e telas de final (EndingRevealView).
- **Tipo:** Música instrumental, melancólica e sombria, sem vocal, sem copyright.
- **Volume:** Moderado.
- **Implementação:** `AVAudioPlayer` (AVFoundation). Arquivo `.mp3` ou `.m4a` no bundle.
- **Comportamento:** Loop no menu. Para ao iniciar partida. Volta ao atingir final.
- **Criar `AudioManager`** como classe separada para gerenciar playback.

> [!NOTE]
> Implementar a infraestrutura de áudio com placeholder. O arquivo real será adicionado depois.

---

## 12. O Que Mudar no Código

### 12.1 Remover
- `PlaceID` → substituir por `BeatID`
- `ItemID.seal` — disco não existe mais
- `Ending.taken` → renomear para `.death`
- `Ending.surrender` → renomear para `.madness`
- `World` struct (unificada) → separar em `GameState` + `StoryMemory`
- Places: `escadaria`, `cisterna`, `coroa` — substituídos pelo novo mapa
- `PendingChoice.swimCistern` — não existe mais
- Flags obsoletas: `.sawFalseLight`, `.heardTheMusic` (reavaliar)
- Interações do selo/disco (`resolveSeal`, etc.)
- `InterpretedAction.isHostile: Bool` → substituir por `tone: String`
- `PlayerAction.isHostile: Bool` → substituir por tone handling
- `trustLevel` — não existe (nem no código atual, mas garantir)

### 12.2 Adicionar
- `BeatID.waterTrail`, `.corridor`, `.steelDoor`
- `Ending.death`, `.madness`
- `GameState` + `StoryMemory` (substituir `World`)
- `lampFuel: Int` no GameState
- Tone classification (`supportive | neutral | distressing`) no InterpretedAction
- Context management: reset de sessão por beat, reidratação com StoryMemory
- `AudioManager` para música ambiente
- App Intents + `AppShortcutsProvider`
- Frases originais de final em WorldMap ou EndingRevealView
- Lógica de morte na água, corredor, monstro, fogo
- Variantes do escape por sanidade

### 12.3 Modificar
- `WorldMap.swift`: Reescrever com os 6 novos beats
- `ActionResolver.swift`: Novas regras de interação para todas as cenas
- `PendingChoice.swift`: Novas confirmações
- `EndingRevealView.swift`: Telas exclusivas com frases
- `ChatViewModel.swift`: Integrar combustível, novos finais, context management
- `FoundationModelsActionParser.swift`: Tone field, context strategy
- `FoundationModelsNarrator.swift`: Context strategy, StoryMemory
- `LocalActionParser.swift`: Ajustar cues para novas ações
- `SessionRepository.swift`: Persistir GameState + StoryMemory em vez de World

---

## 13. Fluxograma de Uma Run

```
1. App abre → Menu (música ambiente tocando)
2. "Começar" → ChatView (música para)
3. Personagem acorda no Salão (lampião aceso, faca no chão)
4. Jogador pode:
   a. Ir pela água → PendingChoice → se confirma → MORTE NA ÁGUA
   b. Ir pela estrada → Trifurcação
5. Na Trifurcação:
   a. Corredor escuro:
      - Lampião aceso → PendingChoice → MORTE NO CORREDOR
      - Lampião apagado → bypass → steelDoor → FUGA (por sanidade)
   b. Porta de aço (centro):
      - Sem chave → trancada
      - Com chave → steelDoor → FUGA (por sanidade)
      - Com faca → faca quebra, porta continua trancada
   c. Porta de madeira (direita):
      - Sem bater → criatura → MORTE MONSTRO
      - Bater → ouve arrastar → criatura vai embora → entrar seguro
        - Pegar chave com faca → OK, faca perdida
        - Pegar chave com mão → OK, sanidade -20
        - Atear fogo → MORTE FOGO
   d. Voltar pro salão → seguro
6. Sanidade = 0 a qualquer momento → LOUCURA
7. Final atingido → EndingRevealView com frase + música ambiente
```

---

## 14. Divisão de Responsabilidades (de ARCHITECTURE.md)

| Camada | Responsável |
|--------|-------------|
| Mapa, causalidade, puzzles, personagens, fatos, finais | **Autorado por nós** (código Swift declarativo) |
| Interpretação de texto livre, falas, descrições, transições | **Gerado pelo modelo** (Foundation Models) |

---

## 15. Build & Testing

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project DeepDive.xcodeproj \
  -scheme DeepDive \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

- Verificar simuladores: `xcrun simctl list devices available`
- Ajustar `DEVELOPER_DIR` e nome do simulador conforme setup local
- **Não lance o Simulator.** Richard testa no device físico (iPhone 16, iOS 26.5).
- Agents só verificam que **compila**.
- Testes: escrever apenas quando for a única forma de verificar algo. Sem suítes amplas.
- Manter `DebugFlags.showSanityMeter` ligado durante dev. Desligar antes de ship.
- Incrementar `SessionRepository.schemaVersion` ao mudar GameState.

---

## 16. UI

- Botão de 3 pontos (canto superior direito): "Reiniciar" (nova run) e "Menu" (volta ao menu)
- Chat estilo WhatsApp: bolhas de mensagem, typing indicator, auto-scroll
- Manter a estética dark existente (Theme.swift)

---

## 17. Resumo das Mudanças

| Antes | Depois |
|-------|--------|
| `PlaceID` com 6 lugares (salão, trifurcação, hayRoom, escadaria, cisterna, coroa) | `BeatID` com 6 beats (salão, waterTrail, trifurcação, corridor, steelDoor, hayRoom) |
| Struct `World` unificada | `GameState` + `StoryMemory` separados |
| `isHostile: Bool` | `tone: supportive/neutral/distressing` |
| 4 itens (faca, lampião, chave, selo) | 3 itens (faca, lampião, chave) |
| `escape / surrender / taken` | `escape / madness / death` |
| Sem combustível de lampião | Com combustível (~5 cenas) |
| Sem context management | Reset por beat + StoryMemory + contextSize monitoring |
| Sem áudio | Música ambiente no menu e tela de final |
| Sem App Intents | App Intents + Shortcuts para Siri |
| Sem frases temáticas | Frases originais por ending |
| Histórico completo no prompt | StoryMemory compacta |
| Fuga com variante única | Fuga com 3 variantes de sanidade |
