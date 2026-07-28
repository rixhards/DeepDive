//
//  ActionResolver.swift
//  DeepDive
//
//  The deterministic core: takes an attempted action plus the world, decides what actually
//  happens, and mutates the world. The AI never reaches this decision (ADR-002).
//
//  Failure here always stays in fiction — she reports that she tried and couldn't, rather
//  than the game reporting that it didn't understand.

import Foundation

struct ActionResolver {

    func resolve(_ action: PlayerAction, world: inout World) -> Outcome {
        // Being cruel to her costs sanity wherever it happens.
        if action.isHostile {
            world.adjustSanity(by: -4)
            if world.isOver { return endingOutcome(for: world) }
        }

        let outcome: Outcome
        switch action.verb {
        case .look: outcome = resolveLook(world: &world)
        case .examine: outcome = resolveExamine(action.target, world: &world)
        case .take: outcome = resolveTake(action.target, world: &world)
        case .use: outcome = resolveUse(action, world: &world)
        case .go: outcome = resolveGo(action.target, world: &world)
        case .wait: outcome = resolveWait(world: &world)
        case .talk: outcome = resolveTalk(action.isHostile, world: &world)
        case .inventory: outcome = resolveInventory(world: world)
        case .unknown: outcome = resolveUnknown(world: world)
        }

        // An ending reached mid-resolution replaces whatever was about to be said — unless the
        // branch that triggered it already told that story itself, in which case only the
        // silent phase is attached.
        if world.isOver {
            guard outcome.narratesEnding else { return endingOutcome(for: world) }
            var narrated = outcome
            narrated.silentTurns = world.ending == .taken ? 3 : 0
            return narrated
        }
        return outcome
    }

    /// The message for arriving somewhere — used by the view model when a run starts.
    func arrival(at id: PlaceID, world: inout World) -> Outcome {
        let place = WorldMap.place(id)
        let firstTime = !world.visited.contains(id)
        world.visited.insert(id)
        return Outcome(firstTime ? place.arrival : place.revisit)
    }

    // MARK: - Looking

    private func resolveLook(world: inout World) -> Outcome {
        let place = WorldMap.place(world.place)
        var facts = [place.overview]
        let loose = place.items.filter { !world.has($0) }
        if !loose.isEmpty {
            facts.append("tem \(loose.map(\.name).joined(separator: " e ")) aqui.")
        }
        return Outcome(facts.joined(separator: " "))
    }

    private func resolveExamine(_ target: String?, world: inout World) -> Outcome {
        guard let target, !target.isEmpty else { return resolveLook(world: &world) }
        let place = WorldMap.place(world.place)

        if let feature = place.feature(matching: target) {
            // Reading the symbols too closely is the one examine that costs her something.
            if feature.id == "simbolos" {
                world.adjustSanity(by: -3)
            }
            if feature.id == "corredor" {
                world.flags.insert(.sawCorridorHint)
            }
            return Outcome(feature.detail)
        }

        if let item = matchItem(target), world.has(item) {
            return Outcome(item.detail)
        }

        return Outcome("eu procurei e não tem nada assim aqui, não.")
    }

    // MARK: - Items

    private func resolveTake(_ target: String?, world: inout World) -> Outcome {
        guard let target, let item = matchItem(target) else {
            return Outcome("pegar o quê? eu não tô vendo isso aqui.")
        }
        if world.has(item) {
            return Outcome("isso já tá comigo.")
        }
        let place = WorldMap.place(world.place)
        guard place.items.contains(item) else {
            return Outcome("não tem \(item.name) aqui pra eu pegar.")
        }
        world.inventory.insert(item)
        return Outcome("peguei. tô com \(item.name) agora.")
    }

    private func resolveInventory(world: World) -> Outcome {
        let carried = ItemID.allCases.filter { world.has($0) }
        guard !carried.isEmpty else {
            return Outcome("eu não tô com nada. só a roupa do corpo.")
        }
        let list = carried.map(\.name).joined(separator: ", ")
        let lamp = world.has(.lamp)
            ? (world.has(.lampLit) ? " o lampião tá aceso." : " o lampião tá apagado.")
            : ""
        return Outcome("tô com \(list).\(lamp)")
    }

    // MARK: - Using things

    private func resolveUse(_ action: PlayerAction, world: inout World) -> Outcome {
        let target = action.target ?? ""
        let instrument = action.instrument.flatMap(matchItem)

        // Using something she doesn't have is refused before anything else is considered.
        if let instrument, !world.has(instrument) {
            if instrument == .knife, world.has(.knifeBroken) {
                return Outcome("a faca quebrou, lembra? não tenho mais.")
            }
            return Outcome("eu não tô com isso.")
        }

        // The lamp is a switch, not a tool, when nothing else is named.
        if let lampAction = resolveLampToggle(target: target, instrument: action.instrument, world: &world) {
            return lampAction
        }

        switch (world.place, instrument) {

        // --- Sala do feno ---
        case (.hayRoom, _) where target.matchesAlias("feno") || target.matchesAlias("palha"):
            return resolveHay(instrument: instrument, world: &world)

        // --- Trifurcação ---
        case (.trifurcacao, _) where target.matchesAlias("porta de madeira") || target.matchesAlias("madeira"):
            if world.has(.knockedWoodDoor) {
                return Outcome("já bati. dessa vez não respondeu nada.")
            }
            world.flags.insert(.knockedWoodDoor)
            world.adjustSanity(by: -4)
            return Outcome("""
            bati e alguma coisa bateu de volta, do outro lado. eu quase larguei tudo e corri. \
            mas depois eu ouvi uma coisa se arrastando pra longe da porta.
            """)

        case (.trifurcacao, .knife) where target.matchesAlias("porta de ferro") || target.matchesAlias("fechadura"):
            world.inventory.remove(.knife)
            world.flags.insert(.knifeBroken)
            return Outcome("""
            eu consegui encaixar a lâmina na fechadura, mas ela quebrou assim que eu forcei. \
            perdi a faca e a porta continua trancada.
            """)

        case (.trifurcacao, .key) where target.matchesAlias("porta de ferro") || target.matchesAlias("fechadura"):
            return resolveGo("porta de ferro", world: &world)

        case (.trifurcacao, nil) where target.matchesAlias("porta de ferro") || target.matchesAlias("fechadura"):
            // She reaches for the key herself if she has it — the player shouldn't have to
            // name the tool she's obviously carrying.
            return resolveGo("porta de ferro", world: &world)

        case (.trifurcacao, nil) where target.matchesAlias("corredor"):
            return resolveGo("corredor", world: &world)

        default:
            break
        }

        // Touching the scenery: always answers, and always costs a little.
        if let feature = WorldMap.place(world.place).feature(matching: target) {
            world.adjustSanity(by: -2)
            return Outcome("""
            encostei. \(feature.id == "agua" ? "a água tá morna, morna demais" : "a superfície tá viscosa") \
            e eu juro que reagiu ao meu toque. eu tirei a mão na hora.
            """)
        }

        return Outcome("eu tentei, mas não deu em nada.")
    }

    private func resolveLampToggle(target: String, instrument: String?, world: inout World) -> Outcome? {
        let mentionsLamp = ItemID.lamp.aliases.contains { target.matchesAlias($0) }
            || (instrument.map { text in ItemID.lamp.aliases.contains { text.matchesAlias($0) } } ?? false)
        guard mentionsLamp, world.has(.lamp) else { return nil }

        // Only treat it as a toggle when no other object is named as the target.
        let targetsSomethingElse = WorldMap.place(world.place).feature(matching: target) != nil
        guard !targetsSomethingElse || target.isEmpty else { return nil }

        if world.has(.lampLit) {
            world.flags.remove(.lampLit)
            return Outcome("apaguei o lampião. ficou bem mais escuro, mas economiza o óleo.")
        }
        world.flags.insert(.lampLit)
        return Outcome("acendi o lampião. a luz é fraca, mas já dá pra enxergar alguma coisa.")
    }

    private func resolveHay(instrument: ItemID?, world: inout World) -> Outcome {
        if world.has(.key) {
            return Outcome("já revirei esse feno. não tem mais nada aí além do cheiro.")
        }

        switch instrument {
        case .knife:
            world.inventory.remove(.knife)
            world.inventory.insert(.key)
            world.flags.insert(.knifeBroken)
            return Outcome("""
            usei a faca pra afastar a palha em vez da mão. tem uma chave aqui no fundo! peguei. \
            só que a lâmina ficou presa em alguma coisa lá embaixo e quebrou quando eu puxei.
            """)

        case .lamp:
            world.ending = .taken
            return Outcome(
                "joguei o lampião no feno. pegou fogo muito mais rápido do que eu esperava.",
                beats: [
                    "a porta bateu sozinha atrás de mim. eu não consigo abrir",
                    "a fumaça tá tomando tudo, arde demais, eu não enxergo",
                    "não, para, eu não consigo respi"
                ],
                raw: true,
                narratesEnding: true
            )

        default:
            world.inventory.insert(.key)
            world.adjustSanity(by: -8)
            return Outcome("""
            enfiei a mão no feno. achei uma chave! mas tinha alguma coisa aí dentro, alguma coisa \
            que se mexeu e arranhou meus dedos. eu tirei a mão com a chave e não olhei pra trás.
            """)
        }
    }

    // MARK: - Moving

    private func resolveGo(_ target: String?, world: inout World) -> Outcome {
        guard let target, !target.isEmpty else {
            return Outcome("ir pra onde? me diz a direção.")
        }
        let place = WorldMap.place(world.place)

        // The water is a place she can walk into, not a room she can stand in.
        if world.place == .salao, ["água", "agua", "lago", "rio", "riacho"].contains(where: { target.matchesAlias($0) }) {
            world.ending = .taken
            return Outcome(
                "tá bem, vou pela água. tá fria mas é rasa aqui na borda.",
                beats: [
                    "peraí. tem alguma coisa se mexendo aqui, mais pro fundo",
                    "não é peixe. é grande e não devia se mover desse jeito",
                    "ai meu deus, aquilo não tem uma forma certa, eu não consigo desc",
                    "para de olhar pra mim assim, PARA—"
                ],
                raw: true,
                narratesEnding: true
            )
        }

        // The corridor's outcome depends on whether she carries light into it.
        if world.place == .trifurcacao, target.matchesAlias("corredor") {
            if world.has(.lampLit) {
                world.ending = .taken
                return Outcome(
                    "tô entrando no corredor. o lampião ajuda um pouco.",
                    beats: [
                        "já faz um tempão que eu ando e isso não chega no fim",
                        "tem um som vindo lá da frente. tipo respiração, mas errada",
                        "eu tentei voltar e o corredor continua exatamente igual",
                        "agora vem dos dois lados",
                        "não consigo tapar os ouvidos o suficiente",
                        "o lampião piscou. acabou o óleo"
                    ],
                    raw: true,
                    narratesEnding: true
                )
            }
            world.adjustSanity(by: -2)
            world.place = .pastIronDoor
            world.visited.insert(.pastIronDoor)
            return Outcome("""
            entrei no escuro mesmo, me apoiando na parede. andei um tempo sem ver nada, só o som \
            do vento. e aí o corredor acabou — eu saí do outro lado da porta de ferro.
            """)
        }

        guard let exit = place.exit(matching: target) else {
            return Outcome("não tem caminho nenhum por aí. eu já procurei.")
        }
        if let requires = exit.requires, !requires(world) {
            return Outcome(exit.blocked ?? "não consigo passar por aí.")
        }

        world.adjustSanity(by: exit.sanityDelta)
        if world.isOver { return endingOutcome(for: world) }

        world.place = exit.destination
        let firstTime = !world.visited.contains(exit.destination)
        world.visited.insert(exit.destination)

        if exit.destination == .pastIronDoor {
            world.ending = .escape
            return endingOutcome(for: world)
        }
        return Outcome(firstTime ? WorldMap.place(exit.destination).arrival : WorldMap.place(exit.destination).revisit)
    }

    // MARK: - Waiting and talking

    private func resolveWait(world: inout World) -> Outcome {
        if world.has(.warnedAboutWaiting) {
            world.adjustSanity(by: -12)
            world.ending = .taken
            return endingOutcome(for: world)
        }
        world.flags.insert(.warnedAboutWaiting)
        return Outcome("""
        esperar pelo quê? tem alguma coisa ecoando lá em cima, nas goteiras, e o som tá \
        descendo. eu não posso ficar parada aqui.
        """)
    }

    private func resolveTalk(_ hostile: Bool, world: inout World) -> Outcome {
        if hostile {
            return Outcome("não precisa falar assim comigo. eu tô fazendo o que dá.")
        }
        world.adjustSanity(by: 3)
        if world.isOver { return endingOutcome(for: world) }

        switch world.sanity {
        case 70...:
            return Outcome("tô inteira. com medo, mas inteira. você perguntar já ajuda um pouco.")
        case 40..<70:
            return Outcome("não sei se eu tô bem. mas eu ainda tô aqui, e você também. isso já é alguma coisa.")
        default:
            return Outcome("não. eu não tô bem. mas continua falando comigo, por favor. quando você fala eu lembro de onde eu vim.")
        }
    }

    private func resolveUnknown(world: World) -> Outcome {
        Outcome("eu não sei como fazer isso aqui. o que você quer que eu tente?")
    }

    // MARK: - Endings

    private func endingOutcome(for world: World) -> Outcome {
        switch world.ending {
        case .surrender:
            return Outcome(WorldMap.surrenderText, raw: true)
        case .taken:
            return Outcome(WorldMap.takenText, raw: true, silentTurns: 3)
        case .escape:
            return Outcome(WorldMap.escapeText)
        case nil:
            return Outcome("")
        }
    }

    // MARK: - Matching

    private func matchItem(_ text: String) -> ItemID? {
        ItemID.allCases.first { item in
            item.aliases.contains { text.matchesAlias($0) }
        }
    }
}
