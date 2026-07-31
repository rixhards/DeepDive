//
//  NarratorTests.swift
//  DeepDiveTests
//

import XCTest
@testable import DeepDive

/// Main-actor because `Narrator` is: the real implementation owns a live model session.
@MainActor
final class NarratorTests: XCTestCase {
    private func request(facts: [String]) -> NarrationRequest {
        NarrationRequest(
            facts: facts,
            sanity: 30,
            beat: .salao,
            beatSummary: "",
            carrying: [],
            memory: StoryMemory.initial()
        )
    }

    func testStaticNarratorReturnsFactsUnchanged() async {
        let narrator = StaticNarrator()
        let result = await narrator.narrate(request(facts: ["a personagem está com medo"]))
        XCTAssertEqual(result, "a personagem está com medo")
    }

    // MARK: - StoryMemory is derived from the authoritative state

    func testStoryMemoryRebuildTracksDiscoveries() {
        var state = GameState()
        state.inventory.insert(.key)
        state.flags.insert(.knockedWoodDoor)
        let memory = StoryMemory.rebuild(from: state, keepingRecent: ["jogador: oi"])

        XCTAssertTrue(memory.discoveredInformation.contains { $0.contains("chave") })
        XCTAssertTrue(memory.discoveredInformation.contains { $0.contains("bateu") })
        XCTAssertEqual(memory.recentNarrative, ["jogador: oi"])
        XCTAssertTrue(memory.currentObjectives.first?.contains("porta de aço") == true,
                      "holding the key changes what she's trying to do")
    }

    func testStoryMemoryKeepsOnlyTheNewestNarrativeLines() {
        var memory = StoryMemory.initial()
        for index in 1...10 {
            memory.noteExchange(playerText: "mensagem \(index)", reply: "resposta \(index)")
        }
        XCTAssertEqual(memory.recentNarrative.count, StoryMemory.recentNarrativeLimit)
        XCTAssertTrue(memory.recentNarrative.last?.contains("resposta 10") == true)
    }

    // MARK: - The harness must never reach the player (regression, 2026-07-29)

    /// She once typed "SANIDADE agora: 70/100." at the player, straight out of the prompt.
    func testCleanDeletesEchoedSanityScaffolding() {
        let narrator = FoundationModelsNarrator()
        XCTAssertEqual(
            narrator.clean("oi, tem alguém aí?\nSANIDADE agora: 70/100."),
            "oi, tem alguém aí?"
        )
        XCTAssertEqual(
            narrator.clean("FATOS (abalada): eu tô com medo"),
            "",
            "a line that is only scaffolding leaves nothing behind"
        )
    }

    func testCleanStripsAnInlineSanityReadout() {
        let narrator = FoundationModelsNarrator()
        let cleaned = narrator.clean("eu não sei o que fazer. minha sanidade é 45/100. me ajuda.")
        XCTAssertFalse(cleaned.contains("45/100"))
        XCTAssertTrue(cleaned.contains("eu não sei o que fazer"))
        XCTAssertTrue(cleaned.contains("me ajuda"))
    }

    // MARK: - She must not repeat herself (feedback, 2026-07-29)

    func testRepeatedSentencesWithinOneReplyAreDropped() {
        let text = "peguei a faca. estou tão cansada e com medo. estou tão cansada e com medo."
        let result = FoundationModelsNarrator.stripRepeats(in: text, avoiding: "")
        XCTAssertEqual(result, "peguei a faca. estou tão cansada e com medo.")
    }

    func testSentencesSheJustSaidAreDropped() {
        let previous = "não sei onde eu tô. estou tão cansada e com medo."
        let text = "achei uma porta de aço. Estou tão cansada e com medo!"
        let result = FoundationModelsNarrator.stripRepeats(in: text, avoiding: previous)
        XCTAssertEqual(result, "achei uma porta de aço.", "the recycled complaint goes")
    }

    func testShortInterjectionsSurviveDeduplication() {
        let result = FoundationModelsNarrator.stripRepeats(in: "tá. tá. eu vou.", avoiding: "tá.")
        XCTAssertTrue(result.contains("tá"), "voice tics are not repetition: \(result)")
        XCTAssertTrue(result.contains("eu vou"))
    }

    func testDeduplicationKeepsDistinctSentences() {
        let text = "tem uma chave no feno. eu preciso da faca pra pegar."
        XCTAssertEqual(FoundationModelsNarrator.stripRepeats(in: text, avoiding: "oi?"), text)
    }

    // MARK: - Repetition window (spec 012)

    /// The opening bug: comparing against only the last reply let a whole message from two
    /// turns back come through untouched.
    func testSentencesFromTwoRepliesBackAreDropped() {
        let window = [
            "oi? tem alguém aí? por favor me responde.",
            "eu não sei onde eu tô. tô tão assustada.",
        ]
        let text = "oi? tem alguém aí? por favor me responde. tá tudo úmido e escuro aqui."
        let result = FoundationModelsNarrator.stripRepeats(in: text, avoiding: window)
        // "oi?" stays: short fragments are voice, not repetition. The two full sentences she
        // already said two messages ago are what had to go.
        XCTAssertFalse(result.contains("tem alguém aí"), "echoed from two replies back: \(result)")
        XCTAssertFalse(result.contains("por favor me responde"), "echoed: \(result)")
        XCTAssertTrue(result.contains("tá tudo úmido e escuro aqui."), "new content kept: \(result)")
    }

    /// Same input, one-entry window: this is what shipped before spec 012, and it is what the
    /// player saw. Kept so the regression is visible rather than merely described.
    func testSingleEntryWindowIsWhatLetTheEchoThrough() {
        let text = "oi? tem alguém aí? por favor me responde. tá tudo úmido e escuro aqui."
        let result = FoundationModelsNarrator.stripRepeats(
            in: text,
            avoiding: ["eu não sei onde eu tô. tô tão assustada."]
        )
        XCTAssertEqual(result, text, "with only the immediately previous reply, the echo survives")
    }

    func testWindowKeepsSentencesItHasNeverSeen() {
        let window = ["oi? tem alguém aí?", "tá tudo úmido e escuro aqui."]
        let text = "achei uma porta de aço com fechadura."
        XCTAssertEqual(FoundationModelsNarrator.stripRepeats(in: text, avoiding: window), text)
    }

    func testEmptyWindowChangesNothing() {
        let text = "tem uma chave no feno."
        XCTAssertEqual(FoundationModelsNarrator.stripRepeats(in: text, avoiding: [String]()), text)
    }

    // MARK: - Substance guard (spec 012)

    /// Observed on device after widening the window: the model echoed a whole previous
    /// message, every real sentence was stripped, and the leftover "oi?" passed a guard that
    /// only tested for emptiness — so she sent three bubbles that each said just "oi?".
    func testLeftoverInterjectionDoesNotCountAsSomethingToSay() {
        let stripped = FoundationModelsNarrator.stripRepeats(
            in: "oi? tem alguém aí? por favor me responde.",
            avoiding: ["oi? tem alguém aí? por favor me responde."]
        )
        XCTAssertEqual(stripped, "oi?", "only the voice tic survives")
        XCTAssertFalse(
            FoundationModelsNarrator.hasSubstance(stripped),
            "so the narrator must fall back to the authored facts instead of sending it"
        )
    }

    func testARealSentenceCountsAsSubstance() {
        XCTAssertTrue(FoundationModelsNarrator.hasSubstance("tá tudo úmido e escuro aqui."))
    }

    func testEmptyTextHasNoSubstance() {
        XCTAssertFalse(FoundationModelsNarrator.hasSubstance(""))
    }

    // MARK: - FoundationModelsNarrator.clean(_:) defensive post-processing

    func testCleanStripsSurroundingQuotes() {
        let narrator = FoundationModelsNarrator()
        XCTAssertEqual(narrator.clean("\"tem alguém aí?\""), "tem alguém aí?")
    }

    func testCleanStripsEchoedBriefPrefix() {
        let narrator = FoundationModelsNarrator()
        XCTAssertEqual(narrator.clean("BRIEF: tem alguém aí?"), "tem alguém aí?")
        XCTAssertEqual(narrator.clean("resposta: tem alguém aí?"), "tem alguém aí?")
    }

    func testCleanLeavesWellFormedTextUnchanged() {
        let narrator = FoundationModelsNarrator()
        XCTAssertEqual(narrator.clean("peraí\ntá ouvindo isso?"), "peraí\ntá ouvindo isso?")
    }

    func testCleanStripsLeakedSpeakerLabels() {
        let narrator = FoundationModelsNarrator()
        XCTAssertEqual(narrator.clean("personagem: não sei o que fazer"), "não sei o que fazer")
        XCTAssertEqual(narrator.clean("Jogador: onde você está?"), "onde você está?")
        XCTAssertEqual(
            narrator.clean("personagem: não sei\njogador: cadê você\npersonagem: tô com medo"),
            "não sei\ncadê você\ntô com medo"
        )
    }

    func testCleanStripsAsteriskRoleplayNotation() {
        let narrator = FoundationModelsNarrator()
        XCTAssertEqual(narrator.clean("*olha a porta*\n*tá trancada*"), "olha a porta\ntá trancada")
    }

    func testCleanNeverLeaksSpeakerLabelsRegardlessOfCaseOrFormatting() {
        let narrator = FoundationModelsNarrator()
        let leaked = "PERSONAGEM: *some texto estranho*\nJOGADOR: isso não devia estar aqui"
        let cleaned = narrator.clean(leaked)
        XCTAssertFalse(cleaned.lowercased().contains("personagem:"))
        XCTAssertFalse(cleaned.lowercased().contains("jogador:"))
        XCTAssertFalse(cleaned.contains("*"))
    }
}
