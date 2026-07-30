# Escopo do Jogo — Refactor (versão reduzida e final)

> Este documento é a fonte da verdade do conteúdo narrativo do jogo.
> Leia também `ARCHITECTURE.md` (stack técnica: Foundation Models, App
> Intents/Shortcuts, gerenciamento de contexto, princípio de "LLM não decide
> o estado").
>
> **Regra para esta tarefa: não expanda o escopo.** Não adicione cenas,
> itens, finais ou personagens além dos listados aqui. O projeto está sendo
> reduzido de propósito — o objetivo é entregar isto funcionando de forma
> sólida, não crescer o jogo.

## Objetivo da refatoração
O projeto atual está bugado. Refatore a implementação existente para
conformar exatamente com o escopo abaixo, removendo qualquer cena, item,
mecânica ou final que não esteja listado aqui.

## Premissa
Terror psicológico. O jogador conversa por chat com a protagonista (a
mulher) e a guia por um lugar chamado **Ratanabá**. Existe **1 único final
bom** (Fuga). Todos os outros finais são consequência de escolhas erradas.
**Nyarlathotep** é a entidade que pode aparecer/pegar a personagem em
determinadas cenas — use-o como referência de tom (irracionalidade, loucura
instantânea ao avistá-lo), não cite a obra de Lovecraft diretamente no
texto do jogo.

## Regra fundamental de interação
- Jogador instrui **movimento** (ex: "vá pela trilha da água") → cena muda
- Jogador instrui **ação** (ex: "pegue a faca") → personagem realiza a ação
  e permanece na cena atual
- Antes de qualquer ação ou transição potencialmente arriscada, a
  personagem **sempre pergunta se deve mesmo seguir** (confirmação
  explícita do jogador antes de agir)
- As mensagens da personagem nem sempre são 1-para-1 com as do jogador —
  ela pode mandar 2 ou 3 mensagens em sequência quando fizer sentido pro
  contexto (ex: reagir + descrever + perguntar)

## Cenas
| Cena | Descrição |
|---|---|
| **Salão principal** | Ruína irracional: construções de pedra antigas, algumas de cabeça para baixo no teto, pilares, árvores, goteiras, umidade. Dois caminhos: trilha na água, ou estrada de paralelepípedos até a trifurcação. Cena neutra — sem perigo de criaturas ou à sanidade. |
| **Trilha na água** | Ambiente úmido, tipo gruta. Água calma, vai ficando funda até a barriga conforme avança. |
| **Trifurcação** | 3 caminhos: esquerda = corredor escuro sem fim visível; centro = porta grande de metal, trancada; direita = porta de madeira, fechada mas sem trava. Cena neutra. |
| **Corredor** | Longo, parece túnel de catacumba velha. Nunca dá pra ver o fim, mesmo com luz. |
| **Além da porta de metal** | Caverna com menos umidade que o Salão. No fim, luz que leva à floresta amazônica (exterior). |
| **Além da porta de madeira** | Sala apertada e claustrofóbica, cheia de feno. Só dá pra entrar, olhar ao redor — o feno bloqueia a visão além disso. |

## Regra de retorno de cena
- É possível voltar **de qualquer cena atual** para o **Salão principal**
  ou a **Trifurcação** (as duas cenas neutras), a qualquer momento que o
  jogador disser "voltar" — inclusive imediatamente antes de uma cena de
  morte inevitável, como forma de escapar dela
- Antes de avançar para um caminho perigoso, a personagem sempre confirma
  primeiro — isso dá ao jogador a chance de mandar "voltar" a tempo

## Personagem e entidade
- Protagonista: a mulher (sem nome definido — mantenha assim, não invente
  nome a menos que instruído)
- Nyarlathotep: entidade do jogo, aparece em cenas de morte específicas.
  Descreva pela irracionalidade e pelo efeito de loucura instantânea ao
  ser avistado — não use citação direta de nenhuma obra

## Itens
| Item | Onde encontrar | Uso |
|---|---|---|
| **Faca simples** | Chão do Salão principal, a caminho da trifurcação | Corta o feno para pegar a chave com segurança (a faca é perdida no feno ao fazer isso); pode tentar lockpick na porta de aço (quebra a faca ao usar) |
| **Lampião** | Com a personagem, ao acordar — já aceso | Ilumina ambientes escuros; consome combustível por cena enquanto aceso; estado aceso/apagado |
| **Chave da porta de aço** | Dentro da sala da porta de madeira, em meio ao feno, visível brilhando | Abre a porta de aço na trifurcação, rota da fuga |

## Mecânicas
- **Lampião**: estados `aceso`/`apagado`. Consome combustível a cada cena
  se aceso. Combustível inicial: **suficiente para ~5–6 cenas com o
  lampião aceso** (valor ajustável — trate como constante nomeada e
  testável, não número espalhado pelo código). A personagem sempre
  pergunta se deve seguir com o lampião aceso ou apagado antes de cenas
  como a trilha da água, o corredor, ou a sala da porta de madeira.
- **Pegar a chave**: com as mãos nuas → arranhão de algo escondido no
  feno, sanidade cai drasticamente. Com a faca → sem penalidade, mas a
  faca é perdida no feno.
- **Sanidade**: valor numérico (defina escala, ex: 0–100).
  - Mensagens do jogador **de apoio/positivas** → sanidade sobe levemente
  - Mensagens **negativas/sombrias** → sanidade cai
  - Implementação: NÃO peça ao modelo para estimar um delta livre.
    Use geração guiada (`@Generable`) com um enum fechado de tom
    (ex: `supportive | neutral | distressing`), e mapeie cada categoria
    para um delta fixo definido em Swift. O LLM só classifica; o número
    é determinístico.
  - Sem proteção anti-farm por enquanto (aceitável nesta fase — não
    otimizar isso agora)
- **Confirmação de ação arriscada**: obrigatória antes de qualquer ação
  ou transição perigosa (seguir por caminho fatal, pegar a chave com as
  mãos, tentar lockpick, apagar/acender o lampião antes de área escura,
  etc.)

## Finais

### Fuga (único final bom)
Personagem passa da porta de aço, vê a caverna e a luz no fim do túnel.
- Sanidade > 80 → foge ilesa
- 40 ≤ Sanidade ≤ 80 → foge, mas transtornada
- Sanidade < 40 → recusa ir embora, decide "explorar mais" — jogo encerra

**Rota alternativa**: se a personagem atravessar o corredor da
trifurcação com o lampião **apagado**, ela consegue sair do outro lado
(perto da porta de aço) após um tempo, e segue para a saída — mesma
lógica de sanidade acima.

### Morte (4 variantes — texto já roteirizado, não gerar do zero)
> Para todas as mortes abaixo: escreva a cena completa como conteúdo fixo
> (roteiro pré-autorado). O LLM deve narrar dentro desse roteiro e variar
> apenas frases de transição/reação da personagem — não decidir o
> desfecho nem inventar a cena. Isso evita bloqueio de guardrail de
> segurança do Foundation Models e garante o timing certo do clímax.

1. **Morte na água**: ao avançar pela trilha, algo se mexe de forma
   irracional na água; a criatura ataca. Jogo encerra.
2. **Morte no corredor**: se entrar com o lampião **aceso**, o corredor
   se torna infinito sem a personagem perceber. Som sinistro vem da
   frente, ela tenta voltar mas o corredor não termina, o som vem dos
   dois lados, ela trava, se joga no chão, pede socorro — depois,
   silêncio. Jogo encerra.
3. **Morte na sala do feno (criatura)**: se a personagem **não bater na
   porta antes de entrar**, há uma criatura escondida no feno. Ao se
   aproximar para pegar a chave, é puxada para dentro. Jogo encerra.
4. **Morte na sala do feno (fogo)**: se a personagem **bateu na porta
   antes de entrar** (criatura já foi embora, entrada seguindo em
   segurança), mas ela decide atear fogo no feno com o lampião para
   tentar abrir passagem: a porta se fecha e tranca sozinha, a chama
   cresce, a fumaça intoxica o ambiente, ela se asfixia. Jogo encerra.

### Loucura (final bônus)
Conforme a sanidade cai com eventos sinistros, a personagem começa a
falar coisas sem sentido. Ao chegar a 0: ela diz que não quer mais sair,
que ali é bom, que quer ficar para sempre — e passa a falar em uma
"língua" sem sentido, com símbolos estranhos. Jogo encerra. (Mesmo
tratamento de roteiro fixo das mortes se aplica aqui.)

## Telas de final
Cada final tem tela exclusiva com uma frase curta:
- **Fuga**: frase original, inspirada no tom de lendas sobre Ratanabá —
  **não usar citação real de nenhuma fonte**, escrever frase nova
- **Loucura**: frase original, inspirada no tom do "Rei de Amarelo" —
  mesma regra, sem citação real
- **Morte**: sortear entre até 5 frases originais, inspiradas no tom de
  Lovecraft, escritas por você — sem citação direta de nenhuma obra

> Fique à vontade para gerar essas frases; serão refinadas depois.

## UI
- Botão de 3 pontos (canto superior direito): opções "Reiniciar" (nova
  run) e "Menu" (volta ao menu do jogo)

## Áudio
- Menu: música ambiente instrumental sem copyright, tema melancólico e
  sombrio, sem vocal, volume moderado
- Mesma música toca ao atingir qualquer final, junto da tela de frase

## Fora de escopo (não implementar)
- Qualquer cena, item, final ou personagem não listado acima
- Sistema de farm de sanidade (deixar como está por enquanto)
- Nomear a protagonista
