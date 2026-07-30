//
//  PendingChoice.swift
//  DeepDive
//
//  Risky moves don't happen the moment they're ordered. She walks up to them, looks, and
//  asks once — so a death is always something the player confirmed, never something that
//  happened while they were still typing. The question is also the player's window to say
//  "voltar" and walk her back to a neutral scene instead.

import Foundation

nonisolated enum PendingChoice: String, Codable, Sendable {
    /// Wading into the water trail. Confirming is always fatal.
    case enterWater
    /// Entering the corridor with the lamp lit. Confirming is always fatal.
    case corridorLampLit
    /// Entering the corridor in the dark. Confirming traverses it — the bypass route out.
    case corridorDark
    /// Opening the wood door without having knocked. Confirming is fatal (the creature).
    case woodDoorUnknocked
    /// Entering the hay room after knocking. Safe, but she still checks.
    case enterHayRoom
    /// Reaching into the hay bare-handed. Confirming costs a fifth of her mind.
    case takeKeyBareHands
    /// Forcing the steel door's lock with the knife. Confirming breaks the knife.
    case lockpickSteelDoor
    /// Setting the hay on fire with the lamp. Confirming is fatal.
    case burnHay
    /// Lighting the lamp while standing at the mouth of the dark paths.
    case lightLampBeforeDark
    /// Snuffing the lamp while standing at the mouth of the dark paths.
    case snuffLampBeforeDark

    /// What she says when she stops at the edge of it.
    var question: String {
        switch self {
        case .enterWater:
            """
            eu cheguei na beira da água. ela tá parada demais, e daqui já dá pra ver que vai \
            ficando funda. você quer mesmo que eu siga por dentro dela?
            """
        case .corridorLampLit:
            """
            eu tô parada na entrada do corredor com o lampião aceso. e a luz não tá entrando — \
            ela para na boca do corredor igual parede. eu entro assim mesmo, com ele aceso?
            """
        case .corridorDark:
            """
            o lampião tá apagado. desse jeito eu não vou enxergar um palmo lá dentro, vou ter \
            que ir tateando a parede. eu vou no escuro mesmo?
            """
        case .woodDoorUnknocked:
            """
            a porta de madeira não tem tranca, é só empurrar. mas tem umas marcas de arranhão \
            desse lado, na altura do meu peito, e eu não bati pra avisar que eu tô aqui. \
            eu abro assim mesmo?
            """
        case .enterHayRoom:
            """
            depois que eu bati, o que tava se arrastando aí dentro foi embora. acho que agora \
            dá pra entrar. eu entro?
            """
        case .takeKeyBareHands:
            """
            a chave tá funda no meio do feno, e eu vi alguma coisa se mexer aí dentro. você \
            quer mesmo que eu enfie a mão desprotegida?
            """
        case .lockpickSteelDoor:
            """
            essa fechadura é bem maior que a minha lâmina. eu posso tentar forçar com a faca, \
            mas se ela quebrar eu fico sem. eu tento mesmo assim?
            """
        case .burnHay:
            """
            você quer que eu jogue o lampião no feno? essa sala é toda de pedra, não tem janela \
            e a porta abre pra dentro. tem certeza?
            """
        case .lightLampBeforeDark:
            """
            acender o lampião aqui? o corredor fica esquisito perto da luz, parece que ela \
            incomoda alguma coisa. e o óleo não é infinito. acendo mesmo?
            """
        case .snuffLampBeforeDark:
            """
            apagar o lampião aqui? vai ficar tudo preto na mesma hora. tem certeza?
            """
        }
    }

    /// The beat this choice would move her into, when it's a move at all. Used to read a
    /// repeated instruction as insistence instead of starting the same question over.
    var destination: BeatID? {
        switch self {
        case .enterWater: .waterTrail
        case .corridorLampLit, .corridorDark: .corridor
        case .woodDoorUnknocked, .enterHayRoom: .hayRoom
        case .takeKeyBareHands, .lockpickSteelDoor, .burnHay,
             .lightLampBeforeDark, .snuffLampBeforeDark: nil
        }
    }

    /// A short nudge for when the player said something that wasn't an answer. She stays
    /// where she is with the question still open, instead of losing the scene.
    var reminder: String {
        switch self {
        case .enterWater:
            "e eu continuo aqui na beira da água, esperando. eu entro ou não?"
        case .corridorLampLit:
            "eu ainda tô na boca do corredor com o lampião aceso. eu entro assim?"
        case .corridorDark:
            "e eu continuo parada aqui no escuro. eu vou ou não?"
        case .woodDoorUnknocked:
            "minha mão ainda tá na porta de madeira. eu abro?"
        case .enterHayRoom:
            "a porta tá aberta na minha frente. eu entro?"
        case .takeKeyBareHands:
            "e a chave continua lá no meio do feno. eu enfio a mão ou não?"
        case .lockpickSteelDoor:
            "eu ainda tô com a lâmina na fechadura. tento forçar?"
        case .burnHay:
            "eu ainda tô com o lampião na mão, em cima do feno. é isso mesmo que você quer?"
        case .lightLampBeforeDark:
            "eu acendo o lampião ou não?"
        case .snuffLampBeforeDark:
            "eu apago o lampião ou não?"
        }
    }

    /// What she says when the player backs her off.
    var refusal: String {
        switch self {
        case .enterWater:
            "tá bom. eu vou me afastar da água. obrigada por não deixar eu entrar aí."
        case .corridorLampLit:
            "tá. eu saí de perto do corredor. a gente pensa em outra coisa."
        case .corridorDark:
            "beleza, eu recuei. no escuro total eu também não tava confiante."
        case .woodDoorUnknocked:
            "beleza, eu tirei a mão da porta. não vou abrir por enquanto."
        case .enterHayRoom:
            "tá, eu fico aqui fora por enquanto."
        case .takeKeyBareHands:
            "tá, tirei a mão. deve ter outro jeito de pegar essa chave."
        case .lockpickSteelDoor:
            "melhor não arriscar a faca. ela ainda pode servir pra outra coisa."
        case .burnHay:
            "tá certo. eu abaixei o lampião. seria burrice mesmo."
        case .lightLampBeforeDark:
            "tá, deixei apagado por enquanto."
        case .snuffLampBeforeDark:
            "tá, deixei aceso então."
        }
    }
}
