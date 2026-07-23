# DeepDive — Sessão de Decisões de Design (2026-07-23)

> Este documento registra as decisões tomadas para a Spec 005 (Persistence).

---

## Decisões — Spec 005 (Persistence)

### 1. O que persistir
**Estado completo:** snapshot de jogo + histórico de mensagens exibidas na tela.
- `currentNodeID: String`
- `flags: [String: Bool]`
- `ints: [String: Int]` (sanity, trust)
- `messages: [ChatMessage]` — histórico visual da conversa

O histórico de mensagens permite reconstruir a tela exatamente como estava ao retomar.

### 2. Número de save slots
**1 save slot único.** O jogo sempre salva e retoma a única sessão em andamento. Compatível com a proposta de imersão — o jogador guia um único estranho de cada vez.

### 3. Gatilho de save
**Auto-save após cada escolha do jogador** (após `engine.advance()` retornar com sucesso). O jogador nunca perde progresso. Nenhuma ação manual necessária.

### 4. Tecnologia de persistência
**SwiftData** — nativo iOS 17+, sem dependências externas. Integra com SwiftUI via `@Query` e `@Model`.

### 5. Comportamento ao abrir o app
Dois comportamentos planejados (só o primeiro entra na Spec 005):
- **Spec 005 (agora):** Se existir save, o app abre direto na `ChatView` retomando a conversa — igual ao WhatsApp que abre na última conversa. Sem menu.
- **Spec futura (Menu):** Um menu com botão "Continuar" (se existir save) + aba de Achievements com os finais atingidos.

### 6. Escopo da Spec 005
A Spec 005 foca **exclusivamente** em salvar e retomar a sessão em andamento via SwiftData. Menu e Achievements ficam para specs separadas futuras:
- Spec 008+ → Menu principal (Continuar / Novo Jogo)
- Spec 009+ → Achievements / finais atingidos

### 7. Ciclo de vida do save ao atingir um final
O save é **apagado automaticamente** quando `isTerminal = true`. Na próxima abertura, o jogo começa do zero (comportamento idêntico ao atual sem persistência).

---

*Gerado em 2026-07-23 por Antigravity (Claude Sonnet) durante sessão /grill-me com Richard.*
