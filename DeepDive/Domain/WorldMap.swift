//
//  WorldMap.swift
//  DeepDive
//
//  ALL narrative prose lives here (ADR-002). This is declarative data that happens to be
//  written in Swift — no control flow, no engine logic. Adding a place means listing what's
//  in it; every feature listed is immediately examinable by the player.
//
//  In-game text is pt-BR. Identifiers stay English.

import Foundation

enum WorldMap {
    static let places: [PlaceID: Place] = [
        salao.id: salao,
        trifurcacao.id: trifurcacao,
        hayRoom.id: hayRoom,
        pastIronDoor.id: pastIronDoor,
    ]

    static func place(_ id: PlaceID) -> Place {
        // Every PlaceID has an entry; a missing one is a programming error, not a data error.
        places[id]!
    }

    // MARK: - Salão grande de pedra

    static let salao = Place(
        id: .salao,
        arrival: """
        acabei de acordar aqui e não sei como cheguei. é um lugar irracional — tem construção \
        que parece feita de cabeça pra baixo. tudo úmido, pingando. tem um caminho pela água, \
        bem parada, e outro que parece uma estrada de paralelepípedos.
        """,
        revisit: "voltei pro salão dos pilares. a água continua parada do mesmo jeito.",
        overview: """
        pilares antigos, muitos caídos. árvore crescendo torta pelas frestas da pedra. o teto \
        pinga sem parar e eu não vejo onde ele termina. a estrada de paralelepípedos segue reto \
        até uma trifurcação lá na frente, e tem o caminho pela água do outro lado.
        """,
        features: [
            Feature("pilares", aliases: ["pilar", "pilares", "coluna", "colunas"], detail: """
            são enormes e tem entalhe em toda a superfície. metade tá caída. os que ficaram de \
            pé não parecem estar sustentando nada.
            """),
            Feature("agua", aliases: ["água", "agua", "lago", "riacho", "rio", "poça"], detail: """
            tá parada demais pra água corrente. dá pra ver o fundo, e o fundo é fundo demais pro \
            tamanho disso aqui. não tá refletindo o teto direito.
            """),
            Feature("arvores", aliases: ["árvore", "arvores", "árvores", "arvore", "raiz", "raízes"], detail: """
            crescem de dentro da pedra, tortas, procurando uma luz que não existe aqui. a casca \
            é escura e molhada.
            """),
            Feature("teto", aliases: ["teto", "cima", "alto", "goteira", "goteiras"], detail: """
            eu não consigo ver onde termina. a água cai de algum lugar lá em cima e o som volta \
            errado, como se o espaço fosse maior do que a sala.
            """),
            Feature("simbolos", aliases: ["símbolo", "simbolos", "símbolos", "entalhe", "escrita", "parede", "paredes"], detail: """
            tem símbolos entalhados por toda parte. não é nenhuma língua que eu reconheça, mas \
            eles se repetem num padrão. quanto mais eu olho, mais eu acho que entendo — e isso \
            me assusta mais que não entender.
            """),
            Feature("estrada", aliases: ["estrada", "paralelepípedo", "paralelepipedo", "caminho de pedra", "pedras"], detail: """
            pedra encaixada à mão, bem feita. segue reta até uma trifurcação que eu consigo ver \
            daqui.
            """),
        ],
        exits: [
            Exit(aliases: ["estrada", "paralelepípedo", "paralelepipedo", "caminho de pedra", "frente", "reto", "trifurcação", "trifurcacao"], to: .trifurcacao),
        ]
    )

    // MARK: - Trifurcação

    static let trifurcacao = Place(
        id: .trifurcacao,
        arrival: """
        cheguei no fim do caminho de pedra. tem três saídas: uma porta de madeira, uma porta de \
        ferro com fechadura, e um corredor comprido e escuro.
        """,
        revisit: "tô de volta na trifurcação. as três saídas continuam aqui.",
        overview: """
        porta de madeira de um lado, porta de ferro com uma fechadura no meio, e um corredor \
        escuro do outro. atrás de mim é o caminho de pedra de volta pro salão.
        """,
        features: [
            Feature("porta_madeira", aliases: ["porta de madeira", "madeira", "porta da direita"], detail: """
            madeira velha, inchada de umidade. não tem fechadura, só empurrar. tem umas marcas \
            na altura do meu peito que parecem arranhões, do lado de cá.
            """),
            Feature("porta_ferro", aliases: ["porta de ferro", "ferro", "porta de metal", "metal", "fechadura", "porta do meio"], detail: """
            ferro maciço, com uma fechadura grande e antiga no meio. não tem maçaneta. sem a \
            chave certa isso aqui não abre.
            """),
            Feature("corredor", aliases: ["corredor", "corredor escuro", "passagem", "esquerda"], detail: """
            a luz do meu lampião quase não alcança nada lá dentro. é estranho — parece que as \
            sombras fogem dela e esticam o corredor pra mais longe do que ele devia ir.
            """),
        ],
        exits: [
            Exit(
                aliases: ["porta de ferro", "ferro", "porta de metal", "metal", "porta do meio"],
                to: .pastIronDoor,
                requires: { $0.has(.key) },
                blocked: "eu empurrei com tudo e não cede nem um milímetro. essa aqui tá trancada de verdade."
            ),
            Exit(aliases: ["porta de madeira", "madeira", "porta da direita"], to: .hayRoom),
            Exit(aliases: ["salão", "salao", "voltar", "volta", "trás", "atras", "atrás", "caminho de pedra", "estrada"], to: .salao),
        ]
    )

    // MARK: - Sala do feno

    static let hayRoom = Place(
        id: .hayRoom,
        arrival: """
        entrei. é apertado aqui, todo de pedra, e tem feno cobrindo o chão inteiro. alguma coisa \
        se arrastou pra dentro do feno na hora que eu abri a porta. o cheiro é de esgoto, forte, \
        arde na garganta.
        """,
        revisit: "voltei pra sala do feno. o cheiro continua insuportável.",
        overview: """
        uma sala pequena de pedra, feno cobrindo o chão todo, e a porta de madeira atrás de mim. \
        não tem mais saída nenhuma daqui.
        """,
        features: [
            Feature("feno", aliases: ["feno", "palha", "monte de feno", "chão", "chao"], detail: """
            palha seca, empilhada bem alto num canto. tem alguma coisa embaixo, eu vi mexer. se \
            eu quiser procurar aí dentro vou ter que enfiar a mão — ou usar alguma coisa pra \
            afastar a palha.
            """),
            Feature("cheiro", aliases: ["cheiro", "fedor", "amônia", "amonia", "enxofre"], detail: """
            enxofre misturado com amônia. é o tipo de cheiro que gruda e que eu não vou \
            conseguir tirar do nariz tão cedo.
            """),
            Feature("paredes_feno", aliases: ["parede", "paredes", "pedra"], detail: """
            pedra em todos os lados, sem fresta nenhuma. essa sala não leva a lugar nenhum, é um \
            fim.
            """),
        ],
        exits: [
            Exit(aliases: ["porta", "voltar", "volta", "sair", "trás", "atras", "atrás", "trifurcação", "trifurcacao"], to: .trifurcacao),
        ]
    )

    // MARK: - Além da porta de ferro (placeholder)

    static let pastIronDoor = Place(
        id: .pastIronDoor,
        arrival: """
        a chave girou e a porta abriu. tem luz do outro lado — luz de verdade, não é do lampião. \
        eu tô vendo folha, tô vendo mato. acho que é a saída.
        """,
        revisit: "tô na passagem com a luz vindo de fora.",
        overview: "uma passagem curta, e no fim dela luz do dia entrando por uma abertura.",
        features: [
            Feature("luz", aliases: ["luz", "abertura", "saída", "saida", "fora", "mato", "folha"], detail: """
            é dia lá fora. eu tinha esquecido que existia dia.
            """),
        ],
        exits: []
    )

    // MARK: - Endings

    /// Delivered verbatim, without the narrator — this text is malformed on purpose and
    /// narration would rewrite it into clean prose.
    static let surrenderText = """
    não precisa mais procurar a saída
    eu parei faz tempo. aqui é quieto. aqui é bom
    os símbolos não são símbolos. são nomes
    eu sei ler agora. eu sei ler. eu sei ler
    ◇ ∴ ▽ ◆ ∴ ◇◇
    ◇◇◇
    """

    static let takenText = """
    tem alguma coisa aqui
    não é uma pessoa
    tem braços mas não são braços. são muitos e é um só
    espera. eu vi ele antes dele virar. eu vi ANTES
    ele não chegou. ele já tava. sempre esteve
    a forma dele não fecha. eu olho e ela não
    """

    static let escapeText = """
    eu passei. é a floresta, é o mundo real, o ar entrou de uma vez e eu caí de joelhos. tinha \
    uma frase gravada do lado de dentro da porta: assim em cima como embaixo. lá embaixo eu não \
    entendi. agora eu entendo. tô fora. mas alguma coisa minha ficou lá.
    """
}
