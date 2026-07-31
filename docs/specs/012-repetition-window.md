# Spec 012 — Janela de repetição da narradora

## Status
`approved`

## Contexto

A abertura do jogo às vezes sai com as mensagens dela se repetindo. O padrão observado no
simulador (iPhone 17 Pro Max, iOS 26.5, com Foundation Models ativo):

```
Msg 1  oi? tem alguém aí? por favor me responde. tô com medo. não sei o que fazer.
Msg 2  oi? tô com medo.
       eu não sei onde eu tô. eu acordei agora no chão... tô tão assustada.
Msg 3  oi? tem alguém aí? por favor me responde. tô com medo. não sei o que fazer.   ← Msg 1 inteira
       tá tudo úmido e escuro. eu tô com um lampião aceso na mão...
Msg 4  oi? tô com medo.                                                              ← Msg 2 inteira
       eu não sei onde eu tô. eu acordei agora no chão... tô tão assustada.
       me ajuda. por favor. o que eu faço?
```

A repetição é sempre de **duas mensagens atrás**, nunca da imediatamente anterior.

**Causa.** `FoundationModelsNarrator.narrate` chama
`stripRepeats(in:avoiding: request.previousReply)`, e `previousReply` é uma única `String`,
sobrescrita a cada mensagem entregue em `ChatViewModel.deliver`. O filtro só conhece a última
fala. Quando o modelo ecoa algo de duas mensagens atrás, não há nada com que comparar e o
texto passa inteiro.

A abertura é o pior caso porque entrega quatro mensagens em sequência dentro da mesma sessão
do modelo: muito contexto próximo para ele repetir, e uma janela de comparação de tamanho 1.

Ser intermitente é coerente com a causa — depende de o modelo decidir ecoar ou não.

> Descoberta relacionada: **o Foundation Models roda no Simulator** (logs mostram
> `com.apple.FoundationModels` ativo, sem fallback). O `CLAUDE.md` afirmava que só o device
> físico executava o modelo. Este bug só aparece com o modelo ligado — no fallback autoral,
> não existe.

### Segundo achado, durante a validação

Com a janela alargada, a repetição sumiu — e a abertura virou isto:

```
Msg 1  oi? tem alguém aí? por favor me responde
Msg 2  oi?
Msg 3  oi?
Msg 4  oi?
```

O modelo continuava ecoando a mensagem anterior inteira. O filtro agora removia todas as
sentenças longas corretamente, mas sobrava `"oi?"` — que passa de propósito, porque
fragmentos curtos são voz e não repetição.

A guarda de fallback existente testava só vazio:

```swift
guard !deduped.isEmpty else { return plain }
```

`"oi?"` não é vazio, então a guarda passava e ela enviava uma bolha contendo só isso. Testar
vazio é fraco demais: o que importa é se **sobrou algo com conteúdo**.

## Objetivo

Trocar a janela de comparação de uma fala para as últimas N falas, para que a narradora não
repita nada que tenha dito recentemente — não apenas o que disse por último. E fazer a guarda
de fallback exigir conteúdo real, não apenas texto não-vazio.

## Critérios de Aceite

- [x] `NarrationRequest` carrega as últimas falas (`recentReplies`), não uma única `previousReply`
- [x] `ChatViewModel` mantém essa janela com tamanho máximo fixo e a limpa em `restart()`
- [x] `stripRepeats` compara contra todas as falas da janela
- [x] A sobrecarga `stripRepeats(in:avoiding: String)` continua existindo — os testes atuais em `NarratorTests` usam essa assinatura e seguiram compilando sem edição
- [x] `DeepDiveIntents` passa a janela pelo mesmo caminho
- [x] A guarda de fallback exige conteúdo (`hasSubstance`), não apenas texto não-vazio
- [x] O projeto compila sem erro nem warning
- [x] Suíte completa passando: **81 testes, 0 falhas**
- [x] Aberturas do zero no simulador, com Foundation Models ativo, sem nenhuma repetição

### Como foi validado

**Testes determinísticos** (novos, em `NarratorTests`):

| Teste | O que prova |
|---|---|
| `testSentencesFromTwoRepliesBackAreDropped` | O eco de duas mensagens atrás agora é removido |
| `testSingleEntryWindowIsWhatLetTheEchoThrough` | Com janela 1, o mesmo eco sobrevive — a regressão fica visível, não só descrita |
| `testLeftoverInterjectionDoesNotCountAsSomethingToSay` | `"oi?"` sozinho não conta como conteúdo |
| `testARealSentenceCountsAsSubstance` / `testEmptyTextHasNoSubstance` | Limites da guarda |
| `testWindowKeepsSentencesItHasNeverSeen` / `testEmptyWindowChangesNothing` | Sem falso positivo |

**Ao vivo**, no iPhone 17 Pro Max / iOS 26.5 com o modelo ativo: **3 aberturas do zero**, todas
com as 4 mensagens distintas. Uma delas verificada por programa, lendo o payload do SwiftData
e comparando as sentenças de todas as mensagens da personagem entre si — 6 mensagens, 0
repetições. Antes do fix o bug aparecia com facilidade (2 de 4 tentativas).

Também confirmado ao vivo que os dois comportamentos que a mudança poderia quebrar continuam
de pé: a **pergunta pendente da água** foi feita normalmente antes da morte, e o **script de
morte** saiu literalmente como está no `WorldMap`.

> Nota: a abertura só é persistida depois do primeiro turno do jogador — `saveSession()` é
> chamado apenas dentro de `send(_:)`. Fechar o app logo após a abertura perde a sessão. Não
> foi alterado aqui; fica registrado.

## Comportamento Esperado

Ao montar cada mensagem, a narradora descarta sentenças que já apareceram em qualquer uma
das últimas **5** falas dela. Cinco cobre a abertura inteira (quatro mensagens) com folga.

O restante do comportamento não muda: fragmentos curtos (até 12 caracteres de chave) seguem
passando, porque são voz e não repetição.

## Casos de Borda

**A pergunta pendente precisa sobreviver.** Quando o jogador responde algo passivo, ela
repete a pergunta de propósito — comportamento documentado no `CLAUDE.md` e descoberto em
teste de device. Com a janela maior, essa repetição intencional passa a ser detectada e
removida.

Isso continua funcionando por causa da guarda já existente em
`FoundationModelsNarrator.narrate`:

```swift
guard !deduped.isEmpty else { return plain }
```

Se tudo for removido, a fala volta como o fato autoral cru — que é exatamente a pergunta
pendente. A guarda precisa continuar intacta; ela é o que protege esse caso.

**Mensagem parcialmente repetida:** a parte repetida sai, a parte nova fica. É o
comportamento desejado.

## Notas Técnicas

Mudança aditiva, conforme a regra do `CLAUDE.md` de manter os testes compilando: a versão
`String` de `stripRepeats` continua existindo e delega para a versão de array.

`NarrationRequest.recentReplies` entra com valor padrão `[]`, então o helper `request(facts:)`
de `NarratorTests` segue válido sem alteração.

Nenhuma mudança em `ActionResolver`, `GameState` ou `WorldMap` — o bug é de apresentação, não
de simulação.

## Dependências

Nenhuma.

## Histórico de Revisões

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-07-31 | Claude Code | Criação, a partir de bug encontrado na preparação da submissão (spec 011) |
