# DeepDive — Sessão de Decisões de Design (2026-07-22)

> Este documento registra as decisões tomadas para a fundação da Game Engine (Spec 002).

---

## 1. Estrutura do JSON (Design for the Future)

Decidimos adotar uma abordagem **forward-compatible** para o schema do JSON da narrativa.
Embora a engine inicial (Spec 002) não vá avaliar estados complexos, o JSON já deverá conter a estrutura necessária para suportar:
- **Conditions:** Condições exigidas para que uma opção de resposta apareça para o jogador (ex: `tem_chave_enferrujada == true`).
- **Effects (Flags):** Consequências de escolher uma opção, que alteram o estado do jogo (ex: definir `tem_chave_enferrujada = true`).

**Por quê?** Isso evita que a estrutura fundamental dos arquivos JSON de narrativa e os modelos do Swift precisem ser reescritos ou refatorados massivamente quando a Spec 004+ (Variáveis de Estado) chegar.

## 2. Fronteira da Engine (API do Domínio)

Adotamos a abordagem de **DTO (Data Transfer Object) focado na apresentação** para a comunicação da Engine com a UI.

- A `GameEngine` lerá o arquivo JSON completo (`story.json`) decodificando-o em modelos ricos (ex: `StoryNode`, `StoryOption`, `Condition`, `Effect`).
- Quando a UI (`ChatViewModel`) pedir para avançar a história, a `GameEngine` fará o processamento interno (resolvendo flags e verificando quais opções o jogador tem o direito de ver) e devolverá um modelo simplificado focado em apresentação (ex: `EngineResponse` contendo apenas a string da fala e as opções válidas).

**Por quê?** Isso garante a separação de responsabilidades do MVVM. A UI fica "cega" para as complexidades da narrativa, garantindo que o acoplamento seja mínimo.

## 3. Escopo da Spec 002

A Spec 002 será **estritamente focada na lógica da engine**, isolada da interface.

**O que entra:**
- Classe `GameEngine` baseada numa FSM (Finite State Machine).
- Modelos `Codable` para o schema do JSON (preparados para o futuro).
- Arquivo `story.json` com um mini-cenário expandido da Spec 001.
- Unit Tests robustos provando a navegação pelos nós e a decodificação do JSON.

**O que fica de fora:**
- A UI não vai mudar na Spec 002 (continuará usando dados mockados). A integração real acontecerá apenas na Spec 003.
- Processamento real de sanidade e inventário (a engine apenas lerá esses campos sem aplicá-los por enquanto).

---

## Decisões — Spec 003 (UI + Engine Integration)

### 1. Destino do ChatViewModel
O `ChatViewModel` existente será **reescrito** para usar a `GameEngine` real.
- O `init` do ViewModel passa a receber uma `GameEngine` (injetada via dependency injection).
- As chamadas internas mudam de `MockConversation`/`ConversationNode` para `engine.start()` e `engine.advance(choosing:)`.

### 2. Limpeza dos modelos antigos
`ConversationNode.swift` e `MockConversation.swift` serão **mantidos** no projeto por ora (não deletados), mas deixarão de ser referenciados pelo `ChatViewModel`. A remoção formal será incluída como subtarefa da própria Spec 003.

### 3. Tratamento de erro no carregamento
O `ChatViewModel` terá inicialização **lazy/assíncrona**:
- Começa num estado `loading`.
- Tenta instanciar a `GameEngine` (que carrega o `story.json`).
- Se falhar, transita para um estado `failed(Error)`, exibindo uma tela de erro simples (`ErrorView`).
- Esse padrão prepara o app para futuros cenários de carregamento remoto (Spec 006+).

### 4. Impacto nas Views
**Zero mudança nas Views** da Spec 003. A `ChatView`, `MessageBubble`, `OptionButtonsView` e `TypingIndicatorView` permanecem idênticas — elas já funcionam corretamente com as propriedades que o ViewModel expõe (`messages`, `currentOptions`, `isTyping`, `isFinished`).

### 5. Mapeamento EngineOption → UI
O ViewModel **não expõe `EngineOption` diretamente** para a View. Em vez disso:
- Cria um tipo de apresentação intermediário (`ChatOption`) contendo apenas `id: String` e `text: String`.
- Mapeia `EngineOption → ChatOption` internamente.
- A `OptionButtonsView` usa `ChatOption.id` para chamar `engine.advance(choosing:)`.
- Isso desacopla a View dos tipos do Domain.

### 6. Testes na Spec 003
A Spec 003 incluirá **testes de integração leves** no target `DeepDiveTests`:
- Instanciar `ChatViewModel` com uma `GameEngine` criada a partir de um `story.json` de fixture controlado.
- Simular uma sequência de escolhas e verificar que `messages` e `currentOptions` refletem o estado correto.

---

*Gerado em 2026-07-22 por Antigravity (Gemini/Claude Sonnet) durante sessão /grill-me com Richard.*
