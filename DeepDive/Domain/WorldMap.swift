//
//  WorldMap.swift
//  DeepDive
//
//  ALL narrative prose lives here (ADR-002). This is declarative data that happens to be
//  written in Swift — no control flow, no engine logic. Adding a beat means listing what's
//  in it; every feature listed is immediately examinable by the player.
//
//  Death scenes, the madness scene and the escape scenes are FIXED scripts on purpose:
//  Foundation Models' guardrails can refuse dark content, so the climaxes are pre-authored
//  and delivered verbatim — the model never decides or improvises an ending.
//
//  In-game text is pt-BR. Identifiers stay English.

import Foundation

nonisolated enum WorldMap {
    static let beats: [BeatID: Beat] = [
        salao.id: salao,
        waterTrail.id: waterTrail,
        trifurcacao.id: trifurcacao,
        corridor.id: corridor,
        steelDoor.id: steelDoor,
        hayRoom.id: hayRoom,
    ]

    static func beat(_ id: BeatID) -> Beat {
        // Every BeatID has an entry; a missing one is a programming error, not a data error.
        beats[id]!
    }

    // MARK: - Salão Principal (spawn)

    static let salao = Beat(
        id: .salao,
        // She wakes up scared and confused. She does not deliver a room description to a
        // stranger — that comes later, and only if the player asks.
        arrival: "oi? tem alguém aí? por favor me responde",
        arrivalBeats: [
            "eu não sei onde eu tô. eu acordei agora no chão e não lembro de ter chegado aqui",
            "tá tudo úmido e escuro. eu tô com um lampião aceso na mão e eu não sei de onde ele veio",
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
        é uma ruína gigante. pilares antigos, árvores crescendo torto pelas frestas, goteira \
        por todo lado. e tem construções presas no teto, de cabeça pra baixo, como se o chão \
        fosse lá em cima. daqui saem dois caminhos: uma trilha que entra na água, e uma estrada \
        de paralelepípedos que segue reto até uma trifurcação.
        """,
        features: [
            Feature("pilares", aliases: ["pilar", "pilares", "coluna", "colunas"], detail: """
            são enormes e tem entalhe em toda a superfície. metade tá caída. os que ficaram de \
            pé não parecem estar sustentando nada.
            """),
            Feature("agua", aliases: ["água", "agua", "lago", "riacho", "rio", "poça"], detail: """
            tá parada demais pra ser água de verdade. não reflete o teto direito, e a trilha \
            entra por dentro dela e some na escuridão.
            """, sanityDelta: -2),
            Feature("arvores", aliases: ["árvore", "arvores", "árvores", "arvore", "raiz", "raízes"], detail: """
            crescem de dentro da pedra, tortas, procurando uma luz que não existe aqui. a casca \
            é escura e molhada.
            """),
            Feature("teto", aliases: ["teto", "cima", "alto", "goteira", "goteiras", "construções", "construcoes", "casas"], detail: """
            eu não consigo ver onde ele termina. e tem construções inteiras lá em cima, presas \
            de cabeça pra baixo — janela, porta, escada, tudo apontando pro chão. quanto mais eu \
            olho mais parece que sou eu que tô pendurada.
            """, sanityDelta: -4),
            Feature("simbolos", aliases: ["símbolo", "simbolos", "símbolos", "entalhe", "entalhes", "escrita", "parede", "paredes"], detail: """
            tem símbolos entalhados por toda parte. não é nenhuma língua que eu reconheça, mas \
            eles se repetem num padrão.
            """),
            Feature("estrada", aliases: ["estrada", "paralelepípedo", "paralelepipedo", "caminho de pedra", "pedras"], detail: """
            pedra encaixada à mão, bem feita. segue reta até uma trifurcação que eu consigo ver \
            daqui. tem uma faca pequena caída no meio do caminho.
            """),
            Feature("trilha", aliases: ["trilha", "trilha da água", "trilha na agua", "caminho da água"], detail: """
            é uma trilha que desce e entra na água parada. dá pra ver que vai afundando aos \
            poucos, até a escuridão engolir tudo.
            """, sanityDelta: -2),
        ],
        exits: [
            Exit(aliases: ["estrada", "paralelepípedo", "paralelepipedo", "caminho de pedra", "frente", "reto", "trifurcação", "trifurcacao"], to: .trifurcacao),
            Exit(aliases: ["água", "agua", "trilha", "lago", "rio", "riacho", "trilha da água"], to: .waterTrail),
        ],
        items: [.knife]
    )

    // MARK: - Trilha na Água (fatal)

    static let waterTrail = Beat(
        id: .waterTrail,
        // She never stands here waiting for input: confirming the water plays the death
        // script. The texts below exist so the map stays total.
        arrival: "a água já passou do meu joelho e continua subindo.",
        revisit: "eu tô dentro da água de novo.",
        overview: "água parada até onde a luz alcança, num túnel de gruta. e o fundo descendo.",
        exits: []
    )

    // MARK: - Trifurcação (hub)

    static let trifurcacao = Beat(
        id: .trifurcacao,
        arrival: """
        cheguei no fim da estrada. é uma trifurcação: à esquerda tem um corredor comprido e \
        escuro, no meio uma porta enorme de aço com fechadura, e à direita uma porta de \
        madeira fechada, sem tranca.
        """,
        revisit: "tô de volta na trifurcação. os três caminhos continuam aqui.",
        sound: """
        tem corrente de ar vindo do corredor escuro, e ela faz um assobio baixo. e de vez em \
        quando tem um arrastado atrás da porta de madeira. bem devagar.
        """,
        smell: "cheiro de ferrugem perto da porta de aço, e uma coisa azeda vindo de baixo da porta de madeira.",
        overview: """
        um corredor escuro à esquerda, uma porta de aço maciça com uma fechadura grande no \
        meio, e uma porta de madeira sem trava à direita. atrás de mim, a estrada de volta \
        pro salão.
        """,
        features: [
            Feature("porta_madeira", aliases: ["porta de madeira", "madeira", "porta da direita"], detail: """
            madeira velha, inchada de umidade. não tem tranca, é só empurrar. tem umas marcas \
            na altura do meu peito que parecem arranhões, do lado de cá.
            """, sanityDelta: -2),
            Feature("porta_aco", aliases: ["porta de aço", "aço", "aco", "porta de ferro", "ferro", "porta de metal", "metal", "fechadura", "porta do meio"], detail: """
            aço maciço, com uma fechadura grande e antiga no meio. não tem maçaneta. sem a \
            chave certa isso aqui não abre.
            """),
            Feature("corredor", aliases: ["corredor", "corredor escuro", "passagem", "esquerda", "túnel", "tunel"], detail: """
            parece um túnel de catacumba velha. a luz não alcança o fim — e não é como se \
            estivesse longe, é como se o fim não estivesse lá.
            """, sanityDelta: -2),
        ],
        exits: [
            Exit(aliases: ["corredor", "corredor escuro", "passagem", "esquerda", "túnel", "tunel"], to: .corridor),
            Exit(
                aliases: ["porta de aço", "aço", "aco", "porta de ferro", "ferro", "porta de metal", "metal", "porta do meio"],
                to: .steelDoor,
                requires: { $0.has(.key) },
                blocked: "eu empurrei com tudo e não cede nem um milímetro. essa aqui tá trancada de verdade. precisa da chave."
            ),
            Exit(aliases: ["porta de madeira", "madeira", "porta da direita"], to: .hayRoom),
            Exit(aliases: ["salão", "salao", "voltar", "volta", "trás", "atras", "atrás", "estrada", "caminho de pedra"], to: .salao),
        ]
    )

    // MARK: - Corredor Escuro

    static let corridor = Beat(
        id: .corridor,
        // Entered lit, it's the death script; entered dark, she traverses straight through to
        // the steel door. Either way she never stands here — texts exist to keep the map total.
        arrival: "eu tô dentro do corredor. não dá pra ver o fim.",
        revisit: "o corredor de novo. continua sem fim à vista.",
        overview: "pedra dos dois lados e um escuro comprido que a luz não termina de atravessar.",
        exits: []
    )

    // MARK: - Além da Porta de Aço (caverna → saída)

    static let steelDoor = Beat(
        id: .steelDoor,
        // Arriving here IS the escape: the resolver plays the sanity variant right after this.
        arrival: """
        é uma caverna. bem menos úmida que o resto, o ar aqui é diferente. e lá no fundo tem \
        luz. não é reflexo, não é lampião. é luz de dia.
        """,
        revisit: "a caverna continua aqui, e a luz no fundo também.",
        overview: "uma caverna seca subindo em direção a uma boca de luz. dá pra ouvir folha, vento, mundo.",
        exits: []
    )

    // MARK: - Sala da Porta de Madeira (feno + chave)

    static let hayRoom = Beat(
        id: .hayRoom,
        // She only ever arrives here alive after knocking (the unknocked route is a death).
        arrival: """
        entrei. é uma sala apertada, o teto é baixo e tem feno cobrindo tudo, quase da minha \
        altura nos cantos. mal dá pra ver as paredes. e tem uma coisa: no meio do feno tem \
        alguma coisa pequena brilhando.
        """,
        revisit: "voltei pra sala do feno. o cheiro de palha continua o mesmo.",
        sound: """
        eu prendi a respiração pra escutar. o feno range sozinho, bem de leve, como se tivesse \
        acabado de parar de se mexer.
        """,
        smell: "cheiro seco de palha por cima, e por baixo um azedo de bicho, de coisa que dormiu aqui.",
        overview: """
        feno até quase a altura do peito, paredes de pedra que eu mal enxergo, a porta de \
        madeira atrás de mim. e um brilho pequeno no meio do feno, tipo metal.
        """,
        features: [
            Feature("feno", aliases: ["feno", "palha", "monte de feno", "chão", "chao"], detail: """
            palha seca, empilhada alta. o brilho tá fundo, no meio dela — pra pegar eu vou ter \
            que enfiar a mão, ou afastar a palha com alguma coisa.
            """, sanityDelta: -2),
            Feature("brilho", aliases: ["brilho", "chave", "coisa brilhando", "metal"], detail: """
            é uma chave! grande, de ferro, com a cabeça torta. tá funda no feno, mas dá pra \
            alcançar.
            """),
            Feature("paredes_feno", aliases: ["parede", "paredes", "pedra"], detail: """
            pedra em todos os lados, sem fresta nenhuma. essa sala não leva a lugar nenhum, é \
            um fim.
            """),
        ],
        exits: [
            Exit(aliases: ["porta", "voltar", "volta", "sair", "sai", "trás", "atras", "atrás", "trifurcação", "trifurcacao"], to: .trifurcacao),
            Exit(aliases: ["salão", "salao"], to: .salao),
        ],
        items: [.key]
    )

    // MARK: - Fixed death scripts (pre-authored, delivered verbatim)

    // Pacing note: these are short on purpose. A death is four or five messages that get
    // shorter, wetter and louder — a long, well-punctuated death reads as calm, and calm is
    // the one thing it must never read as.

    /// Death 1 — confirming the water trail.
    static let waterDeathScript = FixedScript(
        opener: "tá bem. eu tô entrando.",
        beats: [
            "a água tá morna. morna que nem sangue",
            "já passou da cintura tem coisa aqui embaixo tem COISA aqui",
            "não é peixe não é peixe não é",
            "ELA TÁ VINDO E A ÁGUA NEM MEXE",
            "NÃO NÃO OLHA PRA MIM ASSIM NÃ—",
        ]
    )

    /// Death 2 — entering the corridor with the lamp lit.
    static let corridorDeathScript = FixedScript(
        opener: "tá. eu tô entrando com o lampião aceso.",
        beats: [
            "isso não acaba. eu ando e não acaba",
            "tem respiração na minha frente e eu virei pra voltar e NÃO TEM MAIS ENTRADA",
            "tá dos dois lados tá dos dois lados",
            "eu não consigo andar me ajuda ME AJUDA",
            "SOCORRO SOCOR—",
        ]
    )

    /// Death 3 — opening the wood door without knocking. The creature waits inside the hay.
    static let hayMonsterDeathScript = FixedScript(
        opener: "tá bom. eu vou abrir sem bater.",
        beats: [
            "entrei. feno até o meu peito e uma chave brilhando no meio",
            "peraí o feno tá respirando",
            "TÁ RESPIRANDO",
            "ABRIU ELE ABRIU ME SOLTA",
            "ME SOL—",
        ]
    )

    /// Death 4 — setting the hay on fire with the lamp, after having knocked.
    static let hayFireDeathScript = FixedScript(
        opener: "tá certo. joguei o lampião no feno.",
        beats: [
            "subiu na hora. subiu TUDO",
            "a porta fechou sozinha e travou essa porta não tem tranca COMO ELA TRAVOU",
            "a fumaça tá preta eu não vejo nada arde ARDE",
            "não consigo respi—",
        ]
    )

    /// Death 5 — the player made it clear nobody is coming. She stops asking, and then she
    /// stops. Reached through `GameState.abandonmentLimit`, not through a place.
    static let abandonmentDeathScript = FixedScript(
        opener: "tá. entendi.",
        beats: [
            "eu vou parar de te encher. você não devia nem ter respondido a primeira vez",
            "eu vou sentar aqui um pouco. só isso. eu tô muito cansada",
            "sabe o que é engraçado? parou de fazer barulho desde que eu parei de andar",
            "tem alguma coisa parada na minha frente. eu acho que ela tava esperando eu desistir",
            "não faz mal. de qualquer jeito não tinha ninguém do outro lado",
        ]
    )

    /// Madness — sanity reached zero. Delivered verbatim; the broken glyphs are the point.
    static let madnessScript = FixedScript(
        opener: "sabe que eu ia te falar uma coisa",
        beats: [
            "não precisa mais procurar a saída",
            "eu parei de procurar faz tempo. aqui é quieto. aqui é bom",
            "eu vou ficar. eu quero ficar pra sempre",
            "os símbolos não são símbolos. são nomes. eu sei ler agora. eu sei ler",
            "◇ ∴ ▽ ◆ ∴ ◇◇",
            "▽▽ ◆ ◇ ∴∴ ▽ ◆◆ ∴",
            "◇◇◇",
        ]
    )

    // MARK: - The corridor traversed in the dark (the bypass route)

    static let corridorDarkTraversal = FixedScript(
        opener: "tá. eu vou no escuro, tateando a parede.",
        beats: [
            "eu não enxergo nada. só a pedra fria passando debaixo da minha mão",
            "tem um vento fraco vindo de frente. eu vou seguindo ele",
            "pisei numa coisa que rolou pro lado. eu não quero saber o que era",
            "tem uma claridade na frente. tem uma SAÍDA na frente",
            "eu saí. eu tô do outro lado — isso aqui é do lado de dentro da porta de aço!",
        ]
    )

    /// What she says when the key turns — the opener for the escape via the steel door.
    static let steelDoorOpens = "a chave entrou dura, mas girou. a porta tá abrindo. tá ABRINDO."

    // MARK: - Escape variants (one ending, three states of mind)

    /// Sanity ≥ 80: she walks out whole.
    static let escapeUnharmedScript = FixedScript(
        opener: "eu tô subindo em direção à luz. o ar vai ficando quente.",
        beats: [
            "é mato. é MATO, é verde, é floresta de verdade",
            "eu saí. eu tô fora. tem sol na minha cara e cheiro de chuva no ar",
            "obrigada. sério. todo mundo teria parado de responder e você não parou",
            "eu vou seguir o sol até achar gente. quando eu tiver sinal de novo, a primeira mensagem é sua",
        ]
    )

    /// 40 ≤ sanity < 80: she gets out, but carries it with her.
    static let escapeShakenScript = FixedScript(
        opener: "eu tô subindo em direção à luz. devagar. minhas pernas tão tremendo.",
        beats: [
            "é floresta. eu saí. eu tô fora",
            "eu devia tá feliz né. eu tô chorando e não é de alívio, eu não sei do que é",
            "ainda tô ouvindo as goteiras. aqui fora não tem goteira. eu sei que não tem",
            "obrigada por me tirar. só que uma parte de mim ficou lá embaixo, olhando pros símbolos",
            "quando eu tiver sinal eu te aviso que cheguei. não me esquece, tá?",
        ]
    )

    /// Sanity < 40: she reaches the way out and refuses it. The run still ends.
    static let escapeRefusedScript = FixedScript(
        opener: "eu tô vendo a saída. é mato lá fora. luz de dia.",
        beats: [
            "engraçado. eu passei esse tempo todo querendo isso",
            "você já reparou que os símbolos tão aqui também? na boca da caverna. até aqui",
            "eu não vou agora. eu quero ver o resto antes. só ver, rapidinho",
            "tem tanta coisa aqui embaixo que eu ainda não li",
            "eu vou voltar lá pra dentro. não me espera",
        ]
    )

    // MARK: - Studying the carvings (each reading costs more than the last)

    /// Sanity cost of each reading, matched by index to `symbolReadingTexts`.
    static let symbolReadingCosts = [-4, -8, -13, -18]

    static let symbolReadingTexts = [
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

    /// After the scale is spent she refuses to keep reading — the rest of the way down to
    /// madness has to come from somewhere else.
    static let symbolsExhausted = """
    não. eu não vou ler mais. se eu ler de novo eu não sei se eu volto. me pede qualquer \
    outra coisa.
    """

    // MARK: - Lamp lines (the fuel economy speaks through these)

    static let lampLitLine = "acendi o lampião. a luz é fraca, mas já dá pra enxergar alguma coisa."
    static let lampSnuffedLine = "apaguei o lampião. ficou bem mais escuro, mas economiza o óleo."
    static let lampLowFuelWarning = "e o lampião tá fraquejando — o óleo tá quase no fim."
    static let lampDiedLine = "o lampião tremeu e apagou no meio do caminho. acabou o óleo. não acende mais."
    static let lampDeadRefusal = "não dá. o óleo acabou de vez, esse lampião não acende nunca mais."
    static let lampAlreadyLitLine = "ele já tá aceso."
    static let lampAlreadySnuffedLine = "ele já tá apagado."

    /// How she describes the reservoir when she examines the lamp.
    static func lampFuelDescription(fuel: Int, isDead: Bool) -> String {
        if isDead { return "o reservatório tá seco. acabou o óleo de vez." }
        switch fuel {
        case 4...: return "o reservatório ainda tá com uma boa quantidade de óleo."
        case 2...3: return "o óleo já passou da metade. não é infinito."
        default: return "resta um dedinho de óleo. quase nada."
        }
    }

    // MARK: - Ending screens (original phrases, one per ending)

    /// Tone: legends of Ratanabá and lost cities. Original writing, no quotation.
    static let escapeEndingPhrase = "Nenhum mapa encontra a cidade. É ela que encontra quem procura."

    /// Tone: The King in Yellow. Original writing, no quotation.
    static let madnessEndingPhrase = "Há palavras que ninguém aprende. São elas que aprendem a gente."

    /// Tone: cosmic incomprehension. Original writing, no quotation. One is drawn at random.
    static let deathEndingPhrases = [
        "O que vive no fundo não tem nome. Nome é coisa de quem cabe no mundo.",
        "Ela chegou perto demais de entender.",
        "O escuro lá embaixo nunca esteve vazio. Só esteve esperando.",
        "Por um instante ela viu a forma do que não devia ter forma. Foi o bastante.",
        "A cidade não devora ninguém. Só recolhe o que sempre foi dela.",
    ]

    // MARK: - App Intents

    /// What Siri answers when there is no run to talk to.
    static let intentNoActiveRun = "ninguém respondeu. a conversa ficou no vácuo."

    /// Messages she sends with nobody prompting her — the payload of the random-hour
    /// Shortcuts automation. Authored, never model-generated: this fires with the app closed.
    static func unpromptedMessage(for state: GameState) -> String {
        var lines = [
            "você tá aí? eu tô começando a achar que eu imaginei você.",
            "eu ouvi uma coisa. me responde, por favor.",
            "faz quanto tempo que eu tô aqui? você consegue ver a hora aí?",
            "eu não sei se eu devia te contar isso, mas eu não sinto fome desde que eu acordei.",
            "eu fico olhando pro celular esperando aparecer alguma coisa sua.",
        ]

        // A couple of state-aware lines, so it doesn't feel like a generic drip.
        if state.has(.lampDead) {
            lines.append("tá tudo escuro agora. eu não sei mais pra que lado eu tava indo.")
        } else if state.lampFuel <= 2 {
            lines.append("o lampião tá bem fraco. eu queria decidir logo pra onde ir.")
        }
        if state.currentBeat == .trifurcacao {
            lines.append("tem um arrastado atrás da porta de madeira. começou de novo agora.")
        }
        if state.sanity < 40 {
            lines.append("eu acho que eu tô me acostumando com esse lugar. isso é ruim, né?")
        }

        return lines.randomElement() ?? lines[0]
    }

    /// A read-only summary for the "how is she doing" intent. Deliberately in her voice.
    static func statusLine(for state: GameState) -> String {
        let place: String = switch state.currentBeat {
        case .salao: "no salão dos pilares"
        case .waterTrail: "dentro da água"
        case .trifurcacao: "na trifurcação, entre os três caminhos"
        case .corridor: "dentro do corredor escuro"
        case .steelDoor: "do outro lado da porta de aço"
        case .hayRoom: "na sala do feno"
        }

        let carried = ItemID.allCases.filter { state.has($0) }.map(\.name)
        let carrying = carried.isEmpty ? "nada nas mãos" : carried.joined(separator: ", ")

        let mood: String = switch state.sanity {
        case 80...: "ela diz que tá inteira, com medo mas inteira"
        case 40..<80: "ela tá abalada, mas ainda tá andando"
        default: "ela tá muito mal. ela quase não fala frase inteira"
        }

        let lamp = state.has(.lampDead)
            ? "o lampião morreu"
            : (state.has(.lampLit) ? "o lampião tá aceso" : "o lampião tá apagado")

        return "ela tá \(place). \(carrying). \(lamp). \(mood)."
    }
}

/// A pre-authored scene: an acknowledgement followed by messages delivered in order, with
/// no player input in between. Kept verbatim — the narrator never touches these.
nonisolated struct FixedScript {
    let opener: String
    let beats: [String]
}
