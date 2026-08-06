# Spec 013 — Parser de português: preâmbulo emocional, negação e default seguro

## Status
`implemented`

## Contexto

O jogo inteiro passa por uma caixa de texto. A premissa é que o jogador **conforte e guie** uma
pessoa em perigo. Uma auditoria de ponta a ponta mediu o que acontece quando alguém escreve
português natural, e o resultado é que a gramática mais óbvia de "confortar e guiar na mesma
mensagem" é justamente a que o parser não aceita.

Isso não é hipótese. **Duas das cinco screenshots de marketing em `docs/app-store/screenshots/`
capturam o defeito ao vivo**, e a página de suporte publicada em `docs/suporte.html` ensina ao
jogador frases que não funcionam.

O `LocalActionParser` casa palavras-chave por posição: vence o cue mais à esquerda da frase. Em
português, o conforto vem primeiro e separado por vírgula — e vírgula não é separador de
cláusula. Então o conforto ganha e a ordem morre. Pior: a palavra "não" é cue do verbo `.no`,
o que transforma qualquer frase de apoio que contenha "não" numa recusa.

## Objetivo

Fazer o parser entender três coisas que todo falante de português usa e que hoje quebram o jogo:
**preâmbulo emocional antes da ordem**, **negação**, e **saudações**. E tornar o default de
`resolveUse` seguro, para que incerteza nunca vire uma ação com custo.

## Levantamento inicial

Medido com um harness headless que compila a camada `Domain/` fora do Xcode e roda o
`LocalActionParser` + `ActionResolver` reais. Todos os casos abaixo foram reproduzidos:

| O jogador escreve | Hoje | Deveria |
|---|---|---|
| `"Calma, eu to aqui com voce. Olha em volta e me diz o que tem ai."` *(screenshot `03-conforto`)* | `verb=talk` — a ordem "olha em volta" é **descartada** | conforta **e** descreve |
| `"Procura uma saida. Vai pela estrada de pedra, nao entra na agua."` *(screenshot `04-agua`)* | `verb=use target=agua` → **ela encosta na água e perde 2 de sanidade** | procura/anda; **não** toca na água |
| `"calma, pega a faca"` | `verb=talk`, não age no mundo | conforta e pega a faca |
| `"não tenha medo, eu tô aqui"` | `verb=no` — **cancela a pergunta pendente** | conforto, pendência preservada |
| `"não desisto de você"` | `tom=distressing` → −4 e 1 strike rumo à morte por abandono | `tom=supportive` |
| `"eu não vou embora"` | `tom=distressing` | `tom=supportive` |
| `"não abre essa porta"` (sem pendência) | *"eu não perguntei nada."* | ela entende a proibição |
| `"oi"` | não reconhecido | ela responde |
| `"o que você tá vendo?"` *(ensinado em `suporte.html`)* | não reconhecido | descreve o lugar |

Causas isoladas no código:

1. **Vírgula e ponto não separam cláusulas.** `LocalActionParser.splitClauses` tem `" e "`,
   `" então "`, `"; "`, `" depois "` — mas não `,` nem `.`.
2. **O veto `allActionable`.** Se *qualquer* parte do split não casar com um cue, o split inteiro
   é descartado e a mensagem volta a ser uma cláusula só. Um fragmento não reconhecido anula a
   instrução reconhecida ao lado dele. Falha para o lado de não fazer nada.
3. **Negação não é modelada.** `"nao"` é cue de `.no` em `answerCues`, que é a primeira lista
   consultada.
4. **`"procura"` está na lista de cues do verbo `.use`**, que significa *tocar/manipular*.
5. **Tom por substring cru.** `classifyTone` faz `text.contains(cue)` sem fronteira de palavra,
   então `"desisto"` casa dentro de `"não desisto"`.
6. **`resolveUse` é fail-dangerous.** Quando nada casa, ele toca no primeiro substantivo da frase
   que exista como feature, **cobra sanidade** e narra o toque.
7. **`InterpretedAction.verb` documenta 11 dos 20 verbos** e omite `yes`/`no`, então o modelo
   nunca soube que confirmação existe.

## Decisões

1. **`,` `.` `!` `?` viram separadores de cláusula**, junto dos atuais. É assim que se escreve
   "calma, pega a faca".
2. **O veto `allActionable` cai.** Passa a valer: executa as cláusulas que casam, ignora as que
   não casam, desde que **pelo menos uma** case. Se nenhuma casar, a mensagem inteira volta a ser
   tratada como uma cláusula só (comportamento atual).
3. **Negação é um modificador de cláusula, não um verbo.** `não`/`nunca`/`jamais` imediatamente
   antes de um cue de ação marca aquela cláusula como **proibição**. O verbo `.no` passa a valer
   só para respostas curtas e isoladas (`"não"`, `"melhor não"`, `"nem pensar"`), não para
   qualquer frase que contenha a palavra.
4. **Proibição tem efeito real:** com pendência aberta, é uma recusa (mesmo efeito de `.no`).
   Sem pendência, ela reconhece a instrução em ficção e não age.
5. **`procura`/`vasculha`/`cava`/`revira` saem de `.use`.** Buscar é examinar o lugar, não
   manipular um objeto.
6. **Tom só casa por palavra inteira.** O fallback `text.contains(cue)` some. E a checagem de
   negação roda antes: `"não"` + cue hostil = apoio, não hostilidade.
7. **Novo verbo `.greet`** para `oi`/`olá`/`ok`/`beleza`/`tá bom`/`entendi`. Saudação não é
   `.talk` ("como você está?") nem `.unknown`.
8. **`resolveUse` passa a fail-safe.** Sem correspondência, ela **pergunta** em vez de tocar. O
   toque em cenário continua existindo, mas só quando o jogador nomeia a feature com um verbo de
   toque explícito (`toca`, `encosta`).
9. **`InterpretedAction` passa a listar os 20 verbos**, em português, com `yes`/`no` incluídos.
   O tipo do campo continua `String` (`@Generable` com enum fica para outra spec).

**Fora de escopo:** balanceamento (rota do corredor escuro, economia de óleo), anti-farm de
sanidade (deferido de propósito — ver briefing histórico), e o futuro do `Narrator`.

### Ajustes feitos durante a implementação

Duas decisões acima ficaram mais limpas como verbos próprios do que como regras espalhadas:

- **`Verb.search` em vez de mandar `procura` para `.examine`** (decisão 5). Colapsar os dois
  perderia a distinção que sustenta o único puzzle do jogo: *"olha pro feno"* descreve o feno,
  *"revira o feno"* enfia a mão nele — mesmo substantivo, atos diferentes, e só um acha a chave.
- **`Verb.touch` em vez de um sinalizador em `.use`** (decisão 8). O toque custa sanidade; um
  custo merece um verbo explícito em vez de um booleano que o resolver precisa lembrar de
  checar. `.touch` é consultado **depois** de `.burn`, senão *"toca fogo no feno"* viraria um
  toque em vez de um incêndio.

Total: 22 casos em `Verb`, todos documentados no `@Guide`.

## Critérios de Aceite

Escritos como **falas do jogador**, porque essa é a categoria de critério que faltou nas 12 specs
anteriores: elas verificam estrutura (tipos, campos, arquivos) e o jogo quebra na entrada.

### Preâmbulo emocional não engole a ordem

- [x] `"calma, pega a faca"` → ela conforta **e** pega a faca; `state.has(.knife) == true`
- [x] `"Calma, eu to aqui com voce. Olha em volta e me diz o que tem ai."` → conforto **e**
      descrição do lugar; sanidade sobe (tom supportive)
- [x] `"respira. agora vai pela estrada"` → conforto **e** movimento; `currentBeat == .trifurcacao`
- [x] `"confia em mim, bate na porta de madeira"` → conforto **e** `state.has(.knockedWoodDoor)`
- [x] `"você consegue! abre a porta de aço"` → conforto **e** tentativa na porta de aço
- [x] `"pega a faca, calma"` (ordem invertida) continua funcionando como hoje

### Negação é entendida

- [x] `"não tenha medo, eu tô aqui"` com pendência aberta → conforto, **pendência preservada**,
      tom `supportive`
- [x] `"eu não vou te deixar sozinha"` → conforto; **não** é lido como recusa
- [x] `"não desisto de você"` → tom `supportive`, sanidade **sobe**; `distressStrikes` não muda
- [x] `"você não vai morrer, eu prometo"` → tom `supportive`
- [x] `"eu não vou embora"` → tom `supportive`
- [x] `"não entra na água"` no salão → ela **não** entra e **não** encosta na água; sanidade
      inalterada
- [x] `"não abre essa porta"` sem pendência → ela reconhece a proibição em ficção (não
      *"eu não perguntei nada"*)
- [x] `"não"` sozinho, com pendência aberta → continua recusando (não regride)
- [x] `"melhor não"` / `"nem pensar"` → continuam recusando

### A frase da screenshot `04-agua`

- [x] `"Procura uma saida. Vai pela estrada de pedra, nao entra na agua."` → ela procura e vai
      pela estrada; **não** encosta na água; `currentBeat == .trifurcacao`; sanidade inalterada

### Aberturas e reconhecimentos

- [x] `"oi"`, `"olá"`, `"oi?"` → resposta em personagem, nunca *"eu não entendi"*
- [x] `"ok"`, `"tá bom"`, `"beleza"`, `"entendi"` → reconhecimento curto, sem virar `.unknown`
- [x] `"o que você tá vendo?"` → descreve o lugar (é ensinado em `docs/suporte.html`)
- [x] `"me ajuda"`, `"o que eu faço?"` → resposta em personagem

### Default seguro

- [x] `"procura alguma coisa útil"` → ela procura; **não** encosta em nada nem perde sanidade
- [x] Um alvo que não existe no beat → ela pergunta o que fazer; sanidade inalterada
- [x] `"toca na água"` (verbo de toque explícito + feature nomeada) → continua tocando e
      continua custando −2. O toque não foi removido, só deixou de ser o default

### Não regride

- [x] `"pega a faca e vai pela água"` continua sendo dois atos
- [x] `"bate antes"`, `"olha em volta"`, `"entra no corredor"` continuam funcionando
- [x] `"sim"` / `"pode ir"` continuam confirmando pendências
- [x] As 5 mortes, a loucura e as 3 variantes de fuga continuam alcançáveis
- [x] `InterpretedAction.verb` documenta os 20 casos de `Verb`, incluindo `yes` e `no`
- [x] Build limpo em Release, 0 warnings, sem nova dependência

## Comportamento Esperado

### Fluxo principal

1. A mensagem é quebrada em cláusulas por `,` `.` `!` `?` `;` e pelas conjunções atuais.
2. Cada cláusula é classificada: **ação**, **proibição** (negação + cue), ou **não reconhecida**.
3. O tom é lido da **mensagem inteira**, uma vez só, com fronteira de palavra e com negação
   considerada. Continua sendo cobrado uma vez por mensagem, nunca por cláusula.
4. As cláusulas de ação executam em ordem, até no máximo `TurnRunner.maxClauses`.
5. Proibições não executam nada; com pendência aberta, recusam.
6. Cláusulas não reconhecidas são ignoradas se alguma outra casou.
7. A sequência para assim que ela abre uma pergunta ou o jogo termina — regra atual, mantida.

### Exemplo

```
jogador: calma, eu tô aqui. olha em volta e me diz o que tem aí.
         └── conforto ──┘  └────────── ação: look ──────────┘

ela: tô aguentando. de verdade. ajuda saber que tem alguém do outro lado.
ela: é uma ruína gigante. pilares antigos, árvores crescendo torto pelas frestas...
```

## Casos de Borda

- **Só proibição, sem pendência** (`"não faz isso"`): ela responde reconhecendo, não age, e o
  turno não é desperdiçado com *"eu não perguntei nada"*.
- **Proibição de algo que ela não ia fazer** (`"não queima o feno"` no salão): reconhece sem
  inventar contexto.
- **Negação dupla** (`"não vou deixar de te ajudar"`): não precisa acertar; precisa **não** cair
  em `distressing`. Na dúvida, `neutral`.
- **Mensagem só de pontuação/emoji**: continua `.unknown`, com a fala atual.
- **Muitas cláusulas** (`"pega a faca, acende o lampião, vai pela estrada, bate na porta"`):
  `maxClauses` continua cortando em 3; o excedente é ignorado em silêncio.
- **Preâmbulo + ordem fatal** (`"calma, entra na água"`): o conforto aplica e a pergunta de
  confirmação abre. Preâmbulo **nunca** pode pular uma confirmação.
- **Tom em cláusula posterior**: continua neutralizado (`index > 0`), para uma frase composta não
  cobrar duas vezes.
- **Sem Apple Intelligence**: tudo acima é do `LocalActionParser` e vale igual. Este é o ponto —
  a maior parte dos aparelhos elegíveis a iOS 26 não tem Apple Intelligence.

## Design / Wireframe

Sem UI. Nenhuma view muda.

## Notas Técnicas

Arquivos afetados:

- `DeepDive/Domain/LocalActionParser.swift` — separadores, veto, negação, tom, `procura`
- `DeepDive/Domain/PlayerAction.swift` — novo caso `Verb.greet`
- `DeepDive/Domain/ActionResolver.swift` — `resolveUse` fail-safe, tratamento de proibição,
  `resolveGreet`
- `DeepDive/Domain/WorldMap.swift` — falas de saudação e de proibição
- `DeepDive/Domain/FoundationModelsActionParser.swift` — `@Guide` com os 20 verbos

**Verificação.** O projeto não tem test target e testes não são entregável (regra do projeto).
A verificação é o harness headless: copia os arquivos de `Domain/` (nenhum importa
`FoundationModels`, `SwiftUI` ou `SwiftData`), compila com
`xcrun --sdk macosx swiftc -swift-version 5` e roda cada critério acima como uma fala real,
imprimindo verbo, tom e estado resultante. Ele vive fora do `.xcodeproj` e não vira alvo de
build. Todos os números do "Levantamento inicial" saíram dele.

Cuidados:

- `firstVerb` compara **ranges do texto com padding**; ao mexer nele, manter a comparação
  homogênea — misturar range com padding e sem padding já quebrou o contrato
  "mais à esquerda vence, empate vai para o primeiro listado".
- Nenhuma nova dependência (regra de ouro).
- O motor continua `nonisolated`: App Intents rodam fora da UI e precisam tomar um turno.

## Dependências

Nenhuma spec pendente. Convive com a
[ADR-002](../adr/ADR-002-world-simulation-in-swift.md), que estabeleceu o parser de verbo+alvo
que esta spec conserta.

## Histórico de Revisões

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-08-04 | Claude Code | Criação inicial a partir da auditoria de ponta a ponta |
| 2026-08-04 | Richard | `draft` → `approved` |
| 2026-08-04 | Claude Code | Implementada. 45/45 verificações no harness, build Release 0 erros / 0 warnings. `.search` e `.touch` viraram verbos próprios (ver "Ajustes feitos durante a implementação") |
