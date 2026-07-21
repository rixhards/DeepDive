guia-desenvolvimento-assistido-por-ia.md 15/07/26, 4:53 PM
Guia para desenvolvimento assistido por IA
Versão revisada — escrita corrigida e informações verificadas em relação à
documentação oficial da Anthropic (docs.claude.com) e a fontes públicas sobre outras
ferramentas mencionadas.
LLM (Large Language Model)
É um modelo treinado para prever texto, capaz de entender linguagem natural e gerar
código e explicações. É o "cérebro" de tudo, adaptando as respostas conforme o contexto
que o usuário fornece.
Context Window (Janela de Contexto)
É a quantidade máxima de tokens que um LLM consegue considerar de uma vez — é
isso que informa "onde, o que e como" o modelo procura e raciocina.
Correção: a regra prática usada pela própria Anthropic é o inverso do que estava
escrito. Não é "um quarto de uma palavra equivale a um token" — é
aproximadamente 1 token ≈ 4 caracteres, o que dá algo em torno de 0,75 palavra
por token (em inglês; em português, por causa da acentuação e de palavras mais
longas, tende a gastar um pouco mais de tokens por palavra).
Quando a janela se enche, as informações mais antigas vão sendo descartadas (processo
chamado de compactação), o que pode gerar alucinações ou perda de instruções. O
histórico de conversa e a "memória" da IA também ocupam espaço nessa janela.
Existem estratégias e ferramentas para otimizar o uso de tokens (ex.: subagents, skills,
compactação).
Resposta à pergunta "sobre as janelas de contexto serem abertas em
separado": sim — cada sessão do Claude Code tem sua própria janela de contexto
independente, e um subagent invocado dentro de uma sessão abre sua própria
janela de contexto limpa, separada da conversa principal, devolvendo só um
resumo ao final. Isso é justamente uma das formas de "economizar" contexto. Vale
confirmar com o Igor se ele quis dizer algo mais específico.
Chat
É o meio mais simples de comunicação com uma LLM: você manda mensagens e ela
devolve respostas. Na sua forma mais básica (um LLM "cru", sem nenhuma camada
adicional), ele não tem acesso a ferramentas nem memória entre conversas — é puro
texto entrando e saindo.
Nuance: essa definição descreve o LLM "nu". Produtos de chat como o Claude.ai
já adicionam camadas por cima disso (busca na web, memória entre conversas,
criação de arquivos etc.), então na prática a linha entre "chat" e "agent" fica mais
https://claude.ai/chat/7e84508a-94fb-42b2-b4e0-de876ece1fd5 Page 1 of 7

guia-desenvolvimento-assistido-por-ia.md 15/07/26, 4:53 PM
tênue — o que diferencia os dois é a presença ou não de ferramentas e autonomia
para agir, não o fato de ser uma interface de chat em si.
Agent
É o comportamento de observar um estado, tomar uma decisão, agir conforme essa
decisão e analisar o resultado daquilo que foi feito — o chamado loop agentic (gather
context → take action → verify results → repeat). É algo autônomo que vive nesse loop até
atingir o objetivo pedido, mesmo que para isso precise iterar várias vezes ou até os
tokens acabarem. É um comportamento, não uma ferramenta.
Esse comportamento costuma ser guiado por arquivos Markdown (CLAUDE.md, skills,
subagents etc.), pois eles dão um contexto específico de como agir, ajudando a evitar
alucinações.
Harness
É a infraestrutura que permite que o Agent faça o que precisa fazer — é o harness que dá
à LLM acesso a terminal, código, ferramentas etc.
Analogia do avião: o piloto sabe pilotar, mas sem um avião ele não tem o que fazer. O
harness é o avião.
Exemplos: Claude Code é o harness que a Anthropic mantém para suas próprias LLMs;
Google Antigravity é um exemplo de harness mais "genérico" — ele é multi-modelo e,
além do Gemini 3 (modelo padrão do Google), também suporta modelos de outras
empresas, incluindo modelos da Anthropic (Claude).
MCP (Model Context Protocol)
É a forma padronizada de o harness conversar com ferramentas e fontes externas. A
arquitetura é dividida em Host, Client e Server. Por exemplo, o Xcode pode avisar o
harness o que ele consegue usar e como.
É possível conectar um MCP ao Figma para ter acesso aos recursos dele. Todo harness
ou ferramenta pode expor seu próprio MCP para conversar com outras fontes — mas
isso consome muitos tokens (cada ferramenta conectada ocupa espaço na janela de
contexto), então vale manter ativos apenas os MCPs de interesse no momento.
(Nota pessoal preservada: na sua experiência, não vale muito a pena usar o MCP do
Xcode — compensa mais usar o xcodebuild , a ferramenta de linha de comando do
Xcode, que é mais leve.)
RAG (Retrieval-Augmented Generation)
É uma técnica que combina busca de informação com geração de texto: em vez de
depender só do que o modelo "sabe" (treinamento), ele busca em tempo real
informações específicas — por exemplo, de uma empresa — e injeta esse conteúdo na
janela de contexto antes de responder. Isso ajuda o modelo a responder sobre algo para o
https://claude.ai/chat/7e84508a-94fb-42b2-b4e0-de876ece1fd5 Page 2 of 7

guia-desenvolvimento-assistido-por-ia.md 15/07/26, 4:53 PM
qual ele não foi treinado, ou que mudou depois do treinamento, ancorando a resposta em
evidências reais.
Skills
É um pacote de conhecimento especializado que o Agent deve seguir — basicamente,
um passo a passo de como algo deve ser executado. Skills são feitas para serem
reutilizáveis.
Como escrever uma boa Skill: tudo é escrito em Markdown, e existem templates que
ajudam a IA a entender melhor o contexto. Se a skill tiver uma boa descrição, ela
funciona como um trigger: durante o trabalho, o LLM percebe que aquele arquivo é
relevante e a carrega sozinho (por isso a Anthropic tem uma skill própria — o skill-
creator — para ajudar a criar novas skills a partir de um template).
Além do "como", uma skill também pode dizer "quando" as coisas devem acontecer. É
importante separar os detalhes: uma skill é uma pasta que contém um arquivo
SKILL.md com o passo a passo e a descrição necessária; conteúdo mais específico pode
ficar em subpastas (ex.: scripts/ , references/ , assets/ ), sem lotar o contexto do
SKILL.md principal. A estrutura típica é:
skill-name/
├── SKILL.md
├── scripts/
├── references/
└── assets/
É possível ter várias skills, desde que cada uma fique em seu próprio diretório skill-
name/ .
Iteração e testagem são importantes: à medida que você usa a skill, vai ajustando e
melhorando ela. Quando o agente comete o mesmo erro repetidamente, uma skill pode
ser criada para instruí-lo sobre como agir naquela situação. (Dica extra: é recomendado
escrever o arquivo em inglês, já que os modelos costumam responder melhor com
instruções nesse idioma.)
Progressive Disclosure
É o mecanismo pelo qual a LLM só "enxerga" o nome e a descrição de uma skill de início
— o conteúdo completo só é carregado quando ela realmente precisa ser usada. Isso
existe justamente para que a janela de contexto não fique poluída com informação que
talvez nem seja usada. Pode ser forçado explicitamente no prompt (ex.: "use tal skill").
Plugin
Empacota várias coisas juntas — skills, hooks, subagents e servidores MCP — e facilita
baixar tudo isso de uma fonte externa de uma vez. Um exemplo real e bem conhecido na
comunidade é o Superpowers, um plugin que empacota um conjunto de skills genéricas
https://claude.ai/chat/7e84508a-94fb-42b2-b4e0-de876ece1fd5 Page 3 of 7

guia-desenvolvimento-assistido-por-ia.md 15/07/26, 4:53 PM
comunidade é o Superpowers, um plugin que empacota um conjunto de skills genéricas
voltadas a uma metodologia de desenvolvimento (brainstorm, spec, TDD, debugging
estruturado etc.) e que pode auxiliar bastante no dia a dia.
Uso típico: /plugin install superpowers@claude-plugins-official . Isso serve, em
resumo, para instalar coisas prontas no seu harness sem precisar configurar cada peça
manualmente.
Hooks
São gatilhos automáticos: um handler definido por você que executa em um ponto
específico do ciclo de vida do agente — por exemplo, antes de uma ferramenta rodar,
depois de uma edição de arquivo, ou no início da sessão. A diferença importante em
relação a uma skill é que o hook é determinístico: ele dispara sempre naquele ponto do
fluxo, e não depende do modelo "decidir" usá-lo.
Subagent
Quando você está conversando com o harness, normalmente é você quem decide
quando e como as coisas acontecem. Esse trabalho pode ser delegado a um subagent:
um assistente especializado que roda na sua própria janela de contexto, limpa e isolada
da conversa principal, com permissões e ferramentas próprias. Ele trabalha na tarefa
delegada e devolve só um resumo para o harness ao final — o que economiza (e muito) o
contexto da conversa principal. Serve para orquestrar agentes específicos usando skills
específicas, ou para paralelizar pesquisas/tarefas.
Workflows
Diferente de uma skill — feita para atender uma tarefa específica — um workflow
engloba várias tarefas/skills em sequência. É possível deixar o workflow implícito,
deixando o agente decidir a ordem por conta própria, ou explícito, onde ele confirma
com você antes de cada próximo passo.
Esclarecimento: vale separar dois conceitos que estavam meio misturados no
texto original:
https://claude.ai/chat/7e84508a-94fb-42b2-b4e0-de876ece1fd5 Page 4 of 7

guia-desenvolvimento-assistido-por-ia.md 15/07/26, 4:53 PM
Workflow, como conceito de engenharia de software, é o fluxo geral de
trabalho — e é isso que o parágrafo original descreve.
No Claude Code especificamente, existe também uma feature chamada
Workflows, focada em automatizar tarefas repetitivas em muitos arquivos (ex.:
"corrija esse mesmo problema em 50 arquivos"), que pode ser reaproveitada
depois.
Já o CLAUDE.md não é exatamente um "orquestrador" de workflow — ele é
um arquivo de instruções persistentes (contexto do projeto: convenções,
arquitetura, comandos de build etc.) que é lido no início de toda sessão, antes
de qualquer prompt. Por isso ele "parece" o ponto de partida de tudo, mas seu
papel é dar contexto, não decidir a ordem de execução das tarefas.
Correção de número: a recomendação oficial não é de no máximo 80 linhas —
é de manter o CLAUDE.md abaixo de ~200 linhas. Quanto mais longo, mais
contexto ele consome em toda sessão e menor tende a ser a aderência do
modelo às instruções. Se as instruções crescerem demais, o recomendado é
dividir em regras ( .claude/rules/ ) que só carregam quando relevantes.
O Superpowers tem uma skill própria para lidar com esse tipo de fluxo estruturado, caso
ajude de exemplo.
Specs
Descreve exatamente qual output se quer — o equivalente a uma User Story, onde se
define o interesse e os critérios de aceite. Numa spec, você pode descrever o nome da
feature, a entrega esperada, o que não é o foco, e os critérios de aceite que validam a
conclusão da feature. Na dúvida, pense: "se eu fosse montar uma US, como ela seria?" —
o resultado é a spec. Em outras palavras, cada feature do projeto pode virar uma spec.
É possível até criar um agente dedicado a escrever specs alinhadas ao contexto e escopo
do seu projeto. Em algumas empresas, specs viram as próprias tasks, e o arquivo da spec
fica dentro do repositório (o nome/convenção varia por empresa).
A spec precisa ser sinalizada explicitamente para ser implementada, pois ela não entra
no Progressive Disclosure do agente automaticamente. É quase o mesmo que escrever
um prompt direto, mas numa spec você tende a ser bem mais específico — o que evita
perder tempo reescrevendo o prompt toda vez, e ainda serve como documentação. Uma
organização de pastas comum é ter um diretório docs/ com um specs/ dentro.
É possível montar uma spec "grande" que funcione como uma User Story e, a partir dela,
quebrar em specs menores que funcionam como tasks. É recomendado subir as specs
para o repositório, para que sirvam de documentação viva. Existem dois cenários típicos:
(1) depois de um brainstorm com o agente sobre como as coisas vão funcionar, vocês
montam a spec juntos; ou (2) a spec já existe e você diz ao agente para usá-la como input.
Sobre SDD (Spec-Driven Development): é justamente o nome dado a essa
metodologia — desenvolver a partir de especificações escritas antes do código, em
https://claude.ai/chat/7e84508a-94fb-42b2-b4e0-de876ece1fd5 Page 5 of 7

guia-desenvolvimento-assistido-por-ia.md 15/07/26, 4:53 PM
metodologia — desenvolver a partir de especificações escritas antes do código, em
vez de ir direto para a implementação. É um termo cada vez mais usado no
ecossistema de desenvolvimento assistido por IA (existem inclusive ferramentas
open-source dedicadas a isso).
Prompt Engineering
Prompt ruim = prompt muito aberto/vago.
Prompt bom = prompt onde você define bem o que precisa ser feito.
Prompt excelente = você diz "faça isso" e, como todo o contexto (CLAUDE.md,
skills, specs) já está configurado de antemão, as coisas simplesmente acontecem.
Camadas do Prompt Engineering:
Prompt → uso imediato, pontual.
Spec → regras para uma única feature.
Skill → regras reutilizáveis entre features/tarefas.
Vibe Coding
É quando o desenvolvedor simplesmente usa um LLM para desenvolver as coisas,
deixando o Agent decidir como e quando fazer, sem revisar o código de perto — "é aqui
que o app morre" (numa piada sobre o risco de shippar algo sem entender ou validar o
que foi gerado). O termo, no uso mais comum do mercado, descreve justamente esse
estilo de "confiar no output" e deixar de lado a revisão linha a linha — o oposto de
abordagens como TDD/SDD, que forçam checkpoints de verificação ao longo do
caminho.
Notas de revisão (resumo das correções factuais)
1. Tokens e palavras: a relação estava invertida. O padrão usado pela Anthropic é ~4
caracteres por token (≈0,75 palavra/token em inglês), não "1/4 de palavra = 1
token".
2. Tamanho do CLAUDE.md: a recomendação oficial é manter o arquivo abaixo de
~200 linhas, não 80.
3. CLAUDE.md como "orquestrador": ele é melhor descrito como
memória/instrução persistente de projeto, carregada no início de toda sessão —
não como um orquestrador de workflow no sentido técnico.
4. Antigravity: confirmado como um harness/IDE agent-first do Google, multi-
modelo (suporta Gemini, e também modelos da Anthropic e OpenAI) — a
comparação com o Claude Code no texto original está correta.
5. Superpowers: confirmado como um plugin real e bem conhecido na comunidade
do Claude Code, com o comando de instalação citado sendo condizente com o
divulgado publicamente.
https://claude.ai/chat/7e84508a-94fb-42b2-b4e0-de876ece1fd5 Page 6 of 7