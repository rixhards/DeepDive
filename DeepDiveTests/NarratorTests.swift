//
//  NarratorTests.swift
//  DeepDiveTests
//

import XCTest
@testable import DeepDive

final class NarratorTests: XCTestCase {
    func testStaticNarratorReturnsBriefUnchanged() async {
        let narrator = StaticNarrator()
        let result = await narrator.narrate(brief: "a personagem está com medo", sanity: 30, history: [])
        XCTAssertEqual(result, "a personagem está com medo")
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
