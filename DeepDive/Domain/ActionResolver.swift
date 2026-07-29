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
        world.turns += 1

        // She asked something and is waiting at the edge of it. Answer first.
        if let pending = world.pending {
            world.pending = nil
            switch action.verb {
            case .yes:
                return commit(pending, world: &world)
            case .no:
                return Outcome(pending.refusal)
            default:
                // Neither yes nor no — she takes the new instruction and drops the idea.
                break
            }
        }

        // Being cruel to her costs sanity wherever it happens.
        if action.isHostile {
            world.adjustSanity(by: -4)
            if world.isOver { return endingOutcome(for: world) }
        }

        let outcome: Outcome
        switch action.verb {
        case .look: outcome = resolveLook(world: &world)
        case .examine: outcome = resolveExamine(action.target, world: &world)
        case .take: outcome = resolveTake(action, world: &world)
        case .use: outcome = resolveUse(action, world: &world)
        case .go: outcome = resolveGo(action.target, world: &world)
        case .wait: outcome = resolveWait(world: &world)
        case .talk: outcome = resolveTalk(action.isHostile, world: &world)
        case .ask: outcome = resolveAsk(action, world: &world)
        case .inventory: outcome = resolveInventory(world: world)
        case .listen: outcome = resolveListen(world: &world)
        case .smell: outcome = Outcome(WorldMap.place(world.place).smell)
        case .shout: outcome = resolveShout(world: &world)
        case .hide: outcome = resolveHide(world: &world)
        case .rest: outcome = resolveRest(world: &world)
        case .yes, .no:
            // Nothing was pending — she has no idea what she's agreeing to.
            outcome = Outcome(pick([
                "sim o quê? me diz o que você quer que eu faça.",
                "eu não perguntei nada. o que é pra eu fazer?",
                "hã? desculpa, eu não tô entendendo o que você quer.",
            ], world))
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
        guard firstTime else { return Outcome(place.revisit) }
        return Outcome(place.arrival, beats: place.arrivalBeats)
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
            // The carvings are the one thing that takes more from her every time she looks.
            if feature.id == "simbolos" {
                return readSymbols(world: &world)
            }
            switch feature.id {
            case "corredor": world.flags.insert(.sawCorridorHint)
            case "luz": world.flags.insert(.sawFalseLight)
            case "musica":
                world.flags.insert(.heardTheMusic)
                world.adjustSanity(by: -6)
            case "ceu":
                // Realising the stars are wrong is worse than anything in the dark.
                world.adjustSanity(by: -5)
            default: break
            }
            return Outcome(feature.detail)
        }

        if let item = matchItem(target), world.has(item) {
            return Outcome(item.detail)
        }

        return Outcome(pick([
            "eu procurei e não tem nada assim aqui, não.",
            "não tem nada disso aqui. eu olhei bem.",
            "isso aí eu não tô vendo em lugar nenhum daqui.",
        ], world))
    }

    /// Each reading costs more than the last. The fifth is the surrender ending — she doesn't
    /// break from what the city does to her, she breaks from finally being able to read it.
    private func readSymbols(world: inout World) -> Outcome {
        let index = world.symbolReadings
        world.symbolReadings += 1

        guard index < WorldMap.symbolReadings.count else {
            world.ending = .surrender
            return Outcome(WorldMap.symbolFinalReading)
        }

        world.adjustSanity(by: [-4, -8, -13, -18][index])
        return Outcome(WorldMap.symbolReadings[index])
    }

    // MARK: - Items

    private func resolveTake(_ action: PlayerAction, world: inout World) -> Outcome {
        guard let target = action.target, let item = matchItem(target) else {
            return Outcome("pegar o quê? eu não tô vendo isso aqui.")
        }

        // "pega o disco com a faca" reads as taking, but it's the same careful act as using
        // the knife on the water — route it to the one rule that knows the cost.
        if world.place == .cisterna, item == .seal {
            return resolveSeal(instrument: action.instrument.flatMap(matchItem), world: &world)
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
            if !world.has(.knockedWoodDoor) {
                // Opening it blind is fatal, so she stops with her hand on it and asks.
                world.pending = .woodDoorUnknocked
                return Outcome(PendingChoice.woodDoorUnknocked.question)
            }
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

        // --- Cisterna: fishing the seal out of black water ---
        case (.cisterna, _) where target.matchesAlias("disco") || target.matchesAlias("selo")
            || target.matchesAlias("água") || target.matchesAlias("agua"):
            return resolveSeal(instrument: instrument, world: &world)

        // --- Coroa: the way out ---
        case (.coroa, .seal) where target.matchesAlias("porta") || target.matchesAlias("encaixe"):
            world.ending = .escape
            return Outcome(WorldMap.escapeText, narratesEnding: true)

        case (.coroa, nil) where target.matchesAlias("porta") || target.matchesAlias("encaixe"):
            if world.has(.seal) {
                world.ending = .escape
                return Outcome(WorldMap.escapeText, narratesEnding: true)
            }
            return Outcome("""
            empurrei, bati, procurei alguma beirada pra puxar. nada. essa porta só abre com o \
            que falta no encaixe.
            """)

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
            world.pending = .burnHay
            return Outcome(PendingChoice.burnHay.question)

        default:
            world.inventory.insert(.key)
            world.adjustSanity(by: -8)
            return Outcome("""
            enfiei a mão no feno. achei uma chave! mas tinha alguma coisa aí dentro, alguma coisa \
            que se mexeu e arranhou meus dedos. eu tirei a mão com a chave e não olhei pra trás.
            """)
        }
    }

    /// The knife keeps her arm out of the water. Two rooms want that knife and she only has
    /// one — spending it on the hay is what makes this hurt.
    private func resolveSeal(instrument: ItemID?, world: inout World) -> Outcome {
        if world.has(.seal) {
            return Outcome("já tô com o disco. não vou enfiar a mão aí de novo.")
        }

        if instrument == .knife {
            world.inventory.insert(.seal)
            return Outcome("""
            usei a faca pra enganchar o disco e puxar sem encostar na água. veio fácil. o som \
            debaixo d'água parou no exato segundo em que eu tirei ele — e depois voltou.
            """)
        }

        world.inventory.insert(.seal)
        world.adjustSanity(by: -12)
        return Outcome("""
        enfiei o braço na água preta e peguei o disco. mas enquanto eu puxava, alguma coisa \
        encostou na minha mão. devagar. do jeito que a gente encosta numa coisa pra ver o que é.
        """)
    }

    // MARK: - Moving

    private func resolveGo(_ target: String?, world: inout World) -> Outcome {
        guard let target, !target.isEmpty else {
            return Outcome(pick([
                "ir pra onde? me diz a direção.",
                "seguir por onde? eu não sei pra que lado você quer que eu vá.",
                "pra onde? daqui tem mais de um caminho.",
            ], world))
        }
        let place = WorldMap.place(world.place)

        // The water is a place she can walk into, not a room she can stand in. She stops at
        // the edge and asks first — a death should always be something the player confirmed.
        if world.place == .salao, ["água", "agua", "lago", "rio", "riacho"].contains(where: { target.matchesAlias($0) }) {
            world.pending = .enterWater
            return Outcome(PendingChoice.enterWater.question)
        }

        // The cistern water is not a route, it's a way to die — so she asks.
        if world.place == .cisterna, ["água", "agua", "nadar", "nada", "mergulha", "mergulhar"].contains(where: { target.matchesAlias($0) }) {
            world.pending = .swimCistern
            return Outcome(PendingChoice.swimCistern.question)
        }

        // The corridor's outcome depends on whether she carries light into it.
        if world.place == .trifurcacao, target.matchesAlias("corredor") {
            if world.has(.lampLit) {
                world.pending = .corridorWithLamp
                return Outcome(PendingChoice.corridorWithLamp.question)
            }
            world.adjustSanity(by: -2)
            world.place = .escadaria
            let first = !world.visited.contains(.escadaria)
            world.visited.insert(.escadaria)
            return Outcome("""
            entrei no escuro mesmo, me apoiando na parede. andei um tempo sem ver nada, só o som \
            do vento. e aí o corredor acabou — eu saí do outro lado da porta de ferro.
            """, beats: [first ? WorldMap.escadaria.arrival : WorldMap.escadaria.revisit])
        }

        guard let exit = place.exit(matching: target) else {
            return Outcome(pick([
                "não tem caminho nenhum por aí. eu já procurei.",
                "por ali não dá. não tem passagem nenhuma desse lado.",
                "eu fui até lá e não tem saída nenhuma. só parede.",
            ], world))
        }
        if let requires = exit.requires, !requires(world) {
            return Outcome(exit.blocked ?? "não consigo passar por aí.")
        }

        world.adjustSanity(by: exit.sanityDelta)
        if world.isOver { return endingOutcome(for: world) }

        world.place = exit.destination
        let firstTime = !world.visited.contains(exit.destination)
        world.visited.insert(exit.destination)

        return Outcome(firstTime ? WorldMap.place(exit.destination).arrival : WorldMap.place(exit.destination).revisit)
    }

    // MARK: - Waiting and talking

    private func resolveWait(world: inout World) -> Outcome {
        if world.has(.warnedAboutWaiting) {
            world.pending = .waitAgain
            return Outcome(PendingChoice.waitAgain.question)
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
        world.comfortsTaken += 1
        if world.comfortsTaken > 3 {
            return Outcome("você já perguntou isso. eu sei que você tá tentando ajudar, mas perguntar de novo não muda nada aqui embaixo.")
        }
        world.adjustSanity(by: 4)
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

    /// Questions about her, not about the room. She always has something to say — being asked
    /// who she is steadies her a little, which is the whole relationship this game is about.
    private func resolveAsk(_ action: PlayerAction, world: inout World) -> Outcome {
        let question = [action.target, action.instrument]
            .compactMap { $0 }
            .joined(separator: " ")

        if let topic = Conversation.topic(matching: question.isEmpty ? "quem e voce" : question) {
            world.adjustSanity(by: 1)
            return Outcome(topic.answers[world.turns % topic.answers.count])
        }
        return Outcome(Conversation.deflections[world.turns % Conversation.deflections.count])
    }

    private func resolveUnknown(world: World) -> Outcome {
        Outcome(pick([
            "eu não sei como fazer isso aqui. o que você quer que eu tente?",
            "desculpa, eu não entendi o que é pra eu fazer. tenta de outro jeito?",
            "eu fiquei parada esperando entender o que você quis dizer. me explica melhor?",
            "isso eu não sei fazer. tem outra coisa que eu possa tentar?",
        ], world))
    }

    // MARK: - Senses and small human things

    private func resolveListen(world: inout World) -> Outcome {
        let place = WorldMap.place(world.place)
        if world.place == .cisterna {
            world.flags.insert(.heardTheMusic)
            world.adjustSanity(by: -4)
        }
        return Outcome(place.sound)
    }

    private func resolveShout(world: inout World) -> Outcome {
        switch world.place {
        case .cisterna:
            world.adjustSanity(by: -6)
            return Outcome("""
            eu gritei. o eco voltou várias vezes, cada vez mais fundo... e aí um dos ecos voltou \
            com um atraso errado. eu não vou gritar de novo.
            """)
        case .trifurcacao:
            world.adjustSanity(by: -3)
            return Outcome("""
            eu chamei alto. não respondeu ninguém, mas alguma coisa atrás da porta de madeira \
            parou de se mexer no exato segundo em que eu gritei.
            """)
        default:
            world.adjustSanity(by: -2)
            return Outcome("""
            eu gritei o mais alto que deu. só voltou o meu próprio eco, e demorou demais pra voltar. \
            esse lugar é maior do que parece.
            """)
        }
    }

    private func resolveHide(world: inout World) -> Outcome {
        Outcome(pick([
            "eu me encostei atrás de uma coluna e fiquei quieta um tempo. não adianta muito — eu sinto que esse lugar sabe onde eu tô de qualquer jeito.",
            "eu me agachei num canto e prendi a respiração. não mudou nada. me esconder de quê, se eu nem sei o que tem aqui?",
        ], world))
    }

    private func resolveRest(world: inout World) -> Outcome {
        world.adjustSanity(by: 2)
        return Outcome(pick([
            "eu sentei um pouco e respirei. minhas pernas tavam tremendo e eu nem tinha percebido.",
            "eu parei, encostei na parede e contei até dez. ajudou um pouquinho.",
        ], world))
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

    // MARK: - Commit an irreversible choice she already asked about

    private func commit(_ choice: PendingChoice, world: inout World) -> Outcome {
        switch choice {
        case .enterWater:
            world.ending = .taken
            return Outcome(
                "tá bem. eu tô entrando.",
                beats: [
                    "a água tá morna. mais morna que o ar",
                    "tem alguma coisa se mexendo aqui, mais pro fundo",
                    "não é peixe. é grande e não devia se mover desse jeito",
                    "meu deus, aquilo não tem uma forma certa, eu não consigo desc",
                    "para de olhar pra mim assim, PARA—",
                ],
                raw: true,
                narratesEnding: true
            )

        case .corridorWithLamp:
            world.ending = .taken
            return Outcome(
                "tá. eu tô entrando com o lampião aceso.",
                beats: [
                    "já faz um tempão que eu ando e isso não chega no fim",
                    "tem um som vindo lá da frente. tipo respiração, mas errada",
                    "eu tentei voltar e o corredor continua exatamente igual",
                    "agora vem dos dois lados",
                    "não consigo tapar os ouvidos o suficiente",
                    "o lampião piscou. acabou o óleo",
                ],
                raw: true,
                narratesEnding: true
            )

        case .woodDoorUnknocked:
            world.ending = .taken
            return Outcome(
                "tá bom. eu vou abrir.",
                beats: [
                    "tem alguma coisa bem atrás da porta. bem atrás mesmo, encostada",
                    "ela tava esperando eu abrir",
                    "ai—",
                ],
                raw: true,
                narratesEnding: true
            )

        case .burnHay:
            world.ending = .taken
            return Outcome(
                "tá certo. joguei o lampião no feno.",
                beats: [
                    "pegou muito mais rápido do que eu esperava",
                    "a porta bateu sozinha atrás de mim. eu não consigo abrir",
                    "a fumaça tá tomando tudo, arde demais, eu não enxergo",
                    "não, para, eu não consigo respi",
                ],
                raw: true,
                narratesEnding: true
            )

        case .swimCistern:
            world.ending = .taken
            return Outcome(
                "tá. eu entrei na água.",
                beats: [
                    "tá muito mais fundo do que parecia da borda",
                    "o som parou. parou de repente e agora só tem o meu ouvido batendo",
                    "tem uma coluna passando do meu lado. eu não tô me mexendo. a COLUNA que tá passando",
                    "não é coluna",
                ],
                raw: true,
                narratesEnding: true
            )

        case .waitAgain:
            world.adjustSanity(by: -12)
            world.ending = .taken
            return endingOutcome(for: world)
        }
    }

    // MARK: - Matching

    /// Rotates through alternatives so a repeated situation doesn't produce a repeated line.
    private func pick(_ options: [String], _ world: World) -> String {
        options[world.turns % options.count]
    }

    private func matchItem(_ text: String) -> ItemID? {
        ItemID.allCases.first { item in
            item.aliases.contains { text.matchesAlias($0) }
        }
    }
}
