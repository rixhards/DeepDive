//
//  ActionResolver.swift
//  DeepDive
//
//  The deterministic core: takes an attempted action plus the state, decides what actually
//  happens, and mutates the state. The AI never reaches this decision (ADR-002).
//
//  Failure here always stays in fiction — she reports that she tried and couldn't, rather
//  than the game reporting that it didn't understand.

import Foundation

nonisolated struct ActionResolver {

    func resolve(_ action: PlayerAction, state: inout GameState) -> Outcome {
        state.turn += 1

        // How the message *lands* is charged first, before anything about what it asks for.
        // It has to come before the pending branch below, or cruelty typed while she's
        // waiting for a yes would cost nothing at all. The model only classified the tone;
        // what it costs is Swift's decision.
        if let abandoned = applyTone(action.tone, state: &state) {
            return abandoned
        }
        if state.isFinished { return endingOutcome(for: state) }

        // "não entra na água" — the player named an act and forbade it. With a question open
        // this is the answer "no"; otherwise she acknowledges and stays put. Either way the
        // verb never runs. Before spec 013 negation was read as the verb `.no`, so any
        // sentence containing "não" — including every reassurance — cancelled her question.
        if action.isProhibition {
            if let pending = state.pending {
                state.pending = nil
                return Outcome(pending.refusal)
            }
            return Outcome(pick(WorldMap.prohibitionLines, state))
        }

        // She asked something and is standing at the edge of it. The question survives
        // anything that isn't an answer or a different act — losing the scene because a
        // message didn't parse was the worst thing this loop did.
        var reminder: String?
        if let pending = state.pending {
            switch action.verb {
            case .yes:
                state.pending = nil
                let outcome = commit(pending, state: &state)
                if state.isFinished, !outcome.narratesEnding { return endingOutcome(for: state) }
                return outcome

            case .no:
                state.pending = nil
                return Outcome(pending.refusal)

            case .unknown:
                // She didn't understand, but she hasn't forgotten what she asked. Verbatim
                // because the reminder is a question, and a question that gets reworded into a
                // statement is a choice the player never gets to make (spec 015).
                return Outcome(resolveUnknown(state: state).facts.joined(separator: " "),
                               beats: [pending.reminder],
                               delivery: .verbatim)

            case .look, .examine, .listen, .smell, .ask, .talk, .inventory, .greet:
                // Passive acts answer without moving her, so the question stays open.
                reminder = pending.reminder

            default:
                // Ordering the very same move again is insistence, not a new idea — she
                // already asked and the player answered by repeating themselves.
                if insists(on: pending, with: action, state: state) {
                    state.pending = nil
                    let outcome = commit(pending, state: &state)
                    if state.isFinished, !outcome.narratesEnding { return endingOutcome(for: state) }
                    return outcome
                }
                // Any other act drops the idea — this is how "voltar" saves her.
                state.pending = nil
            }
        }

        var outcome: Outcome
        switch action.verb {
        case .look: outcome = resolveLook(state: &state)
        case .examine: outcome = resolveExamine(action, state: &state)
        case .search: outcome = resolveSearch(action, state: &state)
        case .take: outcome = resolveTake(action, state: &state)
        case .use: outcome = resolveUse(action, state: &state)
        case .touch: outcome = resolveTouch(action.target, state: &state)
        case .greet: outcome = Outcome(pick(WorldMap.greetingLines, state))
        case .knock: outcome = resolveKnock(action.target, state: &state)
        case .burn: outcome = resolveBurn(action.target, state: &state)
        case .go: outcome = resolveGo(action.target, state: &state)
        case .wait: outcome = resolveWait(state: state)
        case .talk: outcome = resolveTalk(action.tone, state: &state)
        case .ask: outcome = resolveAsk(action, state: state)
        case .inventory: outcome = resolveInventory(state: state)
        case .listen: outcome = Outcome(WorldMap.beat(state.currentBeat).sound)
        case .smell: outcome = Outcome(WorldMap.beat(state.currentBeat).smell)
        case .shout: outcome = resolveShout(state: &state)
        case .hide: outcome = resolveHide(state: state)
        case .rest: outcome = resolveRest(state: state)
        case .yes, .no:
            // Nothing was pending. A hostile "não" is an answer to *her*, not to a question
            // she asked — she reacts to it instead of asking what the player means.
            outcome = action.tone == .neutral
                ? Outcome(pick([
                    "sim o quê? me diz o que você quer que eu faça.",
                    "eu não perguntei nada. o que é pra eu fazer?",
                    "hã? desculpa, eu não tô entendendo o que você quer.",
                ], state))
                : resolveTalk(action.tone, state: &state)
        case .unknown: outcome = resolveUnknown(state: state)
        }

        // An ending reached mid-resolution replaces whatever was about to be said — unless
        // the branch that triggered it already told that story itself.
        if state.isFinished, !outcome.narratesEnding {
            return endingOutcome(for: state)
        }
        // A question she is still waiting on gets restated after a passive answer. The reminder
        // travels as a beat of this outcome, so the only way to guarantee it survives is to
        // protect the whole message it rides in — the reply loses its narration, the player
        // keeps the question (spec 015).
        if let reminder {
            outcome.beats.append(reminder)
            outcome.makeVerbatim()
        }
        return outcome
    }

    /// Did the player just repeat the instruction she's asking about?
    private func insists(on pending: PendingChoice, with action: PlayerAction, state: GameState) -> Bool {
        guard let destination = pending.destination,
              let target = action.target,
              [.go, .use].contains(action.verb) else { return false }
        return WorldMap.beat(state.currentBeat).exit(matching: target)?.destination == destination
    }

    // MARK: - Tone

    /// Applies the emotional cost of the message. Distressing messages escalate, and enough
    /// of them end the run: she stops believing anyone is coming, and the city takes her.
    /// Returns the ending outcome when that happens.
    private func applyTone(_ tone: Tone, state: inout GameState) -> Outcome? {
        switch tone {
        case .neutral:
            return nil

        case .supportive:
            state.adjustSanity(by: tone.sanityDelta)
            return nil

        case .distressing:
            let cost = state.nextDistressCost
            state.distressStrikes += 1
            if state.distressStrikes >= GameState.abandonmentLimit {
                state.finish(.death)
                let script = WorldMap.abandonmentDeathScript
                return Outcome(script.opener, beats: script.beats, delivery: .script, silentTurns: 3, narratesEnding: true)
            }
            state.adjustSanity(by: cost)
            return nil
        }
    }

    /// The message for arriving somewhere — used by the view model when a run starts.
    func arrival(at id: BeatID, state: inout GameState) -> Outcome {
        let beat = WorldMap.beat(id)
        let firstTime = !state.visited.contains(id)
        state.visited.insert(id)
        // Verbatim: arrivals enumerate the ways out, and are the only floor plan the player
        // ever gets. A compressed rewrite can silently cost them the map (spec 015).
        guard firstTime else { return Outcome(beat.revisit, delivery: .verbatim) }
        return Outcome(beat.arrival, beats: beat.arrivalBeats, delivery: .verbatim)
    }

    // MARK: - Committing a choice she already asked about

    private func commit(_ choice: PendingChoice, state: inout GameState) -> Outcome {
        switch choice {
        case .enterWater:
            return death(WorldMap.waterDeathScript, at: .waterTrail, state: &state)

        case .corridorLampLit:
            return death(WorldMap.corridorDeathScript, at: .corridor, state: &state)

        case .corridorDark:
            return traverseCorridorInTheDark(state: &state)

        case .woodDoorUnknocked:
            return death(WorldMap.hayMonsterDeathScript, at: .hayRoom, state: &state)

        case .enterHayRoom:
            return move(to: .hayRoom, state: &state)

        case .takeKeyBareHands:
            state.inventory.insert(.key)
            state.adjustSanity(by: -20)
            return Outcome("""
            enfiei a mão no feno e peguei. a chave tá comigo! mas tinha alguma coisa viva lá \
            dentro. ela arranhou meus dedos e recuou pro fundo, devagar, como quem escolhe não \
            me pegar agora. eu tô tremendo.
            """)

        case .lockpickSteelDoor:
            state.inventory.remove(.knife)
            state.flags.insert(.knifeBroken)
            return Outcome("""
            encaixei a lâmina na fechadura e forcei. ela aguentou meio segundo e quebrou lá \
            dentro. perdi a faca, e a porta continua trancada igualzinho.
            """)

        case .burnHay:
            return death(WorldMap.hayFireDeathScript, at: .hayRoom, state: &state)

        case .lightLampBeforeDark:
            state.flags.insert(.lampLit)
            return Outcome(WorldMap.lampLitLine)

        case .snuffLampBeforeDark:
            state.flags.remove(.lampLit)
            return Outcome(WorldMap.lampSnuffedLine)
        }
    }

    /// Every death is the same shape: she is where it happens, the run is over, and the
    /// pre-authored script plays out verbatim — the narrator never touches a climax.
    private func death(_ script: FixedScript, at beat: BeatID, state: inout GameState) -> Outcome {
        state.currentBeat = beat
        state.visited.insert(beat)
        state.finish(.death)
        return Outcome(script.opener, beats: script.beats, delivery: .script, silentTurns: 3, narratesEnding: true)
    }

    // MARK: - Escapes (one ending, three states of mind)

    private func openSteelDoorAndEscape(state: inout GameState) -> Outcome {
        state.currentBeat = .steelDoor
        state.visited.insert(.steelDoor)
        state.finish(.escape)
        let variant = escapeScript(for: state.sanity)
        return Outcome(
            WorldMap.steelDoorOpens,
            beats: [WorldMap.steelDoor.arrival, variant.opener] + variant.beats,
            delivery: .script,
            narratesEnding: true
        )
    }

    /// The bypass: crossing the corridor in the dark comes out on the far side of the steel
    /// door. Only reachable with the lamp unlit, so there is no fuel to burn on the way.
    private func traverseCorridorInTheDark(state: inout GameState) -> Outcome {
        state.visited.insert(.corridor)
        state.currentBeat = .steelDoor
        state.visited.insert(.steelDoor)
        state.finish(.escape)
        let traversal = WorldMap.corridorDarkTraversal
        let variant = escapeScript(for: state.sanity)
        return Outcome(
            traversal.opener,
            beats: traversal.beats + [WorldMap.steelDoor.arrival, variant.opener] + variant.beats,
            delivery: .script,
            narratesEnding: true
        )
    }

    private func escapeScript(for sanity: Int) -> FixedScript {
        switch sanity {
        case 80...: WorldMap.escapeUnharmedScript
        case 40..<80: WorldMap.escapeShakenScript
        default: WorldMap.escapeRefusedScript
        }
    }

    // MARK: - Moving

    private func resolveGo(_ target: String?, state: inout GameState) -> Outcome {
        guard let target, !target.isEmpty else {
            return Outcome(pick([
                "ir pra onde? me diz a direção.",
                "seguir por onde? eu não sei pra que lado você quer que eu vá.",
                "pra onde? daqui tem mais de um caminho.",
            ], state))
        }

        // There is no "back" from the place she woke up in.
        if state.currentBeat == .salao,
           ["voltar", "volta", "trás", "atras"].contains(where: { target.matchesAlias($0) }) {
            return Outcome("voltar pra onde? foi aqui que eu acordei. não existe um antes daqui.")
        }

        // "vai pela porta" at the trifurcação is ambiguous between two very different doors.
        if state.currentBeat == .trifurcacao, target.matchesAlias("porta"),
           !targetsSteelDoor(target), !targetsWoodDoor(target) {
            return Outcome("qual porta? a de aço ou a de madeira?", delivery: .verbatim)
        }

        let beat = WorldMap.beat(state.currentBeat)
        guard let exit = beat.exit(matching: target) else {
            return Outcome(pick([
                "não tem caminho nenhum por aí. eu já procurei.",
                "por ali não dá. não tem passagem nenhuma desse lado.",
                "eu fui até lá e não tem saída nenhuma. só parede.",
            ], state))
        }
        if let requires = exit.requires, !requires(state) {
            return Outcome(exit.blocked ?? "não consigo passar por aí.")
        }
        return approach(exit.destination, state: &state)
    }

    /// Dangerous destinations raise a question instead of moving (no death without an
    /// explicit yes); the two neutral scenes are always a free walk.
    private func approach(_ destination: BeatID, state: inout GameState) -> Outcome {
        switch destination {
        case .waterTrail:
            state.pending = .enterWater
            return Outcome(PendingChoice.enterWater.question, delivery: .verbatim)

        case .corridor:
            let choice: PendingChoice = state.has(.lampLit) ? .corridorLampLit : .corridorDark
            state.pending = choice
            return Outcome(choice.question, delivery: .verbatim)

        case .hayRoom:
            let choice: PendingChoice = state.has(.knockedWoodDoor) ? .enterHayRoom : .woodDoorUnknocked
            state.pending = choice
            return Outcome(choice.question, delivery: .verbatim)

        case .steelDoor:
            return openSteelDoorAndEscape(state: &state)

        case .salao, .trifurcacao:
            return move(to: destination, state: &state)
        }
    }

    /// A plain, surviving transition. This is where lamp fuel burns: one unit per beat
    /// change while lit (`GameState.initialLampFuel` scenes in total).
    private func move(to destination: BeatID, state: inout GameState) -> Outcome {
        var lampFacts: [String] = []
        if state.has(.lampLit) {
            state.lampFuel -= 1
            if state.lampFuel <= 0 {
                state.lampFuel = 0
                state.flags.remove(.lampLit)
                state.flags.insert(.lampDead)
                lampFacts.append(WorldMap.lampDiedLine)
            } else if state.lampFuel == 1 {
                lampFacts.append(WorldMap.lampLowFuelWarning)
            }
        }

        state.currentBeat = destination
        let beat = WorldMap.beat(destination)
        let firstTime = !state.visited.contains(destination)
        state.visited.insert(destination)

        guard firstTime else {
            return Outcome(beat.revisit, beats: lampFacts, delivery: .verbatim)
        }
        return Outcome(beat.arrival, beats: beat.arrivalBeats + lampFacts, delivery: .verbatim)
    }

    // MARK: - Looking

    private func resolveLook(state: inout GameState) -> Outcome {
        let beat = WorldMap.beat(state.currentBeat)
        var facts = [beat.overview]
        let loose = beat.items.filter { !state.has($0) }
        if !loose.isEmpty {
            facts.append("tem \(loose.map(\.name).joined(separator: " e ")) aqui.")
        }
        // Verbatim: this is the player's map. The narrator was being told to keep it under
        // 320 characters and to never redescribe the environment — the exact wrong instruction
        // for the one message whose job is to describe and enumerate (spec 015).
        return Outcome(facts.joined(separator: " "), delivery: .verbatim)
    }

    private func resolveExamine(_ action: PlayerAction, state: inout GameState) -> Outcome {
        guard let target = action.target, !target.isEmpty else { return resolveLook(state: &state) }
        let beat = WorldMap.beat(state.currentBeat)

        if let feature = beat.feature(matching: target) {
            // The carvings are the one thing that takes more from her every time she looks.
            if feature.id == "simbolos" {
                return readSymbols(state: &state)
            }
            // The hay stops being interesting once the key is out of it.
            if feature.id == "feno" || feature.id == "brilho", state.has(.key) {
                return Outcome("já revirei esse feno. a chave tá comigo e não sobrou mais nada aí dentro.")
            }
            state.adjustSanity(by: feature.sanityDelta)
            return Outcome(feature.detail)
        }

        if let item = matchItem(target), state.has(item) {
            if item == .lamp {
                let fuelLine = WorldMap.lampFuelDescription(fuel: state.lampFuel, isDead: state.has(.lampDead))
                return Outcome("\(item.detail) \(fuelLine)")
            }
            return Outcome(item.detail)
        }

        return Outcome(pick([
            "eu procurei e não tem nada assim aqui, não.",
            "não tem nada disso aqui. eu olhei bem.",
            "isso aí eu não tô vendo em lugar nenhum daqui.",
        ], state))
    }

    /// Rummaging. Separate from `examine` because looking at the hay describes it and digging
    /// into it finds the key — same noun, different act (spec 013).
    private func resolveSearch(_ action: PlayerAction, state: inout GameState) -> Outcome {
        let target = action.target ?? ""
        let beat = WorldMap.beat(state.currentBeat)

        // The hay is the one place where searching has rules of its own.
        if state.currentBeat == .hayRoom,
           target.isEmpty || ["feno", "palha", "chave", "brilho", "metal"].contains(where: { target.matchesAlias($0) }) {
            if state.has(.key) {
                return Outcome("já revirei esse feno. a chave tá comigo e não sobrou mais nada aí dentro.")
            }
            return resolveHaySearch(instrument: action.instrument.flatMap(matchItem), state: &state)
        }

        // Searching nothing in particular is searching the room.
        guard !target.isEmpty else { return resolveLook(state: &state) }

        // Something that's actually here: searching for it is looking at it.
        if beat.feature(matching: target) != nil || matchItem(target).map({ state.has($0) }) == true {
            return resolveExamine(action, state: &state)
        }

        // "procura uma saída" is answered by the place itself.
        if targetsWayOut(target) { return resolveLook(state: &state) }

        return Outcome(pick(WorldMap.foundNothingLines, state))
    }

    /// Putting a hand on the scenery. Always answers, and always costs a little — but only
    /// when the player asked for it in those words. This used to be the fallback for every
    /// `use` the resolver couldn't place, which is how "não entra na água" ended with her
    /// hand in the water (spec 013).
    private func resolveTouch(_ target: String?, state: inout GameState) -> Outcome {
        let target = target ?? ""
        guard let feature = WorldMap.beat(state.currentBeat).feature(matching: target) else {
            return Outcome(pick(WorldMap.nothingToTouchLines, state))
        }
        state.adjustSanity(by: -2)
        return Outcome("""
        encostei. \(feature.id == "agua" ? "a água tá morna, morna demais" : "a superfície tá úmida e viscosa") \
        e eu juro que reagiu ao meu toque. eu tirei a mão na hora.
        """)
    }

    /// Each reading costs more than the last (the authored scale). When the scale is spent
    /// she refuses to go on — madness has to come from the rest of the place, not a loop.
    private func readSymbols(state: inout GameState) -> Outcome {
        let index = state.symbolReadings
        guard index < WorldMap.symbolReadingTexts.count else {
            return Outcome(WorldMap.symbolsExhausted)
        }
        state.symbolReadings += 1
        state.adjustSanity(by: WorldMap.symbolReadingCosts[index])
        return Outcome(WorldMap.symbolReadingTexts[index])
    }

    // MARK: - Items

    private func resolveTake(_ action: PlayerAction, state: inout GameState) -> Outcome {
        // "pega a chave" / "pega o brilho" inside the hay room is a hay search, whatever
        // words were used — that's the one take that has rules of its own.
        if state.currentBeat == .hayRoom, !state.has(.key), let target = action.target,
           ["chave", "brilho", "feno", "palha", "metal"].contains(where: { target.matchesAlias($0) }) {
            return resolveHaySearch(instrument: action.instrument.flatMap(matchItem), state: &state)
        }

        guard let target = action.target, let item = matchItem(target) else {
            return Outcome("pegar o quê? eu não tô vendo isso aqui.")
        }
        if state.has(item) {
            return Outcome("isso já tá comigo.")
        }
        let beat = WorldMap.beat(state.currentBeat)
        guard beat.items.contains(item) else {
            return Outcome("não tem \(item.name) aqui pra eu pegar.")
        }
        state.inventory.insert(item)
        if item == .knife {
            return Outcome("peguei a faca do chão. lâmina curta, meio cega — mas é bem melhor que nada.")
        }
        return Outcome("peguei. tô com \(item.name) agora.")
    }

    private func resolveInventory(state: GameState) -> Outcome {
        let carried = ItemID.allCases.filter { state.has($0) }
        guard !carried.isEmpty else {
            return Outcome("eu não tô com nada. só a roupa do corpo.", delivery: .verbatim)
        }
        let list = carried.map(\.name).joined(separator: ", ")
        var lampStatus = ""
        if state.has(.lamp) {
            if state.has(.lampDead) {
                lampStatus = " o lampião morreu, acabou o óleo."
            } else if state.has(.lampLit) {
                lampStatus = state.lampFuel <= 1
                    ? " o lampião tá aceso, mas o óleo tá no fim."
                    : " o lampião tá aceso."
            } else {
                lampStatus = " o lampião tá apagado."
            }
        }
        return Outcome("tô com \(list).\(lampStatus)", delivery: .verbatim)
    }

    // MARK: - Using things

    private func resolveUse(_ action: PlayerAction, state: inout GameState) -> Outcome {
        let target = action.target ?? ""
        let instrument = action.instrument.flatMap(matchItem)

        // Using something she doesn't have is refused before anything else is considered.
        if let instrument, !state.has(instrument) {
            return Outcome(missingItemLine(for: instrument, state: state))
        }

        // The lamp is a switch, not a tool, when nothing else is named.
        if let lampToggle = resolveLampToggle(target: target, instrument: action.instrument, state: &state) {
            return lampToggle
        }

        switch state.currentBeat {
        case .hayRoom:
            if ["feno", "palha", "chave", "brilho"].contains(where: { target.matchesAlias($0) }) {
                if state.has(.key), target.matchesAlias("chave") {
                    return Outcome("a chave tá comigo. ela é da porta de aço — é lá que eu tenho que usar.")
                }
                return resolveHaySearch(instrument: instrument, state: &state)
            }

        case .trifurcacao:
            if targetsSteelDoor(target) {
                return resolveSteelDoorUse(instrument: instrument, state: &state)
            }
            if targetsWoodDoor(target) {
                // Pushing or opening the wood door is an entry attempt.
                return approach(.hayRoom, state: &state)
            }
            if target.matchesAlias("porta") {
                return Outcome("qual porta? a de aço ou a de madeira?", delivery: .verbatim)
            }
            if target.matchesAlias("corredor") || target.matchesAlias("túnel") {
                return approach(.corridor, state: &state)
            }

        default:
            break
        }

        // Fail-safe. She could not place what she's being asked to act on, so she asks instead
        // of doing something to whatever noun happened to be in the sentence. This branch used
        // to reach for the nearest feature and charge sanity for touching it — which is how
        // "Vai pela estrada de pedra, nao entra na agua" put her hand in the water. An
        // instruction she didn't understand must never cost her anything (spec 013).
        return Outcome(pick(WorldMap.unclearActionLines, state))
    }

    /// Words for "a way out of here", which the world answers with the room itself.
    private func targetsWayOut(_ target: String) -> Bool {
        ["saida", "saída", "saidas", "saídas", "passagem", "caminho", "caminhos", "rota", "jeito de sair"]
            .contains { target.matchesAlias($0) }
    }

    private func resolveSteelDoorUse(instrument: ItemID?, state: inout GameState) -> Outcome {
        switch instrument {
        case .key:
            return openSteelDoorAndEscape(state: &state)
        case .knife:
            state.pending = .lockpickSteelDoor
            return Outcome(PendingChoice.lockpickSteelDoor.question, delivery: .verbatim)
        case .lamp, nil:
            // She reaches for the key herself if she has it — the player shouldn't have to
            // name the tool she's obviously carrying.
            if state.has(.key) {
                return openSteelDoorAndEscape(state: &state)
            }
            return Outcome("""
            eu empurrei com tudo e não cede nem um milímetro. essa porta tá trancada de \
            verdade. precisa da chave.
            """)
        }
    }

    /// The hay hides the key. The knife route spends the knife; the bare-hands route asks
    /// first, because what it costs isn't the kind of thing you take back.
    private func resolveHaySearch(instrument: ItemID?, state: inout GameState) -> Outcome {
        if state.has(.key) {
            return Outcome("já revirei esse feno. a chave tá comigo e eu não vou enfiar a mão aí de novo.")
        }

        switch instrument {
        case .knife:
            state.inventory.remove(.knife)
            state.inventory.insert(.key)
            state.flags.insert(.knifeLostInHay)
            return Outcome("""
            usei a faca pra afastar a palha em vez da mão. deu certo — a chave tá comigo! só \
            que a lâmina escorregou lá pro fundo quando eu puxei, e eu NÃO vou cavar atrás \
            dela. perdi a faca.
            """)

        case .lamp:
            state.pending = .burnHay
            return Outcome(PendingChoice.burnHay.question, delivery: .verbatim)

        case .key, nil:
            state.pending = .takeKeyBareHands
            return Outcome(PendingChoice.takeKeyBareHands.question, delivery: .verbatim)
        }
    }

    private func resolveLampToggle(target: String, instrument: String?, state: inout GameState) -> Outcome? {
        let mentionsLamp = ItemID.lamp.aliases.contains { target.matchesAlias($0) }
            || (instrument.map { text in ItemID.lamp.aliases.contains { text.matchesAlias($0) } } ?? false)
        guard mentionsLamp, state.has(.lamp) else { return nil }

        // Only treat it as a toggle when no other object is named as the target.
        let targetsSomethingElse = WorldMap.beat(state.currentBeat).feature(matching: target) != nil
        guard !targetsSomethingElse || target.isEmpty else { return nil }

        if state.has(.lampDead) {
            return Outcome(WorldMap.lampDeadRefusal)
        }

        // At the trifurcação the lamp decision is the decision — the corridor's outcome
        // hangs on it — so she double-checks before flipping it.
        if state.currentBeat == .trifurcacao {
            let choice: PendingChoice = state.has(.lampLit) ? .snuffLampBeforeDark : .lightLampBeforeDark
            state.pending = choice
            return Outcome(choice.question, delivery: .verbatim)
        }

        if state.has(.lampLit) {
            state.flags.remove(.lampLit)
            return Outcome(WorldMap.lampSnuffedLine)
        }
        state.flags.insert(.lampLit)
        return Outcome(WorldMap.lampLitLine)
    }

    // MARK: - Knocking and burning

    private func resolveKnock(_ target: String?, state: inout GameState) -> Outcome {
        let target = target ?? ""

        switch state.currentBeat {
        case .trifurcacao:
            // Knocking is what the wood door is *for*; the steel one just eats the sound.
            if targetsSteelDoor(target), !targetsWoodDoor(target) {
                return Outcome("bati no aço. o som morreu na hora, seco, como se a porta engolisse a batida.")
            }
            if state.has(.knockedWoodDoor) {
                return Outcome("já bati. dessa vez não veio nada de volta. acho que foi mesmo embora.")
            }
            state.flags.insert(.knockedWoodDoor)
            return Outcome("""
            bati três vezes na porta de madeira e recuei um passo. teve um silêncio comprido... \
            e aí uma coisa pesada se arrastou pra longe da porta, lá por dentro. agora não tem \
            mais som nenhum aí atrás.
            """)

        case .hayRoom:
            return Outcome("a porta atrás de mim já tá aberta. não tem onde bater aqui.")

        default:
            return Outcome("bater onde? não tem porta nenhuma aqui por perto.")
        }
    }

    private func resolveBurn(_ target: String?, state: inout GameState) -> Outcome {
        let target = target ?? ""

        if state.currentBeat == .hayRoom,
           target.isEmpty || target.matchesAlias("feno") || target.matchesAlias("palha") || target.matchesAlias("sala") {
            if state.has(.lampDead) {
                return Outcome("com o quê? o lampião morreu, não sobrou fogo nenhum comigo.")
            }
            state.pending = .burnHay
            return Outcome(PendingChoice.burnHay.question, delivery: .verbatim)
        }

        return Outcome("botar fogo nisso não ia ajudar em nada. e o lampião é a única luz que eu tenho.")
    }

    // MARK: - Waiting and talking

    private func resolveWait(state: GameState) -> Outcome {
        Outcome(pick([
            "eu fiquei parada um tempo. nada mudou. só as goteiras, e o frio subindo pelo chão.",
            "esperei. sabe o que é pior? me deu a sensação de que o lugar esperou junto. vamos fazer alguma coisa?",
            "tá, eu esperei um pouco. continua tudo igual — mas eu prefiro não ficar parada aqui muito tempo.",
        ], state))
    }

    private func resolveTalk(_ tone: Tone, state: inout GameState) -> Outcome {
        // Being told nobody is coming has to *sound* like it landed, and it has to sound
        // worse the second time. The third time is handled by `applyTone` — she's gone.
        if tone == .distressing {
            return switch state.distressStrikes {
            case ...1:
                Outcome("""
                por que você tá falando assim comigo? eu não tenho mais ninguém. você é a \
                única pessoa que respondeu.
                """)
            default:
                Outcome(
                    "então era isso. você tava só olhando eu me debater aqui.",
                    beats: ["eu vou parar de pedir. eu não vou mais pedir nada pra você."]
                )
            }
        }
        state.comfortsTaken += 1
        switch state.sanity {
        case 70...:
            return Outcome(pick([
                "tô inteira. com medo, mas inteira. você perguntar já ajuda um pouco.",
                "eu tô aguentando. de verdade. ajuda saber que tem alguém do outro lado.",
            ], state))
        case 40..<70:
            return Outcome(pick([
                "não sei se eu tô bem. mas eu ainda tô aqui, e você também. isso já é alguma coisa.",
                "tô cansada e com frio. mas se você continuar comigo eu continuo andando.",
            ], state))
        default:
            return Outcome(pick([
                "não. eu não tô bem. mas continua falando comigo, por favor. quando você fala eu lembro de onde eu vim.",
                "eu tô no limite. não some, tá? enquanto você responde eu ainda sou eu.",
            ], state))
        }
    }

    /// Questions about her, not about the room. She always has something to say — being
    /// asked who she is steadies her a little, which is the whole relationship this game
    /// is about.
    private func resolveAsk(_ action: PlayerAction, state: GameState) -> Outcome {
        let question = [action.target, action.instrument]
            .compactMap { $0 }
            .joined(separator: " ")

        if let topic = Conversation.topic(matching: question.isEmpty ? "quem e voce" : question) {
            return Outcome(topic.answers[state.turn % topic.answers.count])
        }
        return Outcome(Conversation.deflections[state.turn % Conversation.deflections.count])
    }

    private func resolveUnknown(state: GameState) -> Outcome {
        Outcome(pick([
            "eu não sei como fazer isso aqui. o que você quer que eu tente?",
            "desculpa, eu não entendi o que é pra eu fazer. tenta de outro jeito?",
            "eu fiquei parada esperando entender o que você quis dizer. me explica melhor?",
            "isso eu não sei fazer. tem outra coisa que eu possa tentar?",
        ], state))
    }

    // MARK: - Senses and small human things

    private func resolveShout(state: inout GameState) -> Outcome {
        switch state.currentBeat {
        case .hayRoom:
            state.adjustSanity(by: -6)
            return Outcome("""
            eu gritei e o feno inteiro se mexeu de uma vez, tipo um arrepio. parou na mesma \
            hora. eu não devia ter feito isso.
            """)
        case .trifurcacao:
            state.adjustSanity(by: -3)
            return Outcome("""
            eu chamei alto. não respondeu ninguém, mas alguma coisa atrás da porta de madeira \
            parou de se mexer no exato segundo em que eu gritei.
            """)
        default:
            state.adjustSanity(by: -2)
            return Outcome("""
            eu gritei o mais alto que deu. só voltou o meu próprio eco, e demorou demais pra \
            voltar. esse lugar é maior do que parece.
            """)
        }
    }

    private func resolveHide(state: GameState) -> Outcome {
        Outcome(pick([
            "eu me encostei atrás de uma coluna e fiquei quieta um tempo. não adianta muito — eu sinto que esse lugar sabe onde eu tô de qualquer jeito.",
            "eu me agachei num canto e prendi a respiração. não mudou nada. me esconder de quê, se eu nem sei o que tem aqui?",
        ], state))
    }

    private func resolveRest(state: GameState) -> Outcome {
        Outcome(pick([
            "eu sentei um pouco e respirei. minhas pernas tavam tremendo e eu nem tinha percebido.",
            "eu parei, encostei na parede e contei até dez. ajudou um pouquinho.",
        ], state))
    }

    // MARK: - Endings

    /// The fallback for endings that arrive mid-action (madness from any sanity loss).
    /// Deaths and escapes narrate themselves at the point they trigger.
    private func endingOutcome(for state: GameState) -> Outcome {
        switch state.ending {
        case .madness:
            let script = WorldMap.madnessScript
            return Outcome(script.opener, beats: script.beats, delivery: .script, narratesEnding: true)
        case .death, .escape, nil:
            return Outcome("")
        }
    }

    // MARK: - Matching

    private func targetsWoodDoor(_ target: String) -> Bool {
        ["porta de madeira", "madeira", "porta da direita"].contains { target.matchesAlias($0) }
    }

    private func targetsSteelDoor(_ target: String) -> Bool {
        ["porta de aço", "aço", "porta de ferro", "ferro", "porta de metal", "metal", "fechadura", "porta do meio"]
            .contains { target.matchesAlias($0) }
    }

    /// Rotates through alternatives so a repeated situation doesn't produce a repeated line.
    private func pick(_ options: [String], _ state: GameState) -> String {
        options[state.turn % options.count]
    }

    private func matchItem(_ text: String) -> ItemID? {
        ItemID.allCases.first { item in
            item.aliases.contains { text.matchesAlias($0) }
        }
    }

    private func missingItemLine(for item: ItemID, state: GameState) -> String {
        if item == .knife, state.has(.knifeBroken) {
            return "a faca quebrou na fechadura, lembra? não tenho mais."
        }
        if item == .knife, state.has(.knifeLostInHay) {
            return "a faca ficou perdida no feno. não tenho mais ela."
        }
        if item == .key {
            return "eu ainda não tenho chave nenhuma."
        }
        return "eu não tô com isso."
    }
}
