# DeepDive — Sessão de Decisões de Design (2026-07-20)

> Este documento registra TODAS as decisões tomadas na sessão de /grill-me entre o desenvolvedor (Richard) e o agente Antigravity. Use este documento como fonte de verdade para preencher `vision.md`, `AGENTS.md`, `architecture.md` e `spec 001`.

---

## Contexto do Projeto

**Nome:** DeepDive (renomeado de POC_EscapeRoom)
**Tipo:** Jogo de terror narrativo em formato de chat
**Status:** Projeto real (não é mais POC)
**Repositório:** `/Users/richardsiacc/Documents/Academy Projects/IA-Challenge/DeepDive`

---

## 1. Visão do Produto (para `docs/vision.md`)

### Problema
O jogador quer uma experiência de terror narrativo imersiva que simula uma conversa real de WhatsApp com alguém em perigo — sem mecânicas complexas de jogo, só a tensão de guiar um estranho pelo desconhecido.

### Conceito Central
- O jogador **NÃO vive a história**. Ele guia, à distância, alguém (o "personagem-chat") que está preso dentro dela.
- O contato é **completamente anônimo** — estranhos que nunca se conheceram antes, tipo um contato que chegou do nada.
- O personagem-chat **não tem vontade narrativa própria**: segue as instruções do jogador e relata o que acontece a seguir.
- O jogador **NÃO sabe qual caminho leva ao final bom**. Não existe walkthrough correto pré-definido. O caminho é moldado pelas escolhas do jogador ao longo da partida.

### Ambientação
- Baseada livremente na **lenda de Ratanabá** (suposta cidade/civilização pré-histórica soterrada na Amazônia brasileira, nunca comprovada, com túneis e ruínas geométricas).
- Usar a lenda como **inspiração de mundo**, NÃO recriar pessoas reais associadas a lendas amazônicas (pesquisadores, indígenas reais, exploradores desaparecidos) como personagens.
- A pessoa do chat está presa em uma **data temporal alternativa** dentro dessa cidade, onde presente, passado e futuro coexistem.
- A causa dessa sobreposição temporal é uma **anomalia sem explicação** — é assim, ponto, ninguém no universo do jogo sabe por quê. Isso é uma constante do mundo, não um mistério a ser resolvido e explicado no final.
- O **bestiário do jogo NÃO se limita a folclore brasileiro**: convivem criaturas de horror de cinema, folclore, mitologia e misticismo diversos. O que as une é pertencerem a essa cidade fora do tempo, não a origem cultural delas.

### Tom Narrativo
- Espectro entre **terror psicológico/ambíguo** e **horror cósmico** (insignificância humana).
- Um mesmo playthrough pode deslizar de um pro outro dependendo das escolhas do jogador.

### Finais
- **Múltiplos finais emergentes** (5 arquétipos de referência para o design):
  1. Escape com sanidade intacta
  2. Escape mudado ou marcado
  3. Sobrevive mas permanece preso de alguma forma
  4. Consumido pela cidade
  5. Morte narrativamente significativa
- Os finais são **função de estado acumulado** (sanidade, confiança do personagem-chat no jogador, pistas descobertas, regras da cidade respeitadas ou violadas) — **nunca** uma escolha direta de "final X" nem algo aleatório.
- **Nota:** Na v1, não haverá variáveis de estado. Os finais serão determinados puramente pelo grafo de nós. Variáveis de estado (sanidade, confiança, flags) são para specs futuras.

### Idioma
- **Português brasileiro (pt-BR)** para toda a narrativa do jogo.
- Inglês será adicionado em spec futura (i18n).

### Fora de Escopo (v1)
- Texto livre do jogador (usa botões pré-definidos)
- IA / Foundation Models
- Persistência de progresso (cada sessão começa do zero)
- Multiplayer
- Monetização
- Áudio / música
- Internacionalização (i18n)

---

## 2. Stack Tecnológica (para `AGENTS.md` e `docs/architecture.md`)

| Decisão | Valor | Justificativa |
|---------|-------|---------------|
| Plataforma | **iOS nativo** | Sem visionOS, sem multiplataforma |
| Framework UI | **SwiftUI** | Projeto Xcode já existe com SwiftUI |
| Deployment target | **iOS 17+** | Permite `@Observable`, SwiftData futuro, cobre 95%+ devices. Preparado para iOS 26+/27+ e nova Siri |
| Arquitetura | **MVVM** com `@Observable` | Padrão natural do SwiftUI, separa lógica de UI |
| Gerenciador de deps | **SPM** (Swift Package Manager) | Nativo, sem config extra |
| Game Engine | **FSM local em Swift** | Roda no device, determinístico, funciona offline |
| Formato narrativo | **JSON** com `Codable` | Nativo, sem dependências, data-driven |
| Persistência (v1) | **Nenhuma** | Cada sessão começa do zero. Spec futura para SwiftData |
| IA (v1) | **Nenhuma** | Validar game loop primeiro. IA vem depois como spec separada |

---

## 3. Regras para Agentes (para `AGENTS.md`)

### Divisão de Responsabilidade

| Agente | Modelo | Responsabilidade |
|--------|--------|-----------------|
| **Antigravity** | Claude Sonnet / Opus | Brainstorming, arquitetura, revisão, escrita de specs, ADRs, documentação |
| **Claude Code** | Claude (terminal) | Implementação, refatoração, testes, tarefas pesadas de código |

### Regra Inegociável
> **"Foundation Models nunca modificam diretamente o estado do jogo. Quem interpreta e narra é a IA; quem decide consequências e mantém o estado é o Game Engine."**

### Papel da IA no Jogo (para quando for implementada)
- Interpreta as instruções em linguagem livre do jogador
- Dá voz ao personagem-chat, mantendo consistência de tom e do que ele pode saber
- **NUNCA** decide o destino da história — quem decide isso é o Game Engine

---

## 4. Design da UI (para `docs/specs/001-chat-ui.md`)

### Estética
- **WhatsApp-like escuro**: fundo preto/cinza escuro, bolhas de mensagem com cores diferentes para jogador e personagem, timestamp sutil.

### Mecânica de Input
- **Botões/opções pré-definidas** (estilo Bandersnatch / jogos de escolha interativa)
- **SEM texto livre** por enquanto
- Botões aparecem **inline abaixo da última mensagem do personagem** — estilo "respostas rápidas" do WhatsApp/Telegram
- Quando o jogador toca num botão, ele vira uma mensagem enviada (como se o jogador tivesse digitado aquilo)

### Timing e Animações
- Respostas do personagem aparecem com **delay** (1-3 segundos)
- Animação de **"digitando..."** (3 pontinhos pulsando) durante o delay
- **Auto-scroll** para a última mensagem após cada nova mensagem

### Escopo da Spec 001
- Tela única de chat
- Lista de mensagens (jogador e personagem-chat) com bolhas
- Botões de opção inline
- Animação de "digitando..."
- Auto-scroll
- **Dados mockados/hardcoded** (sem Game Engine, sem JSON, sem IA)
- Status: será marcada como `approved` após registro

---

## 5. Game Engine (para spec futura 002)

### Estrutura
- **Grafo de nós (dialog tree)** definido em JSON
- Cada nó = uma "mensagem do personagem" + lista de opções disponíveis
- Cada opção aponta para o próximo nó
- Nós podem ter condições (spec futura: "só mostra essa opção se sanidade > 50")
- Finais são nós terminais
- **Totalmente data-driven**: editar o JSON, não o código Swift

### Variáveis de Estado (futuro)
- Sanidade (mental state)
- Confiança do personagem no jogador
- Pistas descobertas (inventory/flags)
- **Nota:** Na v1, NENHUMA variável de estado. Só o grafo de nós.

---

## 6. Roadmap de Specs Planejado

| Spec | Título | Escopo |
|------|--------|--------|
| 001 | Chat UI | Só a UI de chat com dados mockados |
| 002 | Game Engine | FSM + dialog tree JSON + mini-cenário |
| 003 | Integração UI + Engine | Conectar chat UI ao game engine |
| 004+ | Variáveis de estado | Sanidade, confiança, flags condicionais |
| 005+ | Persistência | Salvar/carregar progresso com SwiftData |
| 006+ | IA local | On-device intent parsing / modelo local |
| 007+ | i18n | Suporte a inglês |
| 008+ | Nova Siri | Integração com App Intents / Siri |

---

## 7. Instruções para o Claude Code

Ao receber este documento, o Claude Code deve:

1. **Ler** `docs/decisions/grill-me-session-2026-07-20.md` (este arquivo) como contexto
2. **Preencher** `docs/vision.md` com base na Seção 1
3. **Preencher** `AGENTS.md` com base nas Seções 2 e 3
4. **Preencher** `docs/architecture.md` com base nas Seções 2 e 5
5. **Preencher** `docs/specs/001-chat-ui.md` com base na Seção 4, e mudar status para `approved`
6. **Respeitar** a estrutura de seções já existente em cada arquivo (não criar seções novas sem necessidade)
7. **Atualizar** todos os documentos para inglês en-us

---

*Gerado em 2026-07-20 por Antigravity (Claude Opus) durante sessão /grill-me com Richard.*
