//
//  WorldSimulationTests.swift
//  DeepDiveTests
//
//  Covers the paths that can't be judged by playing on device: the local parser (which has
//  to work without Apple Intelligence) and the resolver's interaction rules for the whole
//  beat map — every death, the fuel economy, the tone economy and the escape variants.

import XCTest
@testable import DeepDive

/// The local parser standing in for the model: the tests must run without Apple
/// Intelligence, which does not exist in the Simulator.
private struct StubParser: ActionParser {
    func parse(playerText: String, state: GameState) async -> PlayerAction {
        LocalActionParser.parse(playerText, state: state) ?? PlayerAction(verb: .unknown)
    }
}

final class WorldSimulationTests: XCTestCase {
    private let resolver = ActionResolver()

    private func act(_ text: String, _ state: inout GameState) -> Outcome {
        guard let action = LocalActionParser.parse(text, state: state) else {
            return resolver.resolve(PlayerAction(verb: .unknown), state: &state)
        }
        return resolver.resolve(action, state: &state)
    }

    /// A full turn, including compound-command splitting. `async` because the parser is —
    /// blocking on it with a semaphore would deadlock against the main actor.
    private func runTurn(_ text: String, _ state: inout GameState) async -> [Outcome] {
        await TurnRunner(parser: StubParser()).run(playerText: text, state: &state)
    }

    /// Walks her (knock first) into the hay room, ready to search the hay.
    private func stateInsideHayRoom() -> GameState {
        var state = GameState()
        state.currentBeat = .trifurcacao
        _ = act("bate na porta de madeira", &state)
        _ = act("entra na porta de madeira", &state)
        _ = act("sim", &state)
        XCTAssertEqual(state.currentBeat, .hayRoom, "setup: she must actually be inside")
        return state
    }

    // MARK: - She reports state

    func testSheKnowsWhatSheIsCarryingAtSpawn() {
        var state = GameState()
        let said = act("o que você tem aí?", &state).facts.joined(separator: " ")
        XCTAssertTrue(said.contains("lampião"), "she wakes up with the lamp: \(said)")
        XCTAssertFalse(said.contains("faca"), "the knife starts on the floor, not with her: \(said)")
    }

    func testKnifeIsOnTheSalaoFloorAndCanBePickedUp() {
        var state = GameState()
        let looked = act("olha em volta", &state).facts.joined(separator: " ")
        XCTAssertTrue(looked.contains("faca"), "looking around must reveal the knife: \(looked)")

        _ = act("pega a faca", &state)
        XCTAssertTrue(state.has(.knife))
    }

    func testSheAlwaysDescribesWhereSheIs() {
        var state = GameState()
        let said = act("olha em volta", &state).facts.joined(separator: " ")
        XCTAssertTrue(said.contains("pilares"), "the overview must name what's actually here: \(said)")
    }

    func testEveryListedFeatureIsExaminableInEveryBeat() {
        for id in BeatID.allCases {
            let beat = WorldMap.beat(id)
            for feature in beat.features {
                var state = GameState()
                state.currentBeat = id
                guard let alias = feature.aliases.first else { continue }
                let said = act("olha pra \(alias)", &state).facts.joined(separator: " ")
                XCTAssertFalse(
                    said.contains("não tem nada assim aqui"),
                    "'\(alias)' is listed in \(id.rawValue) but examining it failed"
                )
            }
        }
    }

    // MARK: - Death 1: the water trail

    func testWaterAsksBeforeKilling() {
        var state = GameState()
        _ = act("vai pela água", &state)
        XCTAssertEqual(state.pending, .enterWater)
        XCTAssertNil(state.ending)

        _ = act("não", &state)
        XCTAssertNil(state.ending)
        XCTAssertEqual(state.currentBeat, .salao)
    }

    func testConfirmingTheWaterIsAlwaysFatal() {
        var state = GameState()
        _ = act("vai pela água", &state)
        let outcome = act("sim", &state)
        XCTAssertEqual(state.ending, .death)
        XCTAssertTrue(state.isFinished)
        XCTAssertFalse(outcome.beats.isEmpty, "the death plays out over several messages")
        XCTAssertTrue(outcome.raw, "death scripts are delivered verbatim, never narrated")
    }

    // MARK: - Death 2 / bypass: the corridor turns on the lamp

    func testCorridorWithLampLitAsksThenKills() {
        var state = GameState()
        state.currentBeat = .trifurcacao
        XCTAssertTrue(state.has(.lampLit), "she wakes with the lamp lit")
        _ = act("entra no corredor", &state)
        XCTAssertEqual(state.pending, .corridorLampLit)

        _ = act("sim", &state)
        XCTAssertEqual(state.ending, .death)
    }

    func testCorridorInTheDarkIsTheBypassToEscape() {
        var state = GameState()
        state.currentBeat = .trifurcacao
        state.flags.remove(.lampLit)

        _ = act("entra no corredor", &state)
        XCTAssertEqual(state.pending, .corridorDark, "the dark route still checks first")

        let outcome = act("sim", &state)
        XCTAssertEqual(state.ending, .escape, "crossing in the dark comes out the far side")
        XCTAssertEqual(state.currentBeat, .steelDoor)
        XCTAssertTrue(outcome.beats.count >= 3, "the traversal and the exit play out in pieces")
    }

    // MARK: - Death 3: the wood door and the knock

    func testEnteringUnknockedIsFatalAfterConfirmation() {
        var state = GameState()
        state.currentBeat = .trifurcacao
        _ = act("entra na porta de madeira", &state)
        XCTAssertEqual(state.pending, .woodDoorUnknocked)

        _ = act("sim", &state)
        XCTAssertEqual(state.ending, .death)
    }

    func testKnockingFirstMakesTheHayRoomSafe() {
        var state = GameState()
        state.currentBeat = .trifurcacao

        _ = act("bate na porta de madeira", &state)
        XCTAssertTrue(state.has(.knockedWoodDoor), "knocking must register")

        _ = act("entra na porta de madeira", &state)
        XCTAssertEqual(state.pending, .enterHayRoom, "after the knock the entry question changes")

        _ = act("sim", &state)
        XCTAssertEqual(state.currentBeat, .hayRoom)
        XCTAssertNil(state.ending, "the knocked route survives")
    }

    // MARK: - The key in the hay

    func testKnifeOnHayYieldsTheKeyAndSpendsTheKnife() {
        var state = stateInsideHayRoom()
        state.inventory.insert(.knife)
        let sanityBefore = state.sanity

        _ = act("corta o feno com a faca", &state)
        XCTAssertTrue(state.has(.key))
        XCTAssertFalse(state.has(.knife), "the knife is lost in the hay")
        XCTAssertEqual(state.sanity, sanityBefore, "the tool route costs no sanity")
    }

    func testBareHandsOnHayAskFirstThenCostTwentySanity() {
        var state = stateInsideHayRoom()
        let sanityBefore = state.sanity

        _ = act("enfia a mão no feno", &state)
        XCTAssertEqual(state.pending, .takeKeyBareHands, "reaching in blind needs a yes")
        XCTAssertFalse(state.has(.key))

        _ = act("sim", &state)
        XCTAssertTrue(state.has(.key))
        XCTAssertEqual(state.sanity, sanityBefore - 20, "the bare-hands route costs a fifth of her mind")
        XCTAssertNil(state.ending)
    }

    // MARK: - Death 4: burning the hay

    func testBurningTheHayAsksThenKills() {
        var state = stateInsideHayRoom()
        _ = act("bota fogo no feno", &state)
        XCTAssertEqual(state.pending, .burnHay)

        _ = act("sim", &state)
        XCTAssertEqual(state.ending, .death)
    }

    func testBurningNeedsALivingLamp() {
        var state = stateInsideHayRoom()
        state.flags.remove(.lampLit)
        state.flags.insert(.lampDead)
        _ = act("bota fogo no feno", &state)
        XCTAssertNil(state.pending, "no fire left to start one with")
        XCTAssertNil(state.ending)
    }

    // MARK: - The steel door

    func testSteelDoorIsLockedWithoutTheKey() {
        var state = GameState()
        state.currentBeat = .trifurcacao
        let said = act("abre a porta de aço", &state).facts.joined(separator: " ")
        XCTAssertEqual(state.currentBeat, .trifurcacao)
        XCTAssertNil(state.ending)
        XCTAssertTrue(said.contains("trancada") || said.contains("chave"), "she says why: \(said)")
    }

    func testLockpickAsksThenBreaksTheKnifeAndKeepsTheDoorShut() {
        var state = GameState()
        state.currentBeat = .trifurcacao
        state.inventory.insert(.knife)

        _ = act("usa a faca na porta de aço", &state)
        XCTAssertEqual(state.pending, .lockpickSteelDoor, "forcing the lock needs a yes")

        _ = act("sim", &state)
        XCTAssertFalse(state.has(.knife))
        XCTAssertTrue(state.has(.knifeBroken))
        XCTAssertEqual(state.currentBeat, .trifurcacao, "the door does not open")
        XCTAssertNil(state.ending)
    }

    func testTheKeyOpensTheSteelDoorStraightIntoTheEscape() {
        var state = GameState()
        state.currentBeat = .trifurcacao
        state.inventory.insert(.key)

        let outcome = act("abre a porta de aço", &state)
        XCTAssertEqual(state.ending, .escape)
        XCTAssertEqual(state.currentBeat, .steelDoor)
        XCTAssertTrue(outcome.raw, "the finale is authored, not narrated")
    }

    // MARK: - Escape variants by sanity (≥80 whole / 40–79 shaken / <40 refuses)

    private func escapeText(withSanity sanity: Int) -> String {
        var state = GameState()
        state.currentBeat = .trifurcacao
        state.inventory.insert(.key)
        state.sanity = sanity
        let outcome = act("abre a porta de aço com a chave", &state)
        XCTAssertEqual(state.ending, .escape, "every variant is still the escape ending")
        return ([outcome.facts.joined(separator: " ")] + outcome.beats).joined(separator: " ")
    }

    func testEscapeAtFullSanityLeavesWhole() {
        XCTAssertTrue(escapeText(withSanity: 80).contains("primeira mensagem é sua"))
    }

    func testEscapeMidSanityLeavesShaken() {
        XCTAssertTrue(escapeText(withSanity: 79).contains("não me esquece"))
        XCTAssertTrue(escapeText(withSanity: 40).contains("não me esquece"))
    }

    func testEscapeLowSanityRefusesToLeave() {
        XCTAssertTrue(escapeText(withSanity: 39).contains("não me espera"))
    }

    // MARK: - Lamp fuel

    func testLampBurnsOneFuelPerTransitionWhileLit() {
        var state = GameState()
        XCTAssertEqual(state.lampFuel, GameState.initialLampFuel)

        _ = act("segue pela estrada", &state)
        XCTAssertEqual(state.lampFuel, GameState.initialLampFuel - 1)

        _ = act("volta", &state)
        XCTAssertEqual(state.lampFuel, GameState.initialLampFuel - 2)
    }

    func testUnlitLampBurnsNothing() {
        var state = GameState()
        _ = act("apaga o lampião", &state)
        XCTAssertFalse(state.has(.lampLit))

        _ = act("segue pela estrada", &state)
        XCTAssertEqual(state.lampFuel, GameState.initialLampFuel, "no flame, no cost")
    }

    func testEmptyLampDiesForeverAndWarnsOnTheWay() {
        var state = GameState()
        state.lampFuel = 2

        let warning = act("segue pela estrada", &state)
        XCTAssertEqual(state.lampFuel, 1)
        XCTAssertTrue(
            ([warning.facts.joined()] + warning.beats).joined().contains("óleo"),
            "she warns when the oil runs low"
        )

        _ = act("volta", &state)
        XCTAssertEqual(state.lampFuel, 0)
        XCTAssertFalse(state.has(.lampLit), "the lamp goes out by itself")
        XCTAssertTrue(state.has(.lampDead))

        let refusal = act("acende o lampião", &state).facts.joined()
        XCTAssertFalse(state.has(.lampLit), "it can never be relit")
        XCTAssertTrue(refusal.contains("óleo"), "she says why: \(refusal)")
    }

    func testLampToggleAtTheTrifurcacaoAsksFirst() {
        var state = GameState()
        state.currentBeat = .trifurcacao
        _ = act("apaga o lampião", &state)
        XCTAssertEqual(state.pending, .snuffLampBeforeDark, "the lamp decision guards the dark paths")
        XCTAssertTrue(state.has(.lampLit), "nothing changes until the yes")

        _ = act("sim", &state)
        XCTAssertFalse(state.has(.lampLit))
    }

    func testLampTogglesFreelyInTheSalao() {
        var state = GameState()
        _ = act("apaga o lampião", &state)
        XCTAssertFalse(state.has(.lampLit))
        XCTAssertNil(state.pending)
        _ = act("acende o lampião", &state)
        XCTAssertTrue(state.has(.lampLit))
    }

    // MARK: - Tone economy (the LLM classifies, Swift decides)

    func testSupportiveMessagesHealSlightly() {
        var state = GameState()
        state.sanity = 50
        _ = act("calma, você consegue", &state)
        XCTAssertEqual(state.sanity, 52)
    }

    func testDistressingMessagesCost() {
        var state = GameState()
        _ = act("cala a boca sua idiota", &state)
        XCTAssertEqual(state.sanity, GameState.initialSanity - 4)
    }

    func testNeutralInstructionsAreFree() {
        var state = GameState()
        _ = act("olha em volta", &state)
        XCTAssertEqual(state.sanity, GameState.initialSanity)
    }

    // MARK: - Hostility escalates and abandonment ends the run (feedback, 2026-07-29)

    func testDistressingMessagesCostMoreEachTime() {
        var state = GameState()
        _ = act("cala a boca sua idiota", &state)
        XCTAssertEqual(state.sanity, 76, "the first sting is the authored -4")

        _ = act("você é inútil", &state)
        XCTAssertEqual(state.sanity, 68, "the second costs double")
    }

    func testTellingHerNobodyWillHelpEndsTheRun() {
        var state = GameState()
        _ = act("não ligo pra o que ta acontecendo contigo", &state)
        XCTAssertNil(state.ending, "the first one only hurts")

        _ = act("fodase", &state)
        XCTAssertNil(state.ending, "the second one hurts more")

        let outcome = act("não vou te ajudar", &state)
        XCTAssertEqual(state.ending, .death, "the third ends it regardless of sanity")
        XCTAssertGreaterThan(state.sanity, 0, "she didn't go mad — she was abandoned")
        XCTAssertTrue(outcome.raw, "the abandonment scene is authored")
        XCTAssertFalse(outcome.beats.isEmpty)
    }

    func testAbandonmentPhrasesAreReadAsHostile() {
        let state = GameState()
        for message in ["não ligo", "fodase", "não vou te ajudar", "resolve sozinha",
                        "problema seu", "tanto faz", "me deixa em paz"] {
            XCTAssertEqual(
                LocalActionParser.parse(message, state: state)?.tone, .distressing,
                "\"\(message)\" must land as hostile"
            )
        }
    }

    /// "Não ligo" parses as the verb `.no`; with nothing pending she used to answer
    /// "sim o quê?", which read as a bot ignoring an insult.
    func testHostileNoIsAnsweredInCharacterNotAsAConfusedYesNo() {
        var state = GameState()
        let said = act("não ligo", &state).facts.joined(separator: " ")
        XCTAssertFalse(said.contains("sim o quê"), "she must react to the cruelty: \(said)")
        XCTAssertLessThan(state.sanity, GameState.initialSanity)
    }

    // MARK: - A pending question survives anything that isn't an answer (feedback)

    func testNotUnderstandingKeepsThePendingQuestionAlive() {
        var state = GameState()
        _ = act("vai pela água", &state)
        XCTAssertEqual(state.pending, .enterWater)

        let outcome = act("asdfgh qwerty", &state)
        XCTAssertEqual(state.pending, .enterWater, "a misparse must not lose the scene")
        XCTAssertFalse(outcome.beats.isEmpty, "she restates the question")

        _ = act("sim", &state)
        XCTAssertEqual(state.ending, .death, "and the answer still works afterwards")
    }

    func testPassiveQuestionsKeepThePendingQuestionAlive() {
        var state = GameState()
        _ = act("vai pela água", &state)
        let outcome = act("o que você tem aí?", &state)
        XCTAssertEqual(state.pending, .enterWater, "answering a question is not changing her mind")
        XCTAssertTrue(
            outcome.beats.joined().contains("beira da água"),
            "she reminds the player what she asked: \(outcome.beats)"
        )
    }

    func testRepeatingTheSameMoveCountsAsInsistence() {
        var state = GameState()
        _ = act("vai pela água", &state)
        XCTAssertEqual(state.pending, .enterWater)

        // The player said it twice. She asked once. That is an answer.
        let outcome = act("segue pela água", &state)
        XCTAssertEqual(state.ending, .death, "she must not re-ask the same question forever")
        XCTAssertTrue(outcome.raw)
    }

    func testADifferentMoveStillCancelsThePendingQuestion() {
        var state = GameState()
        state.currentBeat = .trifurcacao
        _ = act("entra no corredor", &state)
        _ = act("volta pro salão", &state)
        XCTAssertNil(state.pending)
        XCTAssertEqual(state.currentBeat, .salao)
        XCTAssertNil(state.ending)
    }

    // MARK: - Compound commands (feedback)

    func testCompoundCommandDoesBothActs() async {
        var state = GameState()
        let outcomes = await runTurn("pega a faca e vai pela trilha da água", &state)

        XCTAssertTrue(state.has(.knife), "the first act happened")
        XCTAssertEqual(state.pending, .enterWater, "and the second one happened too")
        XCTAssertEqual(outcomes.count, 2, "each act gets its own message")
    }

    func testCompoundCommandStopsAtAPendingQuestion() async {
        var state = GameState()
        _ = await runTurn("vai pela água e volta pro salão", &state)
        XCTAssertEqual(state.pending, .enterWater, "she stopped to ask")
        XCTAssertEqual(state.currentBeat, .salao, "and never acted on what came after")
        XCTAssertNil(state.ending, "a compound command can never walk her into a death")
    }

    func testSplitOnlyHappensWhenEveryPartIsAnInstruction() {
        XCTAssertEqual(
            LocalActionParser.splitClauses("não sei quem é você e não ligo pra você").count, 1,
            "a sentence that merely contains 'e' is one message"
        )
        XCTAssertEqual(
            LocalActionParser.splitClauses("pega a faca e vai pela trilha").count, 2
        )
        XCTAssertEqual(
            LocalActionParser.splitClauses("acende o lampião e depois entra no corredor").count, 2
        )
    }

    func testCompoundCommandChargesToneOnlyOnce() async {
        var state = GameState()
        _ = await runTurn("calma, pega a faca e olha em volta", &state)
        XCTAssertEqual(state.sanity, GameState.initialSanity + 2, "one message, one tone")
    }

    // MARK: - Sanity events and the madness ending

    func testStudyingTheSymbolsCostsOnTheAuthoredScale() {
        var state = GameState()
        for cost in WorldMap.symbolReadingCosts {
            let before = state.sanity
            _ = act("examina os símbolos", &state)
            XCTAssertEqual(state.sanity, before + cost)
        }
        XCTAssertNil(state.ending, "the scale alone does not finish her")

        let before = state.sanity
        _ = act("examina os símbolos", &state)
        XCTAssertEqual(state.sanity, before, "after the scale she refuses to keep reading")
    }

    func testSanityZeroIsTheMadnessEnding() {
        var state = GameState()
        state.sanity = 3
        let outcome = act("cala a boca sua inutil", &state)
        XCTAssertEqual(state.sanity, 0)
        XCTAssertEqual(state.ending, .madness)
        XCTAssertTrue(state.isFinished)
        XCTAssertTrue(outcome.raw, "the madness script is fixed content")
        XCTAssertFalse(outcome.beats.isEmpty)
    }

    // MARK: - The return rule (neutral scenes are always reachable)

    func testVoltarEscapesAPendingDeathQuestion() {
        var state = GameState()
        state.currentBeat = .trifurcacao
        _ = act("entra no corredor", &state)
        XCTAssertNotNil(state.pending)

        _ = act("volta", &state)
        XCTAssertNil(state.pending, "a new instruction drops the question")
        XCTAssertEqual(state.currentBeat, .salao, "and 'voltar' walks her to safety")
        XCTAssertNil(state.ending)
    }

    func testHayRoomReturnsToTheTrifurcacao() {
        var state = stateInsideHayRoom()
        _ = act("volta", &state)
        XCTAssertEqual(state.currentBeat, .trifurcacao)
    }

    /// Looking around used to throw the question away, which is how a scene got lost every
    /// time the player asked her anything mid-decision. Now only another *act* cancels it.
    func testLookingAroundNoLongerCancelsThePendingQuestion() {
        var state = GameState()
        _ = act("vai pela água", &state)
        _ = act("olha em volta", &state)
        XCTAssertEqual(state.pending, .enterWater, "a passive look keeps the scene")
        XCTAssertNil(state.ending)

        _ = act("pega a faca", &state)
        XCTAssertNil(state.pending, "acting on something else drops the idea")
        XCTAssertNil(state.ending)
    }

    // MARK: - The good run, played end to end

    func testTheGoodEndingIsReachableByPlayingCorrectly() {
        var state = GameState()
        _ = act("pega a faca", &state)
        XCTAssertTrue(state.has(.knife))

        _ = act("segue pela estrada", &state)
        XCTAssertEqual(state.currentBeat, .trifurcacao)

        _ = act("bate na porta de madeira", &state)
        _ = act("entra na porta de madeira", &state)
        _ = act("sim", &state)
        XCTAssertEqual(state.currentBeat, .hayRoom)

        _ = act("corta o feno com a faca", &state)
        XCTAssertTrue(state.has(.key))

        _ = act("volta", &state)
        XCTAssertEqual(state.currentBeat, .trifurcacao)

        _ = act("abre a porta de aço", &state)
        XCTAssertEqual(state.ending, .escape)
        XCTAssertEqual(state.sanity, GameState.initialSanity, "the clean route costs nothing")
    }

    // MARK: - Failure stays in character

    func testUnrecognisedTargetsStillAnswerInHerVoice() {
        var state = GameState()
        let said = act("olha pro helicóptero", &state).facts.joined(separator: " ")
        XCTAssertFalse(said.isEmpty)
        XCTAssertFalse(said.lowercased().contains("não entendi"), "she must never break character: \(said)")
    }

    func testRepeatedFailuresDoNotRepeatTheSameLine() {
        var state = GameState()
        let first = act("olha pro helicóptero", &state).facts.joined()
        let second = act("olha pro helicóptero", &state).facts.joined()
        XCTAssertNotEqual(first, second)
    }

    func testYesWithNothingPendingJustConfusesHer() {
        var state = GameState()
        _ = act("sim", &state)
        XCTAssertEqual(state.currentBeat, .salao)
        XCTAssertNil(state.ending)
    }

    // MARK: - Local parser works without Apple Intelligence

    func testLocalParserHandlesAbbreviationsAndSplitsInstruments() {
        let state = GameState()
        XCTAssertEqual(LocalActionParser.parse("onde vc ta", state: state)?.verb, .look)
        XCTAssertEqual(LocalActionParser.parse("o que vc tem", state: state)?.verb, .inventory)
        XCTAssertEqual(LocalActionParser.parse("vc ta bem?", state: state)?.verb, .talk)

        let split = LocalActionParser.parse("usa a faca no feno", state: state)
        XCTAssertEqual(split?.verb, .use)
        XCTAssertEqual(split?.target, "feno")
        XCTAssertEqual(split?.instrument, "faca")
    }

    func testKnockAndBurnAreTheirOwnVerbs() {
        let state = GameState()
        let knock = LocalActionParser.parse("bate na porta de madeira", state: state)
        XCTAssertEqual(knock?.verb, .knock)
        XCTAssertEqual(knock?.target, "porta de madeira")

        let burn = LocalActionParser.parse("bota fogo no feno", state: state)
        XCTAssertEqual(burn?.verb, .burn)
        XCTAssertEqual(burn?.target, "feno")
    }

    func testLocalParserClassifiesTone() {
        let state = GameState()
        XCTAssertEqual(LocalActionParser.parse("calma, respira, tô aqui", state: state)?.tone, .supportive)
        XCTAssertEqual(LocalActionParser.parse("anda logo sua burra", state: state)?.tone, .distressing)
        XCTAssertEqual(LocalActionParser.parse("olha em volta", state: state)?.tone, .neutral)
    }

    /// "va" used to match inside "descreva", turning a look into a movement command.
    func testCuesMatchWholeWordsOnly() {
        let state = GameState()
        XCTAssertEqual(LocalActionParser.parse("descreva seus arredores", state: state)?.verb, .look)
        XCTAssertEqual(LocalActionParser.parse("descreva o ambiente", state: state)?.verb, .look)
        XCTAssertEqual(LocalActionParser.parse("siga em frente", state: state)?.verb, .go)
    }

    /// The model once invented the knife as an instrument and silently spent it.
    func testOpeningTheSteelDoorDoesNotSilentlySpendTheKnife() {
        var state = GameState()
        state.currentBeat = .trifurcacao
        state.inventory.insert(.knife)
        _ = act("tenta abrir a porta de aço", &state)
        XCTAssertTrue(state.has(.knife), "no instrument was named, so nothing may be spent")
        XCTAssertFalse(state.has(.knifeBroken))
        XCTAssertNil(state.pending, "and no lockpick question without the knife being offered")
    }

    // MARK: - She must never move on her own

    func testAskingWhoSheIsDoesNotMoveHer() {
        var state = GameState()
        let said = act("Oi, quem é você?", &state).facts.joined(separator: " ")
        XCTAssertEqual(state.currentBeat, .salao)
        XCTAssertTrue(said.contains("nome"), "she should actually answer it: \(said)")
    }

    func testConversationalQuestionsAreAnsweredNotObeyed() {
        for question in ["o que aconteceu com você?", "que lugar é esse?", "há quanto tempo você tá aí?",
                         "você tá sozinha?", "você se machucou?", "você sabe quem eu sou?"] {
            var state = GameState()
            let said = act(question, &state).facts.joined(separator: " ")
            XCTAssertEqual(state.currentBeat, .salao, "\(question) must not move her")
            XCTAssertNil(state.ending)
            XCTAssertFalse(said.isEmpty, "\(question) went unanswered")
        }
    }

    func testShortOrUnrelatedTargetsDoNotOpenExits() {
        for junk in ["e", "o", "a", "re", "tra", "helicóptero"] {
            var state = GameState()
            _ = act("vai \(junk)", &state)
            XCTAssertEqual(state.currentBeat, .salao, "'\(junk)' must not match a real exit")
        }
    }

    func testAliasMatchingDistinguishesSimilarThings() {
        XCTAssertTrue("aço".matchesAlias("porta de aço"))
        XCTAssertTrue("porta de aço".matchesAlias("aço"))
        XCTAssertTrue("escadas".matchesAlias("escada"))
        XCTAssertFalse("porta de aço".matchesAlias("porta de madeira"))
        XCTAssertFalse("e".matchesAlias("estrada"))
        XCTAssertFalse("tra".matchesAlias("estrada"))
    }

    // MARK: - She has senses everywhere

    func testSheCanListenAndSmellEverywhere() {
        for id in BeatID.allCases {
            var state = GameState()
            state.currentBeat = id
            XCTAssertFalse(act("escuta", &state).facts.joined().isEmpty, "no sound in \(id.rawValue)")

            var other = GameState()
            other.currentBeat = id
            XCTAssertFalse(act("que cheiro tem aí", &other).facts.joined().isEmpty, "no smell in \(id.rawValue)")
        }
    }
}
