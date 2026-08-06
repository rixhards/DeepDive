//
//  TurnRunner.swift
//  DeepDive
//
//  One player message → one or more resolved outcomes. This is where compound instructions
//  live: "pega a faca e vai pela trilha da água" is two acts in one message, and she should
//  do both instead of doing the first and waiting.
//
//  Splitting is deterministic and local (never the model's call), and the sequence stops the
//  moment she asks a question or the run ends — so a compound command can never walk her
//  past a confirmation into a death.

import Foundation

nonisolated struct TurnRunner {
    let parser: ActionParser
    private let resolver = ActionResolver()

    /// At most this many acts per message. More than three in one breath is almost always a
    /// misparse, not a plan.
    static let maxClauses = 3

    /// Verbs that answer without doing anything to the world. Two of these in a row inside one
    /// message is the same reply twice — "calma, respira, fica calma" is one gesture, not three.
    private static let conversational: Set<Verb> = [.talk, .greet, .ask]

    func run(playerText: String, state: inout GameState) async -> [Outcome] {
        let clauses = LocalActionParser.splitClauses(playerText)
        // The tone belongs to the message, not to each clause — charging it per clause would
        // make a two-part sentence twice as cruel as it read. Read once, here, from the whole
        // text, so splitting on a comma can't change how the message lands.
        let tone = LocalActionParser.messageTone(of: playerText)

        var outcomes: [Outcome] = []
        var previousVerb: Verb?

        for (index, clause) in clauses.enumerated() {
            var action = await parser.parse(playerText: clause, state: state)
            action.tone = index == 0 ? tone : .neutral

            // Don't say the same conversational thing twice in one breath.
            if action.verb == previousVerb, Self.conversational.contains(action.verb) { continue }
            previousVerb = action.verb

            let outcome = resolver.resolve(action, state: &state)
            if !outcome.isEmpty { outcomes.append(outcome) }

            // She stopped to ask something, or the run is over: nothing after this in the
            // same message gets to happen.
            if state.pending != nil || state.isFinished { break }
        }

        // A message that produced nothing at all still deserves an answer.
        if outcomes.isEmpty {
            let action = await parser.parse(playerText: playerText, state: state)
            outcomes.append(resolver.resolve(action, state: &state))
        }
        return outcomes
    }

    /// The message that opens a run (or resumes one).
    func arrival(at beat: BeatID, state: inout GameState) -> Outcome {
        resolver.arrival(at: beat, state: &state)
    }
}
