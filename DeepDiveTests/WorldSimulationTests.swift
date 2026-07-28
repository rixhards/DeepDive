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
        let outcome = act("joga o lampião no feno", &world)
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
        XCTAssertEqual(world.ending, .escape, "the key is the way out")
    }

    // MARK: - The corridor turns on whether she carries light

    func testCorridorWithLampLitIsFatal() {
        var world = World()
        world.place = .trifurcacao
        world.flags.insert(.lampLit)
        _ = act("entra no corredor", &world)
        XCTAssertEqual(world.ending, .taken, "light fixes the anomaly and the corridor never ends")
    }

    func testCorridorInTheDarkComesOutPastTheIronDoor() {
        var world = World()
        world.place = .trifurcacao
        _ = act("entra no corredor", &world)
        XCTAssertNil(world.ending, "the dark route survives")
        XCTAssertEqual(world.place, .pastIronDoor)
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
        _ = act("olha pros símbolos", &world)   // costs 3
        XCTAssertEqual(world.sanity, 0)
        XCTAssertEqual(world.ending, .surrender)
    }

    func testWaitingTwiceIsFatalButWarnsFirst() {
        var world = World()
        let warning = act("não faz nada", &world)
        XCTAssertNil(world.ending, "the first wait only warns")
        XCTAssertFalse(warning.facts.joined().isEmpty)

        _ = act("não faz nada", &world)
        XCTAssertEqual(world.ending, .taken, "ignoring the warning ends it")
    }

    func testWalkingIntoTheWaterEndsTheRun() {
        var world = World()
        _ = act("vai pela água", &world)
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

    func testHostilityIsDetectedAndCostsSanity() {
        var world = World()
        let before = world.sanity
        _ = act("cala a boca sua idiota", &world)
        XCTAssertLessThan(world.sanity, before)
    }
}
