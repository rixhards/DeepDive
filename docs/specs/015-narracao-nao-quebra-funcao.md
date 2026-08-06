# Spec 015 — O narrador pode mudar como ela fala, nunca se a fala ainda funciona

## Status
`implemented` — 2 critérios sem oportunidade de verificação (ver abaixo)

## Contexto

Durante a verificação da spec 014, no simulador com Foundation Models ativo, o jogador digitou
**"entra no corredor"**. O motor fez exatamente o certo: abriu a pendência `corridorLampLit`,
que é uma confirmação de vida ou morte. O texto autoral dessa pergunta é:

> *"eu tô parada na entrada do corredor com o lampião aceso. e a luz não tá entrando — ela para
> na boca do corredor igual parede. eu entro assim mesmo, com ele aceso?"*

O que chegou na tela foi:

> **"pelo jeito, não. tá tudo tão escuro e úmido aqui, tô tão cansada e com medo."**

A pergunta desapareceu. E o que a substituiu é literalmente o texto que as próprias instruções
do narrador listam como exemplo do que **não** fazer — "tá tudo escuro e úmido" e "estou tão
cansada e com medo" estão citadas, nome por nome, na seção "PROIBIDO REPETIR" do prompt.

Aconteceu de novo no mesmo teste, na retomada de uma partida salva. O lembrete autoral
*"e eu continuo aqui na beira da água, esperando. eu entro ou não?"* virou
**"quero entrar. só não sei se vai ser seguro."** — que inverte o sentido: a fala autoral
pergunta ao jogador, a narrada afirma o desejo dela e some com a pergunta.

Isso é a falha mais grave que resta no jogo. O jogador está diante de uma escolha irreversível
e a escolha nunca chega até ele. Se ele responder "sim" ali, ela morre por uma pergunta que ele
não leu. A spec 014 acabou de garantir que essa pergunta sobreviva ao save — para o narrador
destruí-la na entrega.

O mesmo defeito tem uma segunda cara, já medida na auditoria: o `overview` do salão tem **339
caracteres** e é a única mensagem do jogo que informa as duas saídas existentes. Ele é entregue
a um prompt que manda comprimir para **320** e que proíbe redescrever o ambiente — ou seja, o
narrador é instruído a encurtar e a de-descrever justamente a mensagem cujo trabalho é descrever
e enumerar.

## Objetivo

Separar, no motor, o texto que **reage** do texto que **funciona**. O narrador continua dando
voz ao primeiro; o segundo chega ao jogador exatamente como foi escrito.

## Levantamento inicial

| O que o motor produziu | O que chegou na tela | Consequência |
|---|---|---|
| `PendingChoice.corridorLampLit.question` — 162 chars, termina em "?" | *"pelo jeito, não. tá tudo tão escuro e úmido aqui, tô tão cansada e com medo."* | **a confirmação de morte não é feita** |
| `PendingChoice.enterWater.reminder` — "eu entro ou não?" | *"quero entrar. só não sei se vai ser seguro."* | sentido invertido, pergunta perdida |
| `salao.overview` + item — 339 chars, lista as 2 saídas | (prompt manda ≤ 320 e proíbe descrever ambiente) | risco de o jogador perder o mapa |

Causas:

1. **`Outcome.raw` só marca clímax.** Mortes, loucura e fugas são entregues literalmente porque
   os guardrails do modelo podem recusá-las. Ninguém marcou as *perguntas* — que também não
   sobrevivem a reescrita, por outro motivo.
2. **Nenhuma checagem de que a narração ainda faz o que os fatos faziam.** Existem guardas para
   repetição (`stripRepeats`), para andaime de prompt (`clean`) e para vazio (`hasSubstance`) —
   nenhuma para "a resposta continua perguntando?".
3. **O prompt se contradiz.** "máximo 320 caracteres", "PREFIRA uma mensagem única e curta" e
   "NUNCA redescreva o ambiente" são corretos para uma reação e errados para um `look`.
4. **`raw` mistura duas coisas.** Hoje ele significa *entregar literal* **e** *entregar rápido*
   (`typingDelay` de 0,5–1,4 s, feito para uma morte). Uma descrição de sala entregue nesse ritmo
   fica errada.
5. **Um timeout envenena a sessão.** `withTimeout` usa `group.cancelAll()`, mas cancelamento é
   cooperativo: a geração órfã continua ocupando a `LanguageModelSession`, e as chamadas
   seguintes do mesmo beat falham em cascata.

## Decisões

1. **`Outcome.raw: Bool` vira `Outcome.delivery: Delivery`**, com três casos explícitos:
   - `.narrated` — o padrão. O narrador dá voz.
   - `.verbatim` — entregue como escrito, no ritmo normal de digitação.
   - `.script` — entregue como escrito, no ritmo acelerado dos clímaxes (o `raw` de hoje).

   Separar isso é necessário: `verbatim` e `script` querem literalidade, mas só `script` quer
   pressa.

2. **Vai verbatim tudo que pergunta ou enumera.** A regra, escrita para durar:
   *se reescrever pode fazer o texto parar de cumprir a função dele, ele não é reescrito.*
   - `PendingChoice.question` e `.reminder` — **perguntam**
   - `resolveLook` — **enumera as saídas**; é o mapa do jogador
   - `Beat.arrival` / `.revisit` / `arrivalBeats` — enumeram caminhos e são a única planta do lugar
   - `resolveInventory` — enumera o que ela carrega

3. **Continua narrado tudo que reage.** Detalhes de features, conforto, saudação, proibição,
   espera, grito, descanso, falas de item e de lampião, resultados de busca, `Conversation`.
   É onde a variação vale e onde uma reescrita ruim não quebra nada.

4. **Rede de segurança para o que continua narrado.** Se os fatos terminam em pergunta e a
   narração não tem nenhum "?", a narração é descartada e os fatos autorais vão para a tela.
   Mesma coisa se a narração encolher abaixo de um terço do tamanho dos fatos. É a mesma
   filosofia das guardas que já existem: na dúvida, o texto autoral ganha.

5. **Um timeout descarta a sessão.** Em vez de deixar a geração órfã segurando a
   `LanguageModelSession`, a sessão é jogada fora na hora e a próxima mensagem começa uma nova.
   Custa uma reidratação; evita o beat inteiro cair no texto cru.

6. **O prompt para de se contradizer.** As regras de brevidade e de "não redescreva o ambiente"
   permanecem, mas o narrador deixa de receber `look` e chegadas — que eram exatamente os casos
   em que essas regras eram a instrução errada.

**Fora de escopo:** aposentar o narrador. Esta spec não decide se ele deve existir — decide que,
enquanto existir, ele não pode quebrar a função do texto. A pergunta maior (vale a latência de
uma geração por mensagem para reescrever prosa que já está pronta?) fica para uma ADR.

## Critérios de Aceite

Verificados **no simulador com Foundation Models ativo**, porque o defeito não existe sem o
modelo — com o fallback autoral tudo sempre pareceu certo. Foi isso que escondeu o bug.

### A pergunta sempre chega

- [x] `"entra no corredor"` na trifurcação → a mensagem na tela **termina em "?"**, menciona o
      lampião aceso, e é o texto autoral palavra por palavra
- [x] `"vai pela água"` no salão → a mensagem pergunta se ela entra
- [x] `"entra na porta de madeira"` sem ter batido → a mensagem cita os arranhões e pergunta
- [x] `"pega a chave"` na sala do feno → a mensagem pergunta antes de enfiar a mão
- [x] Retomar uma partida salva com pendência aberta → o lembrete chega **com a pergunta**, não
      como uma afirmação do desejo dela
- [x] Nenhuma dessas mensagens contém "cansada", "com medo" ou "escuro e úmido" quando os fatos
      não contêm

### O mapa sempre chega

- [x] `"olha em volta"` no salão → a mensagem cita **a trilha da água e a estrada**
- [x] Chegar na trifurcação → a mensagem cita **os três caminhos**
- [x] `"o que você tem aí?"` carregando faca e lampião → a mensagem cita **os dois**

### A variação continua existindo

- [x] `"calma, você consegue"` → a resposta é reescrita pelo modelo, não uma frase fixa
- [x] `"olha pro teto"` → o detalhe da feature continua narrado
- [x] Mortes, loucura e fugas continuam literais **e rápidas** (ritmo de `script`)

### As redes de segurança

- [ ] Se o modelo devolver uma narração sem "?" para fatos que perguntam, o jogador vê o texto
      autoral
- [ ] Se o modelo devolver algo muito mais curto que os fatos, o jogador vê o texto autoral
- [ ] Depois de um timeout de geração, a **próxima** mensagem do mesmo beat volta a ser narrada
      (a sessão foi renovada, não envenenada)

### Não regride

- [x] Os 45 casos da spec 013 continuam passando
- [x] Os critérios verificados da spec 014 continuam válidos
- [x] App Intents continuam entregando o mesmo texto que o app
- [x] Build limpo em Release, 0 warnings, sem nova dependência

### Ainda não verificado

- [ ] As duas redes de segurança (narração sem "?" e narração encolhida) disparando de fato.
      O modelo não produziu nenhuma das duas nesta rodada — as perguntas agora nem chegam nele.
      A lógica é pura de string e está coberta pelo harness; o disparo real, não.
- [ ] Recuperação depois de um timeout de geração. Nenhum timeout ocorreu nos testes.

## Comportamento Esperado

```
Outcome
  ├─ .script   → literal, ritmo acelerado   (morte, loucura, fuga)
  ├─ .verbatim → literal, ritmo normal      (perguntas, look, chegadas, inventário)
  └─ .narrated → modelo dá voz               (reações)
                    └─ e se a narração perder a pergunta
                       ou encolher demais → cai para os fatos autorais
```

## Casos de Borda

- **Fatos com "?" no meio e não no fim** ("qual porta? a de aço ou a de madeira?") — a checagem
  procura o caractere em qualquer posição, não só no fim.
- **Aparelho sem Apple Intelligence.** Tudo já cai nos fatos autorais; esta spec não muda nada
  lá — e é por isso que o defeito passou tanto tempo invisível.
- **Fatos curtos e legítimos** ("isso já tá comigo.") — o piso de tamanho é proporcional aos
  fatos, não absoluto, senão toda resposta curta seria rejeitada.
- **Beats de uma cena `verbatim`.** `arrivalBeats` herda a política do `Outcome`, como os beats
  de `script` já herdam hoje.
- **App Intents.** `GameTurnService` usa a mesma política; nada de dois caminhos de entrega.

## Design / Wireframe

Sem UI nova. A mudança visível é que perguntas e descrições de lugar passam a chegar como foram
escritas.

## Notas Técnicas

Arquivos afetados:

- `DeepDive/Domain/Outcome.swift` — `raw: Bool` → `delivery: Delivery`
- `DeepDive/Domain/ActionResolver.swift` — marcar perguntas, `look`, chegadas e inventário
- `DeepDive/Domain/FoundationModelsNarrator.swift` — guarda de pergunta e de tamanho; timeout
  descarta a sessão
- `DeepDive/ViewModels/ChatViewModel.swift` — `typingDelay` passa a olhar a política
- `DeepDive/Intents/DeepDiveIntents.swift` — mesma política

Cuidados:

- `Outcome.raw` é lido em quatro lugares; trocar por um enum é mecânico, mas o **ritmo** de
  entrega precisa seguir `script`, não `verbatim`, ou as mortes perdem a pressa que as faz
  funcionar.
- A guarda de pergunta compara **fatos → narração**, nunca o contrário: uma narração que
  *acrescenta* uma pergunta não é rejeitada por isso (só pelas guardas que já existem).
- O motor continua `nonisolated`.

**Verificação.** As partes determinísticas (qual `Outcome` recebe qual política) entram no
harness headless. As guardas de narração são lógica pura de string e também. O resto — o texto
que de fato aparece com o modelo ativo — é verificado no simulador, lendo o `default.store` com
`sqlite3` para comparar o que foi entregue com o texto autoral.

### Observado durante a verificação (fora do escopo desta spec)

Com uma pergunta aberta, `TurnRunner` para de processar cláusulas assim que vê `state.pending`
— então em *"calma, olha em volta"* o conforto sai e o `olha em volta` é engolido. Não é
regressão da 015 nem da 013: a condição de parada sempre foi `state.pending != nil`, que não
distingue "esta cláusula abriu uma pergunta" de "já havia uma pergunta aberta". É defensável
(ela está travada na decisão) e é também exatamente a classe de defeito que a spec 013 atacou:
uma instrução do jogador some sem aviso. Fica anotado para decisão futura.

## Dependências

[Spec 013](013-parser-negacao-e-preambulo.md) e [Spec 014](014-estado-ui-e-app-intents.md), ambas
implementadas. A 014 é o motivo de esta existir: ela garantiu que a pergunta chegue viva até a
entrega, e a entrega é onde ela morria.

## Histórico de Revisões

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-08-04 | Claude Code | Criação inicial, a partir de duas falhas observadas ao vivo na verificação da spec 014 |
| 2026-08-04 | Richard | `draft` → `approved` |
| 2026-08-04 | Claude Code | Implementada. Build Release 0/0; 45/45 da spec 013 e 15/15 da política de entrega no harness; a falha original reproduzida e corrigida no simulador com Foundation Models ativo |
