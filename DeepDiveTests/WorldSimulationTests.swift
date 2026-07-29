//
//  WorldSimulationTests.swift
//  DeepDiveTests
//
//  Covers the paths that can't be judged by playing on device: the local parser (which has to
//  work without Apple Intelligence) and the resolver's interaction rules.

import XCTest
@testable import DeepDive

final class WorldSimulationTests: XCTestCase {
    private let resolver = ActionResolver()

    private func act(_ text: String, _ world: inout World) -> Outcome {
        guard let action = LocalActionParser.parse(text, world: world) else {
            return resolver.resolve(PlayerAction(verb: .unknown), world: &world)
        }
        return resolver.resolve(action, world: &world)
    }

    // MARK: - She reports state (the premise points the dialog tree could not meet)

    func testSheAlwaysKnowsWhatSheIsCarrying() {
        var world = World()
        let outcome = act("o que você tem aí?", &world)
        let said = outcome.facts.joined(separator: " ")
        XCTAssertTrue(said.contains("faca"), "she must list the knife: \(said)")
        XCTAssertTrue(said.contains("lampião"), "she must list the lamp: \(said)")
    }

    func testSheAlwaysDescribesWhereSheIs() {
        var world = World()
        let said = act("olha em volta", &world).facts.joined(separator: " ")
        XCTAssertTrue(said.contains("pilares"), "the overview must name what's actually here: \(said)")
    }

    func testEveryListedFeatureIsExaminableInEveryPlace() {
        for id in PlaceID.allCases {
            let place = WorldMap.place(id)
            for feature in place.features {
                var world = World()
                world.place = id
                guard let alias = feature.aliases.first else { continue }
                let said = act("olha pra \(alias)", &world).facts.joined(separator: " ")
                XCTAssertFalse(
                    said.contains("não tem nada assim aqui"),
                    "'\(alias)' is listed in \(id.rawValue) but examining it failed"
                )
            }
        }
    }

    // MARK: - Interaction rules

    func testKnifeOnHayYieldsTheKeyAndCostsTheKnife() {
        var world = World()
        world.place = .hayRoom
        _ = act("corta o feno com a faca", &world)
        XCTAssertTrue(world.has(.key), "the knife route must still find the key")
        XCTAssertFalse(world.has(.knife), "the knife is spent")
        XCTAssertEqual(world.sanity, 80, "the tool route costs no sanity")
    }

    func testBareHandsOnHayYieldsTheKeyButCostsSanity() {
        var world = World()
        world.place = .hayRoom
        _ = act("enfia a mão no feno", &world)
        XCTAssertTrue(world.has(.key))
        XCTAssertTrue(world.has(.knife), "she kept the knife")
        XCTAssertLessThan(world.sanity, 80, "reaching in blind has a price")
    }

    func testLampOnHayEndsTheRun() {
        var world = World()
        world.place = .hayRoom
        _ = act("joga o lampião no feno", &world)
        let outcome = act("sim", &world)
        XCTAssertEqual(world.ending, .taken)
        XCTAssertFalse(outcome.beats.isEmpty, "the fire plays out over several beats")
    }

    func testIronDoorNeedsTheKey() {
        var world = World()
        world.place = .trifurcacao
        let blocked = act("abre a porta de ferro", &world).facts.joined(separator: " ")
        XCTAssertEqual(world.place, .trifurcacao, "she must not get through without the key")
        XCTAssertTrue(blocked.contains("trancada") || blocked.contains("cede"), "she says why: \(blocked)")

        world.inventory.insert(.key)
        _ = act("abre a porta de ferro com a chave", &world)
        XCTAssertEqual(world.place, .escadaria, "the key opens the way deeper, not straight out")
    }

    // MARK: - The corridor turns on whether she carries light

    func testCorridorWithLampLitIsFatal() {
        var world = World()
        world.place = .trifurcacao
        world.flags.insert(.lampLit)
        _ = act("entra no corredor", &world)
        _ = act("sim", &world)
        XCTAssertEqual(world.ending, .taken, "light fixes the anomaly and the corridor never ends")
    }

    func testCorridorInTheDarkComesOutPastTheIronDoor() {
        var world = World()
        world.place = .trifurcacao
        _ = act("entra no corredor", &world)
        XCTAssertNil(world.ending, "the dark route survives")
        XCTAssertEqual(world.place, .escadaria)
    }

    func testLampTogglesBothWays() {
        var world = World()
        world.place = .trifurcacao
        _ = act("acende o lampião", &world)
        XCTAssertTrue(world.has(.lampLit))
        _ = act("apaga o lampião", &world)
        XCTAssertFalse(world.has(.lampLit))
    }

    // MARK: - Sanity and endings

    func testSanityHittingZeroSurrendersImmediately() {
        var world = World()
        world.sanity = 2
        world.place = .salao
        _ = act("olha pros símbolos", &world)
        XCTAssertEqual(world.sanity, 0)
        XCTAssertEqual(world.ending, .surrender)
    }

    /// The surrender ending has to be reachable by playing, not just by arithmetic.
    func testReadingTheCarvingsToTheEndSurrenders() {
        var world = World()
        for reading in 1...5 {
            _ = act("olha pros símbolos", &world)
            if reading < 5 {
                XCTAssertNil(world.ending, "reading \(reading) must not end it yet")
            }
        }
        XCTAssertEqual(world.ending, .surrender, "the fifth reading is the point of no return")
    }

    /// The whole point of the good ending: it takes a specific, correct route.
    func testTheGoodEndingIsReachableByPlayingCorrectly() {
        var world = World()
        _ = act("segue pela estrada", &world)
        XCTAssertEqual(world.place, .trifurcacao)

        _ = act("bate na porta de madeira", &world)
        _ = act("entra na porta de madeira", &world)
        XCTAssertEqual(world.place, .hayRoom)

        // Hands on the hay keeps the knife for the cistern — the optimal trade.
        _ = act("enfia a mão no feno", &world)
        XCTAssertTrue(world.has(.key))
        XCTAssertTrue(world.has(.knife))

        _ = act("volta", &world)
        _ = act("abre a porta de ferro", &world)
        XCTAssertEqual(world.place, .escadaria)

        _ = act("desce a escada", &world)
        XCTAssertEqual(world.place, .cisterna)

        _ = act("pega o disco com a faca", &world)
        XCTAssertTrue(world.has(.seal), "the knife fishes the seal out")

        _ = act("sobe a passagem", &world)
        XCTAssertEqual(world.place, .coroa)

        _ = act("usa o disco na porta", &world)
        XCTAssertEqual(world.ending, .escape)
        XCTAssertGreaterThan(world.sanity, 0, "she has to come out alive and sane")
    }

    func testEnteringTheCisternWaterIsFatal() {
        var world = World()
        world.place = .cisterna
        _ = act("entra na água", &world)
        _ = act("sim", &world)
        XCTAssertEqual(world.ending, .taken)
    }

    func testComfortStopsHealingOnceItBecomesRoutine() {
        var world = World()
        world.sanity = 50
        for _ in 1...3 { _ = act("você tá bem?", &world) }
        let afterThree = world.sanity
        _ = act("você tá bem?", &world)
        XCTAssertEqual(world.sanity, afterThree, "the fourth reassurance must not heal")
    }

    func testWaitingTwiceIsFatalButWarnsFirst() {
        var world = World()
        let warning = act("não faz nada", &world)
        XCTAssertNil(world.ending, "the first wait only warns")
        XCTAssertFalse(warning.facts.joined().isEmpty)

        _ = act("não faz nada", &world)
        _ = act("sim", &world)
        XCTAssertEqual(world.ending, .taken, "ignoring the warning ends it")
    }

    func testWalkingIntoTheWaterEndsTheRun() {
        var world = World()
        _ = act("vai pela água", &world)
        _ = act("sim", &world)
        XCTAssertEqual(world.ending, .taken)
    }

    // MARK: - Failure stays in character

    func testUnrecognisedTargetsStillAnswerInHerVoice() {
        var world = World()
        let said = act("olha pro helicóptero", &world).facts.joined(separator: " ")
        XCTAssertFalse(said.isEmpty)
        XCTAssertFalse(said.lowercased().contains("não entendi"), "she must never break character: \(said)")
    }

    // MARK: - Local parser works without Apple Intelligence

    func testLocalParserHandlesAbbreviationsAndSplitsInstruments() {
        let world = World()
        XCTAssertEqual(LocalActionParser.parse("onde vc ta", world: world)?.verb, .look)
        XCTAssertEqual(LocalActionParser.parse("o que vc tem", world: world)?.verb, .inventory)
        XCTAssertEqual(LocalActionParser.parse("vc ta bem?", world: world)?.verb, .talk)

        let use = LocalActionParser.parse("corta o feno com a faca", world: world)
        XCTAssertEqual(use?.verb, .use)

        let split = LocalActionParser.parse("usa a faca no feno", world: world)
        XCTAssertEqual(split?.verb, .use)
        XCTAssertEqual(split?.target, "feno")
        XCTAssertEqual(split?.instrument, "faca")
    }

    // MARK: - Regressions from on-device play (2026-07-28)

    /// "va" used to match inside "descreva", turning a look into a movement command.
    func testCuesMatchWholeWordsOnly() {
        let world = World()
        XCTAssertEqual(LocalActionParser.parse("descreva seus arredores", world: world)?.verb, .look)
        XCTAssertEqual(LocalActionParser.parse("descreva o ambiente", world: world)?.verb, .look)
        XCTAssertEqual(LocalActionParser.parse("desce as escadas", world: world)?.verb, .go)
        XCTAssertEqual(LocalActionParser.parse("siga em frente", world: world)?.verb, .go)
    }

    /// "tenta abrir a de ferro" matched nothing locally, fell through to the model, and the
    /// model invented the knife as the instrument — she lost it without being told to.
    func testOpeningTheIronDoorDoesNotSilentlySpendTheKnife() {
        var world = World()
        world.place = .trifurcacao
        _ = act("tenta abrir a porta de ferro", &world)
        XCTAssertTrue(world.has(.knife), "no instrument was named, so nothing may be spent")
        XCTAssertFalse(world.has(.knifeBroken))
    }

    // MARK: - Irreversible actions are confirmed, never blind

    func testWalkingIntoTheWaterAsksBeforeKilling() {
        var world = World()
        let question = act("vai pela água", &world)
        XCTAssertNil(world.ending, "she must stop and ask first")
        XCTAssertEqual(world.pending, .enterWater)
        XCTAssertFalse(question.facts.joined().isEmpty)

        _ = act("não", &world)
        XCTAssertNil(world.ending, "saying no backs her off")
        XCTAssertNil(world.pending)
        XCTAssertEqual(world.place, .salao, "and leaves her where she was")
    }

    func testConfirmingTheWaterStillKills() {
        var world = World()
        _ = act("vai pela água", &world)
        _ = act("sim", &world)
        XCTAssertEqual(world.ending, .taken)
    }

    func testANewInstructionCancelsThePendingQuestion() {
        var world = World()
        _ = act("vai pela água", &world)
        _ = act("olha em volta", &world)
        XCTAssertNil(world.pending, "changing the subject drops the idea")
        XCTAssertNil(world.ending)
    }

    func testCorridorWithLampAsksFirst() {
        var world = World()
        world.place = .trifurcacao
        world.flags.insert(.lampLit)
        _ = act("entra no corredor", &world)
        XCTAssertEqual(world.pending, .corridorWithLamp)
        XCTAssertNil(world.ending)
    }

    // MARK: - She has senses

    func testSheCanListenAndSmellEverywhere() {
        for id in PlaceID.allCases {
            var world = World()
            world.place = id
            XCTAssertFalse(act("escuta", &world).facts.joined().isEmpty, "no sound in \(id.rawValue)")

            var other = World()
            other.place = id
            XCTAssertFalse(act("que cheiro tem aí", &other).facts.joined().isEmpty, "no smell in \(id.rawValue)")
        }
    }

    func testRepeatedFailuresDoNotRepeatTheSameLine() {
        var world = World()
        let first = act("olha pro helicóptero", &world).facts.joined()
        let second = act("olha pro helicóptero", &world).facts.joined()
        XCTAssertNotEqual(first, second, "she must not say the exact same thing twice in a row")
    }

    // MARK: - She must never move on her own (regression, 2026-07-28)

    /// "Oi, quem é você?" walked her all the way to the next scene, because a stray short
    /// target matched an exit through bidirectional substring matching.
    func testAskingWhoSheIsDoesNotMoveHer() {
        var world = World()
        let said = act("Oi, quem é você?", &world).facts.joined(separator: " ")
        XCTAssertEqual(world.place, .salao, "a question must never relocate her")
        XCTAssertFalse(said.isEmpty)
        XCTAssertTrue(said.contains("nome"), "she should actually answer it: \(said)")
    }

    func testConversationalQuestionsAreAnsweredNotObeyed() {
        for question in ["o que aconteceu com você?", "que lugar é esse?", "há quanto tempo você tá aí?",
                         "você tá sozinha?", "você se machucou?", "você sabe quem eu sou?"] {
            var world = World()
            let said = act(question, &world).facts.joined(separator: " ")
            XCTAssertEqual(world.place, .salao, "\(question) must not move her")
            XCTAssertNil(world.ending, "\(question) must not end the run")
            XCTAssertFalse(said.isEmpty, "\(question) went unanswered")
        }
    }

    /// A one-letter target used to satisfy almost every exit alias in the room.
    func testShortOrUnrelatedTargetsDoNotOpenExits() {
        for junk in ["e", "o", "a", "re", "tra", "helicóptero"] {
            var world = World()
            _ = act("vai \(junk)", &world)
            XCTAssertEqual(world.place, .salao, "'\(junk)' must not match a real exit")
        }
    }

    func testAliasMatchingDistinguishesSimilarThings() {
        XCTAssertTrue("ferro".matchesAlias("porta de ferro"))
        XCTAssertTrue("porta de ferro".matchesAlias("ferro"))
        XCTAssertTrue("escadas".matchesAlias("escada"))
        XCTAssertFalse("porta de ferro".matchesAlias("porta de madeira"))
        XCTAssertFalse("e".matchesAlias("estrada"))
        XCTAssertFalse("tra".matchesAlias("estrada"))
    }

    func testHostilityIsDetectedAndCostsSanity() {
        var world = World()
        let before = world.sanity
        _ = act("cala a boca sua idiota", &world)
        XCTAssertLessThan(world.sanity, before)
    }
}
