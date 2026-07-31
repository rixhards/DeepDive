# Spec 010 — Redesign visual (camada de apresentação)

## Status
`implemented`

## Contexto

A build atual é funcional, mas visualmente é um clone de app de mensagens em dark mode.
Nada na tela reforça a premissa do jogo — alguém escrevendo de um lugar fora do tempo.
Três problemas concretos:

1. `Theme.playerBubble` usa `Color.accentColor`, que resolve para o azul `#007AFF` padrão da
   Apple porque `Assets.xcassets/AccentColor.colorset` está vazio. É a cor mais "app de
   sistema" possível e quebra a ficção.
2. O `ChatView` mostra um ponto verde de "online" no header. Ela não está online — a
   convenção de chat contradiz a história.
3. `DebugFlags.showSanityMeter` está `true`, colocando um HUD numérico na tela. A
   `docs/vision.md` diz explicitamente que o jogo não deve ter HUD.

O redesign completo está no Figma (link abaixo), na página `02 · Redesign — Proposta`, com
os tokens na coleção `DeepDive Tokens` (modo `Dark` = build atual, modo `Redesign` = alvo).

**Escopo: só camada de apresentação.** Nada nesta spec exige mudar `ActionResolver`,
`GameState`, `WorldMap`, `TurnRunner` ou qualquer parser. Se a implementação começar a
tocar nesses arquivos, a spec está sendo mal interpretada — pare e revise.

## Objetivo

Substituir a paleta e o cromo do chat por uma linguagem visual própria, e trocar o medidor
numérico de sanidade por degradação ambiental, sem alterar nenhuma regra de jogo.

## Critérios de Aceite

- [x] `Theme.playerBubble` não referencia mais `Color.accentColor`; usa um petróleo
      dessaturado definido explicitamente (`#2A3A42`).
- [x] `Theme` ganha `accentLamp` (`#E8A94B`), usado apenas em hairlines, botão primário e
      no botão de enviar.
- [x] `Theme.background` deixa de ser `Color.black` chapado e passa a ser um gradiente
      vertical sutil (`#06080A` → `#0E1114`).
- [x] O ponto verde de "online" foi removido do header do `ChatView`.
- [x] O header mostra uma segunda linha `"sem operadora · sem data"` abaixo de
      `"número desconhecido"`.
- [x] `DebugFlags.showSanityMeter` é `false` e `SanityMeterView` não é mais instanciado em
      nenhuma tela. *(Aplicada a nota técnica: ambos foram apagados por completo, já que nada
      mais os referenciava.)*
- [x] Existe uma vinheta cuja intensidade deriva de `viewModel.currentSanity`: quanto menor
      a sanidade, mais fechada a vinheta.
- [x] As bolhas da personagem perdem contraste conforme a sanidade cai; as do jogador não.
- [x] O timestamp aparece só na última mensagem de cada bloco consecutivo do mesmo
      remetente, não em toda bolha.
- [x] O `ComposerView` usa um campo com hairline inferior, não mais a pílula preenchida.
- [x] O app compila com
      `xcodebuild -project DeepDive.xcodeproj -scheme DeepDive -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build`.

## Comportamento Esperado

### Fluxo Principal

O jogador não percebe nenhuma mudança de mecânica. Mesmas mensagens, mesmos verbos, mesmos
finais. O que muda é como a tela parece e como a sanidade é comunicada.

### Estados da UI

| Sanidade | Vinheta | Bolhas dela |
|----------|---------|-------------|
| ≥ 80 | fraca, quase imperceptível | opacidade 1.0 |
| 40–79 | média | opacidade ~0.85 |
| < 40 | fechada, véu frio por cima | opacidade ~0.72, tracking levemente aberto |

A transição entre faixas deve ser animada e lenta (≥ 1.5s) — o jogador não pode perceber um
"degrau" quando cruza um limiar, senão vira um HUD disfarçado.

## Casos de Borda

- **Acessibilidade:** a perda de contraste das falas dela é intencional, mas não pode
  impedir a leitura. Respeitar `accessibilityReduceTransparency` e, quando ligado, manter
  opacidade 1.0 e comunicar sanidade só pela vinheta.
- **Sanidade 0:** a tela de loucura já é um script pré-autorado e substitui o chat inteiro —
  a degradação ambiental não se aplica lá.
- **Dark/Light:** o jogo é dark-only. Não introduzir variante clara.
- **App Intents:** a Siri fala com o mesmo pipeline e não tem UI. Nada nesta spec pode
  quebrar `Intents/DeepDiveIntents.swift`.

## Design / Wireframe

Figma: https://www.figma.com/design/qMp5g2M3itjtBeMAeyRjnm/Richas-Game

- Página `01 · iOS — Atual` — reconstrução fiel da build atual, para comparação.
- Página `02 · Redesign — Proposta` — o alvo. Inclui `Chat — redesign · sanidade baixa`,
  que é a referência da degradação ambiental.
- Coleção de variáveis `DeepDive Tokens`, modo `Redesign` — valores exatos de cor.

## Notas Técnicas

- Os valores de cor estão como variáveis no Figma; leia-os de lá em vez de amostrar do
  screenshot.
- A vinheta é um overlay que não pode capturar toque — usar `.allowsHitTesting(false)`.
- A degradação depende de `currentSanity`, que já é exposto pelo `ChatViewModel`. Não
  adicionar estado novo — derive tudo do que já existe.
- Manter as views "burras" conforme a convenção do projeto: o cálculo de intensidade da
  vinheta vive no view model, não no corpo da view.
- `SanityMeterView.swift` e `DebugFlags.showSanityMeter` podem ser apagados por completo se
  nada mais os referenciar.

## Dependências

- Spec 008 (sanity rework) — precisa estar implementada, pois esta spec consome
  `currentSanity`.

## Histórico de Revisões

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-07-30 | Richard | Criação inicial a partir do redesign no Figma |
| 2026-07-30 | Claude Code | Implementada. Todos os critérios de aceite atendidos; build e os 74 testes existentes passam (nenhum arquivo de engine tocado). **Nota:** o arquivo do Figma contém apenas a página `01 · iOS — Atual` — a página `02 · Redesign — Proposta` e o modo `Redesign` da coleção `DeepDive Tokens` não existem lá (a coleção só expõe os valores atuais, incl. `color/bubble/player: #007aff`). Os valores-alvo foram lidos do texto desta spec, que os define por extenso. Extra fora da lista de critérios, mas dentro da causa raiz descrita no Contexto: `Assets.xcassets/AccentColor.colorset` estava vazio e foi preenchido com `#E8A94B`, senão controles de sistema (os botões do `confirmationDialog`) continuariam azuis. Degradação implementada por interpolação contínua entre as faixas da tabela, não por degraus. Status → `implemented`. |
