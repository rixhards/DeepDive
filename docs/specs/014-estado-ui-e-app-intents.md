# Spec 014 — Um dono do estado: App Intents, teclado, morte e recomeço

## Status
`implemented` — com 5 critérios pendentes de verificação no aparelho (ver abaixo)

## Contexto

O `ChatViewModel` guarda `state`, `memory` e `messages` em memória e grava por cima do disco a
cada turno. Os App Intents fazem o oposto: `GameTurnService.run` carrega do disco, aplica o
turno e grava. **O lado do intent já está certo** — quem segura estado obsoleto é o app.

O resultado foi medido no simulador (iPhone 17 Pro / iOS 26.5), com os três intents rodando de
verdade pelo app Atalhos: depois de "Mandar mensagem pra ela" mover a personagem para a
trifurcação, bastou voltar ao app e enviar **uma** mensagem para o save regredir a `salao`, o
óleo voltar de 4 para 5 e as três mensagens escritas pelos intents desaparecerem.

Ou seja: a feature-manchete do produto — ela te procurar fora do app — funciona **até você abrir
o app**, e aí é como se nunca tivesse acontecido.

A mesma auditoria encontrou mais quatro defeitos de estado e de ciclo de vida que têm a mesma
raiz (alguém segurando informação que o disco já mudou, ou uma task em voo escrevendo depois da
hora), e um defeito de UI que faz o app parecer quebrado independente de tudo isso.

## Objetivo

Estabelecer **um único dono do estado por turno** — o disco — e remover os quatro pontos em que
o app perde, sobrescreve ou tranca informação: o teclado que fecha, a morte que não termina, o
recomeço que ressuscita a partida antiga, e a pergunta que atravessa o save sem ser repetida.

## Levantamento inicial

Tudo abaixo foi reproduzido, não inferido:

| Sintoma | Como se manifesta | Onde |
|---|---|---|
| **App destrói os turnos dos intents** | `beat trifurcacao → salao`, `óleo 4 → 5`, 3 mensagens somem | [`ChatViewModel.swift:170`](../../DeepDive/ViewModels/ChatViewModel.swift) — `state = mutated` seguido de `saveSession()` |
| **Mensagens dos intents invisíveis** | Voltar ao app mostra só o histórico do próprio app | `start()` tem `guard !hasStarted`, e nada recarrega no foreground |
| **Teclado fecha a cada turno** | O composer sai da hierarquia; `@FocusState` mora dentro dele | [`ChatView.swift:96`](../../DeepDive/Views/ChatView.swift) — `if !viewModel.isTyping { ComposerView(...) }` |
| **Morte não termina** | `silentTurns = 3`: quem para de digitar nunca vê a tela de final, e o save já foi apagado | `deliver(_:)`, ramo `outcome.silentTurns > 0` |
| **Recomeçar durante a digitação** | A task em voo volta do `await` e restaura o estado pré-restart | `state = mutated` e `saveSession()` rodam antes de qualquer `Task.isCancelled` |
| **Pendência atravessa o save** | Retoma dizendo "cheguei no fim da estrada", com `corridorLampLit` ainda armado; o próximo "sim" mata | `start()` chama `arrival()` e nunca `pending.reminder` |
| **Abertura não cria save** | Instalar → abrir → a abertura toca → sair. Menu só oferece "começar"; intents respondem *"ninguém respondeu"* | `saveSession()` só é chamado em `send()` |

Causa comum dos três primeiros e do quinto: **duas coisas acham que são donas do estado**, e a
que escreve por último ganha.

## Decisões

1. **O disco é a fonte da verdade de um turno.** `send()` passa a carregar a sessão, aplicar o
   turno e gravar — exatamente o fluxo que `GameTurnService.run` já usa. O `ChatViewModel` deixa
   de ser dono do estado e vira cache da UI. Isso elimina a categoria inteira do bug em vez de
   remendar o sintoma, e de quebra conserta o recomeço-durante-a-digitação, que é a mesma doença.
2. **`GameSession` ganha `revision: Int`**, incrementado a cada gravação. É como o app descobre,
   barato, que o disco andou sem ele.
3. **Recarregar no `scenePhase == .active`**, quando a revisão do disco estiver à frente.
4. **As mensagens que chegaram por fora são *entregues*, não emendadas.** Elas entram com
   indicador de digitação e o mesmo `typingDelay` das outras. Emendar em silêncio faria o
   histórico "pular"; entregar transforma a reconciliação na batida que a feature sempre quis
   dar — você sumiu, ela falou sozinha, e você só está vendo agora.
5. **O composer nunca sai da hierarquia.** Ele já recebe `isDisabled` e esse parâmetro nunca foi
   usado com `true`. Passa a ser desabilitado, não removido.
6. **A morte continua tendo silêncio, mas o silêncio acaba.** `silentTurns` sobrevive — as
   mensagens do jogador caindo no vazio *são* o final. Mas passa a existir também
   `endingGraceSeconds`: se o jogador não digitar nada, a tela de final aparece sozinha. O que
   vier primeiro encerra.
7. **Fuga e loucura continuam indo direto para a tela de final.** A assimetria com a morte é
   deliberada e passa a ser documentada em `Outcome.silentTurns`: só a morte tem silêncio porque
   só nela ela sumiu; nos outros dois a história terminou e a revelação é o pagamento.
8. **Retomar uma partida com pergunta aberta repete a pergunta.** Depois do `arrival()`, se
   `state.pending != nil`, ela reafirma com `pending.reminder` antes de aceitar qualquer resposta.
9. **A sessão é gravada assim que a abertura termina.** Uma linha, e resolve os intents mudos
   logo após a instalação e o menu sem "continuar".

**Fora de escopo:** balanceamento, o futuro do `Narrator`, e o `AppShortcutsProvider` falhando
no Simulador (precisa de confirmação no iPhone físico antes de virar trabalho).

## Critérios de Aceite

Escritos como **coisas que o jogador faz e vê**, seguindo o padrão da spec 013.

### O app e os intents param de se destruir

- [x] Jogar um turno no app → mandar o app pro background → rodar "Mandar mensagem pra ela" no
      Atalhos → voltar ao app: as mensagens do intent **aparecem**, chegando com indicador de
      digitação, e o beat é o que o intent deixou
- [x] Logo em seguida, enviar uma mensagem no app: o beat **continua** sendo o do intent (não
      regride), o óleo não volta, e nenhuma mensagem some
- [ ] Rodar um intent com o app **em primeiro plano** → enviar uma mensagem no app: o turno do
      intent não é perdido
- [ ] Rodar "Receber mensagem dela" → voltar ao app: a mensagem espontânea está no histórico
- [x] `revision` no disco só cresce; nunca é gravada uma revisão menor que a lida

### Instalar e abrir já conta como partida

- [x] Instalar, abrir, deixar a abertura tocar, sair sem digitar → "Ver como ela está" responde
      com o estado real, não *"ninguém respondeu"*
- [x] No mesmo cenário, o menu oferece **"continuar"**

### Teclado

- [x] Enviar uma mensagem: o teclado **não fecha** enquanto ela responde
- [ ] Durante uma cena de 4 mensagens seguidas (a abertura), o composer não pisca nem salta
- [x] Enquanto ela digita, o campo fica visível e **desabilitado**; o botão de enviar não aceita
      toque
- [ ] O texto já digitado não é perdido quando ela começa a responder

### A morte termina

- [x] Morrer e **não digitar nada** → a tela de final aparece sozinha
- [ ] Morrer e enviar 3 mensagens → a tela de final aparece na terceira (comportamento atual)
- [ ] Durante esse intervalo, as mensagens do jogador aparecem no chat **sem resposta**
- [ ] Fuga e loucura continuam indo direto para a tela de final, sem intervalo de silêncio

### Recomeçar é seguro

- [x] Enviar uma mensagem e, **enquanto ela digita**, tocar "..." → "recomeçar do início": a
      partida nova não é sobrescrita pela antiga ao final da entrega
- [x] Depois de recomeçar, o histórico contém só a abertura nova
- [ ] "voltar ao menu" durante a digitação também não deixa a task em voo gravar

### A pergunta sobrevive ao save

- [x] Ela pergunta "eu entro assim, com o lampião aceso?" → fechar o app → reabrir: ela
      **repete a pergunta** antes de aceitar qualquer resposta
- [x] Só depois disso um "sim" confirma

### Não regride

- [x] As 5 mortes, a loucura e as 3 variantes de fuga continuam alcançáveis
- [x] Um turno normal continua gravando (fechar e reabrir retoma no mesmo ponto)
- [x] Os 45 casos da spec 013 continuam passando
- [x] Build limpo em Release, 0 warnings, sem nova dependência

### Ainda não verificado no aparelho

Estes critérios continuam desmarcados de propósito — o mecanismo está implementado, mas eu não
os exercitei de ponta a ponta e não vou marcá-los sem prova:

- Intent disparado com o app **em primeiro plano** (o `adoptStoreIfAhead` em `send()` cobre,
  mas não dirigi o cenário)
- "Receber mensagem dela" com volta ao app
- Morte encerrada pela contagem de 3 mensagens (verifiquei o caminho do relógio, não o da contagem)
- Fuga e loucura indo direto à revelação pela UI (o motor está coberto pelo harness)
- Texto já digitado sobreviver ao início da resposta dela

## Comportamento Esperado

### Um turno, agora

```
send(texto)
  ├─ carrega a sessão do disco            (o intent pode ter mexido)
  ├─ aplica o turno                        (TurnRunner → ActionResolver)
  ├─ grava com revision + 1
  └─ entrega as falas na UI
```

### Voltar do background

```
scenePhase → .active
  ├─ lê a revisão do disco
  ├─ igual à de memória? nada a fazer
  └─ maior?  adota state/memory, e entrega as mensagens novas
             como se estivessem chegando agora
```

## Casos de Borda

- **Intent dispara no meio de uma entrega da UI.** A gravação do turno em curso é a última a
  acontecer; a próxima leitura pega o resultado. Nenhuma escrita cega.
- **Recarregar com entrega em voo.** `deliveryTask` é cancelado antes de adotar o disco, e a task
  cancelada não grava — é o mesmo guard do critério de recomeço.
- **Save de schema antigo.** `SessionRepository.load()` já descarta e devolve `nil`; um
  `GameSession` sem `revision` deve decodificar com `revision = 0`, não falhar.
- **Partida terminada no disco.** `load()` continua ignorando `isFinished`; voltar do background
  numa partida encerrada não ressuscita nada.
- **Foreground sem save nenhum** (o jogador apagou pelo menu em outro fluxo): mantém o que está
  em memória, não zera a tela.
- **Morte enquanto o app está em background.** O intervalo de graça só começa a contar quando a
  tela volta — ninguém "perde" o final por estar fora do app.

## Design / Wireframe

Sem tela nova. A única mudança visível é o composer permanecer no lugar, esmaecido, enquanto ela
digita — em vez de sumir e voltar.

## Notas Técnicas

Arquivos afetados:

- `DeepDive/ViewModels/ChatViewModel.swift` — turno carrega/aplica/grava, reload no foreground,
  entrega das mensagens externas, guardas de cancelamento, save após a abertura, graça da morte
- `DeepDive/Views/ChatView.swift` — composer sempre presente, `scenePhase`
- `DeepDive/Views/ComposerView.swift` — estado desabilitado visível (já tem `isDisabled`)
- `DeepDive/Data/GameSession.swift` — `revision: Int`
- `DeepDive/Data/SessionRepository.swift` — incrementa a revisão ao gravar
- `DeepDive/Domain/Outcome.swift` — documentar que `silentTurns` é exclusivo da morte

Cuidados:

- `SessionRepository` cria um `ModelContainer` novo por instância. Isso continua aceitável
  porque toda leitura vai ao disco e toda escrita é um upsert de um registro só — mas é a razão
  pela qual observação do SwiftData **não** é o mecanismo aqui; a revisão é.
- O motor continua `nonisolated`. Nada nesta spec pode prender o `TurnRunner` ao main actor,
  senão os App Intents param de conseguir tomar um turno.
- `revision` entra em `GameSession`, que é o blob JSON — não exige mudança de `schemaVersion`
  desde que decodifique com valor padrão.

**Verificação.** Sem test target (regra do projeto). As partes de estado puro entram no mesmo
harness headless da spec 013; o resto é verificado no simulador com os intents reais, do jeito
que a auditoria mediu — inclusive lendo o `default.store` com `sqlite3` para conferir `revision`,
beat e contagem de mensagens antes e depois.

## Dependências

[Spec 013](013-parser-negacao-e-preambulo.md) — implementada. Esta spec não altera o parser, mas
os 45 casos dela fazem parte da não-regressão.

## Histórico de Revisões

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-08-04 | Claude Code | Criação inicial a partir da auditoria de ponta a ponta e do teste dos App Intents no simulador |
| 2026-08-04 | Richard | `draft` → `approved` |
| 2026-08-04 | Claude Code | Implementada. Build Release 0 erros / 0 warnings, 45/45 da spec 013 sem regressão, e 16 critérios verificados no simulador com os intents reais. 5 critérios seguem desmarcados por falta de verificação |
