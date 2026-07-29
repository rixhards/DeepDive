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
        escadaria.id: escadaria,
        cisterna.id: cisterna,
        coroa.id: coroa,
    ]

    static func place(_ id: PlaceID) -> Place {
        // Every PlaceID has an entry; a missing one is a programming error, not a data error.
        places[id]!
    }

    // MARK: - Salão grande de pedra

    static let salao = Place(
        id: .salao,
        // She wakes up scared and confused. She does not deliver a room description to a
        // stranger — that comes later, and only if the player asks.
        arrival: "oi? tem alguém aí? por favor me responde",
        arrivalBeats: [
            "eu não sei onde eu tô. eu acordei agora no chão e não lembro de ter chegado aqui",
            "tá tudo úmido e escuro. eu tô com um lampião na mão e eu não sei de onde ele veio",
            "me ajuda. por favor. o que eu faço?",
        ],
        revisit: "voltei pro salão dos pilares. a água continua parada do mesmo jeito.",
        sound: """
        eu fiquei bem quietinha pra escutar. tem água pingando do teto, várias goteiras em \
        tempos diferentes. e por baixo disso tem um som grave, contínuo, que eu não sei se é \
        som ou se é o chão vibrando.
        """,
        smell: "cheiro de pedra molhada, mato podre e um fundo doce meio enjoativo, tipo fruta passada.",
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
        sound: """
        tem corrente de ar vindo do corredor escuro, e ela faz um assobio baixo. e de vez em \
        quando tem um arrastado atrás da porta de madeira. bem devagar.
        """,
        smell: "cheiro de ferrugem perto da porta de metal, e uma coisa azeda vindo de baixo da porta de madeira.",
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
                to: .escadaria,
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
        sound: """
        eu prendi a respiração pra escutar. tem um farfalhar dentro do feno, e ele para toda \
        vez que eu paro de me mexer. tá me imitando.
        """,
        smell: "enxofre com amônia, tão forte que arde. é cheiro de bicho, de coisa viva que dorme aqui.",
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

    // MARK: - Escadaria (além da porta de ferro)

    static let escadaria = Place(
        id: .escadaria,
        arrival: """
        a porta abriu. tem luz do outro lado, eu tinha razão... mas não é o que eu pensei. não \
        vem de fora. é reflexo, batendo em alguma coisa lá embaixo. tem uma escada em espiral \
        descendo. pra sair daqui eu vou ter que descer mais.
        """,
        revisit: "tô no alto da escada em espiral de novo. a luz continua vindo debaixo.",
        sound: """
        o som daqui vem de baixo e sobe pela escada. é um eco de água em espaço grande, muito \
        maior do que qualquer coisa que eu vi até agora.
        """,
        smell: "cheiro de água parada e pedra fria. e um leve cheiro de sal, o que não faz sentido nenhum aqui.",
        overview: """
        uma escada em espiral descendo, com uma luz esverdeada vindo lá do fundo. as paredes são \
        cobertas de entalhes. atrás de mim, a porta de ferro.
        """,
        features: [
            Feature("luz", aliases: ["luz", "claridade", "brilho", "reflexo"], detail: """
            não é sol. é esverdeada, e treme igual luz batendo em água. eu queria tanto que \
            fosse sol.
            """),
            Feature("degraus", aliases: ["escada", "degrau", "degraus", "espiral"], detail: """
            os degraus são gastos bem no meio, fundos. muita gente desceu por aqui, muita mesmo. \
            e o desgaste é só de descida — eu não consigo achar marca de ninguém subindo.
            """),
            Feature("entalhes", aliases: ["entalhe", "entalhes", "gravura", "desenho", "parede", "paredes"], detail: """
            tem uma figura repetida em toda a parede, descendo a escada. ela desce, desce, \
            desce... e na última tem ela subindo de volta. só que a figura que sobe não é igual \
            à que desceu. tem alguma coisa a mais nela.
            """),
        ],
        exits: [
            Exit(aliases: ["descer", "desce", "baixo", "escada", "fundo", "cisterna"], to: .cisterna),
            Exit(aliases: ["voltar", "volta", "subir", "porta de ferro", "trás", "atras", "atrás", "trifurcação", "trifurcacao"], to: .trifurcacao),
        ]
    )

    // MARK: - Cisterna

    static let cisterna = Place(
        id: .cisterna,
        arrival: """
        cheguei numa cisterna gigante. tem colunas saindo de uma água preta, e o teto some no \
        escuro lá em cima. e tem um som aqui. parece música, mas nenhum instrumento faz isso. \
        vem debaixo d'água.
        """,
        revisit: "voltei pra cisterna. o som debaixo d'água não parou nem um segundo.",
        sound: """
        é isso que eu não consigo explicar. tem uma música vindo debaixo d'água, grave, e ela \
        nunca repete. eu fico esperando voltar pro começo e ela nunca volta. e quanto mais eu \
        escuto, mais eu acho que tem palavra ali dentro.
        """,
        smell: "cheiro de água parada e de sal. e por baixo, alguma coisa orgânica que eu prefiro não pensar no que é.",
        overview: """
        uma cisterna enorme de água preta, colunas afundando nela, e uma passagem subindo do \
        outro lado. tem um disco de pedra logo abaixo da superfície, perto da borda.
        """,
        features: [
            Feature("agua", aliases: ["água", "agua", "água preta", "superfície", "superficie"], detail: """
            não dá pra ver o fundo. e quando eu fico parada, sem me mexer, a superfície continua \
            mexendo sozinha.
            """),
            Feature("colunas", aliases: ["coluna", "colunas", "pilar", "pilares"], detail: """
            elas afundam na água e dá pra ver que continuam muito mais pra baixo do que essa \
            cisterna devia ter. tem os mesmos símbolos entalhados nelas.
            """),
            Feature("simbolos", aliases: ["símbolo", "simbolos", "símbolos", "escrita", "entalhe"], detail: ""),
            Feature("musica", aliases: ["som", "música", "musica", "barulho", "ruído", "ruido"], detail: """
            é grave e não repete nunca. eu fico esperando a melodia voltar pro começo e ela nunca \
            volta. quanto mais eu escuto, mais eu acho que tem palavra ali dentro.
            """),
            Feature("marcas", aliases: ["marca", "marcas", "nível", "nivel", "parede"], detail: """
            tem marcas de nível na parede. a água já esteve bem mais alta. e as marcas continuam \
            subindo muito acima da minha cabeça.
            """),
            Feature("disco", aliases: ["disco", "selo", "pedra redonda", "medalhão", "medalhao"], detail: """
            tem um disco de pedra logo abaixo da superfície, encostado na borda. dá pra ver os \
            símbolos na borda dele. tá fundo o suficiente pra eu ter que enfiar o braço.
            """),
        ],
        exits: [
            Exit(aliases: ["subir", "sobe", "passagem", "cima", "coroa", "outro lado"], to: .coroa),
            Exit(aliases: ["voltar", "volta", "escada", "trás", "atras", "atrás", "escadaria"], to: .escadaria),
        ]
    )

    // MARK: - Coroa

    static let coroa = Place(
        id: .coroa,
        arrival: """
        subi e cheguei numa câmara redonda. tem uma abertura no teto e dá pra ver o céu. céu \
        de verdade, com estrela e tudo. e tem uma porta de pedra aqui embaixo, com um encaixe \
        redondo no meio dela.
        """,
        revisit: "tô na câmara redonda de novo, com a abertura pro céu.",
        sound: """
        aqui é o único lugar em que eu escuto vento de verdade, vindo da abertura lá em cima. \
        vento normal. eu quase chorei de alívio.
        """,
        smell: "entra ar de fora pela abertura. cheiro de mato molhado, de floresta. é o primeiro cheiro bom desde que eu acordei.",
        overview: """
        uma câmara redonda, uma abertura no teto mostrando o céu estrelado, e uma porta de pedra \
        com um encaixe redondo vazio no meio.
        """,
        features: [
            Feature("ceu", aliases: ["céu", "ceu", "estrela", "estrelas", "abertura", "buraco"], detail: """
            é céu mesmo, com estrela. eu fiquei olhando um tempão. e aí eu percebi que eu não \
            reconheço nenhuma constelação. nenhuma. eu sei achar o cruzeiro do sul desde criança \
            e ele não tá ali.
            """),
            Feature("porta", aliases: ["porta", "porta de pedra", "encaixe", "buraco redondo", "fechadura"], detail: """
            porta de pedra maciça, sem maçaneta. no meio tem um encaixe redondo, do tamanho da \
            palma da minha mão, com símbolos em volta. falta alguma coisa aí.
            """),
        ],
        exits: [
            Exit(aliases: ["descer", "desce", "voltar", "volta", "cisterna", "trás", "atras", "atrás"], to: .cisterna),
        ]
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
    o disco encaixou e girou sozinho. a porta abriu pra dentro e do outro lado é mato, é \
    floresta, é o mundo. eu subi e o sol tava nascendo. eu conheço esse céu. tinha uma frase \
    gravada na pedra do lado de dentro: assim em cima como embaixo. lá embaixo eu não entendi. \
    agora eu entendo. eu saí. mas alguma coisa minha ficou lá — e alguma coisa de lá veio comigo.
    """

    /// Studying the carvings, one reading at a time. The last one is the surrender ending:
    /// she doesn't go mad from what happens to her, she goes mad from finally understanding.
    static let symbolReadings = [
        """
        tem símbolos entalhados por toda parte. não é nenhuma língua que eu reconheça, mas eles \
        se repetem num padrão. quanto mais eu olho, mais eu acho que entendo — e isso me assusta \
        mais do que não entender.
        """,
        """
        eu olhei de novo. alguns eu reconheço agora. não sei de onde. eu não devia reconhecer \
        nada disso.
        """,
        """
        não são desenhos. são sílabas. eu consigo separar as sílabas, eu consigo ver onde uma \
        acaba e a outra começa.
        """,
        """
        eu tô lendo. eu não devia conseguir mas eu tô lendo. tem um nome que se repete em todas \
        as paredes, o tempo todo, desde o começo.
        """,
    ]

    /// The moment she reads the name out loud — the point of no return.
    static let symbolFinalReading = """
    eu li o nome em voz alta. eu não queria. ele saiu sozinho da minha boca e agora eu não \
    consigo parar de repetir.
    """
}
