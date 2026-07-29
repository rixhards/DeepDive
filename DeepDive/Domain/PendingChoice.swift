//
//  PendingChoice.swift
//  DeepDive
//
//  Irreversible moves don't happen the moment they're ordered. She walks up to them, looks,
//  and asks once — so a death is always something the player confirmed, never something that
//  happened while they were still typing.

import Foundation

enum PendingChoice: String, Codable {
    case enterWater
    case corridorWithLamp
    case woodDoorUnknocked
    case burnHay
    case swimCistern
    case waitAgain

    /// What she says when she stops at the edge of it.
    var question: String {
        switch self {
        case .enterWater:
            """
            eu cheguei na beira da água. daqui dá pra ver que ela não tá refletindo nada — nem \
            as colunas, nem a minha cara. você quer mesmo que eu entre aí?
            """
        case .corridorWithLamp:
            """
            eu tô parada na entrada do corredor com o lampião aceso. e a luz não tá entrando, \
            ela para na boca do corredor igual parede. eu entro assim mesmo?
            """
        case .woodDoorUnknocked:
            """
            a porta de madeira não tem tranca, é só empurrar. mas tem umas marcas de arranhão \
            desse lado, na altura do meu peito. eu abro?
            """
        case .burnHay:
            """
            você quer que eu jogue o lampião no feno? essa sala é toda de pedra, não tem janela \
            e a porta abre pra dentro. tem certeza?
            """
        case .swimCistern:
            """
            você quer que eu entre nessa água? o som tá vindo debaixo dela, e eu não consigo ver \
            o fundo. tem certeza mesmo?
            """
        case .waitAgain:
            """
            você quer mesmo que eu fique parada de novo? o que tava ecoando lá em cima tá mais \
            perto agora. eu consigo ouvir daqui.
            """
        }
    }

    /// What she says when the player backs her off.
    var refusal: String {
        switch self {
        case .enterWater: "tá bom. eu vou me afastar da água. obrigada por não deixar eu entrar aí."
        case .corridorWithLamp: "tá. eu saí de perto do corredor. a gente pensa em outra coisa."
        case .woodDoorUnknocked: "beleza, eu tirei a mão da porta. não vou abrir por enquanto."
        case .burnHay: "tá certo. eu abaixei o lampião. seria burrice mesmo."
        case .swimCistern: "graças a deus. eu recuei da borda. não era pra eu entrar ali."
        case .waitAgain: "você tem razão. eu não vou ficar parada esperando isso chegar."
        }
    }
}
