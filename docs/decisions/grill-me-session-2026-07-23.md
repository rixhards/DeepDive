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

---

## Decisões — Spec 006 (On-Device AI — Intent Parsing) e Spec 007 (Dynamic Narration)

### Decisão estratégica: Atualizar deployment target
O iOS 26+ será o novo mínimo do projeto. Foundation Models (Apple Intelligence) estará disponível para iPhone 11+ com iOS 27. O `CLAUDE.md`, `vision.md`, `architecture.md` e `README.md` devem ser atualizados para refletir iOS 26+.

### 1. Papel da IA
A Foundation Models habilita **conversa em linguagem natural**: o jogador digita livremente, a IA entende a intenção e o personagem responde como uma pessoa real, adaptando tom conforme sanidade e confiança. Intent parsing (Spec 006) + narração dinâmica (Spec 007) separados em specs independentes.

### 2. Specs separadas
- **Spec 006:** Intent Parsing — a IA converte texto livre do jogador em uma opção válida da engine.
- **Spec 007:** Dynamic Narration — a IA reescreve o texto do nó JSON para soar como uma pessoa real adaptando tom por sanidade/trust.

### 3. Narração: briefing interno
O texto do JSON vira um "briefing" passado para a Foundation Models ("O personagem precisa comunicar X. Escreva como uma mensagem de WhatsApp de uma pessoa real"). A IA gera o texto final. O JSON nunca aparece diretamente na tela.

### 4. Deployment target
iOS 26+ obrigatório. Sem fallback para iOS 17-25. Atualizar todos os documentos e o `Info.plist`/`xcodeproj` como parte da Spec 006.

### 5. UX de geração
Comportamento de mensageiro real: typing indicator aparece → personagem "digita" → mensagem aparece completa de uma vez. Sem streaming token-a-token visível. Duração do typing varia proporcionalmente ao tamanho da mensagem gerada.

### 6. Input do jogador na Spec 006
Campo de texto livre substitui os botões de opção. Só disponível quando Foundation Models está acessível (sempre, dado iOS 26+ obrigatório).

### 7. Intent incerto
A IA retorna a opção mais próxima encontrada E gera uma resposta do personagem pedindo reformulação ("Não entendi bem... o que você quis dizer?"), mantendo as opções visíveis. Jogador tenta de novo.

### 8. Contexto da IA
**Histórico completo de mensagens + estado de jogo completo** (sanidade, trust, flags). Foundation Models é on-device e gratuito — sem custo por token, sem limite econômico.

---

*Atualizado em 2026-07-23 por Antigravity (Claude Sonnet) — decisões Specs 006 e 007.*
