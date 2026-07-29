//
//  Conversation.swift
//  DeepDive
//
//  Answers to questions about *her*, not about the room. "Quem é você?" is the first thing
//  most players type and it isn't a world action — without this she either ignored it or,
//  worse, the model bent it into a movement command.
//
//  All prose is pt-BR (ADR-002 keeps narrative in Swift, declaratively).

import Foundation

enum Conversation {

    struct Topic {
        let id: String
        let aliases: [String]
        /// More than one answer so asking twice doesn't produce a photocopy.
        let answers: [String]
    }

    static let topics: [Topic] = [
        Topic(
            id: "identity",
            aliases: ["quem e voce", "quem eh voce", "quem fala", "qual seu nome", "seu nome",
                      "como voce se chama", "quem esta ai", "quem ta ai", "com quem eu falo",
                      "com quem estou falando", "quem sou eu falando", "voce quem e"],
            answers: [
                """
                eu ia dizer meu nome e ele não veio. eu sei que eu tenho um, eu sinto o formato \
                dele na boca. eu só não consigo alcançar.
                """,
                """
                de novo isso. eu tento lembrar meu nome e chega perto, mas some. é a coisa mais \
                assustadora daqui, sabia? mais que o escuro.
                """,
            ]
        ),
        Topic(
            id: "whatHappened",
            aliases: ["o que aconteceu", "o que houve", "como voce chegou", "como voce veio parar",
                      "o que te trouxe", "voce lembra de alguma coisa", "voce lembra", "se lembra",
                      "qual a ultima coisa que voce lembra", "o que voce lembra"],
            answers: [
                """
                a última coisa que eu tenho é uma estrada de terra e o barulho do motor. depois \
                disso é o chão de pedra e você. não tem nada no meio.
                """,
                """
                eu tentei montar a linha do tempo de novo e continua faltando o pedaço do meio. \
                estrada, motor, e aí já era aqui.
                """,
            ]
        ),
        Topic(
            id: "wherePlace",
            aliases: ["que lugar e esse", "onde e isso", "onde nos estamos", "voce sabe onde ta",
                      "que lugar e aquele", "o que e esse lugar", "isso e uma caverna",
                      "voce faz ideia de onde ta"],
            answers: [
                """
                eu não sei. e o pior é que não parece nenhuma coisa que eu conheça. as construções \
                aqui não obedecem — tem escada que sobe pra baixo, tem canto que não fecha.
                """,
                """
                continuo sem saber. só sei que isso aqui foi construído por alguém. e que faz \
                muito tempo que ninguém sai.
                """,
            ]
        ),
        Topic(
            id: "howLong",
            aliases: ["ha quanto tempo", "quanto tempo voce esta", "quanto tempo faz",
                      "voce esta ai ha quanto tempo", "que horas sao ai", "e dia ou noite"],
            answers: [
                """
                eu não sei dizer. eu tentei contar mas eu perco a conta. e o meu celular marca \
                sempre a mesma hora desde que eu acordei. sempre a mesma.
                """,
                """
                o relógio não anda. eu olho e é o mesmo minuto de sempre. já desisti de usar ele \
                pra me guiar.
                """,
            ]
        ),
        Topic(
            id: "hurt",
            aliases: ["voce esta ferida", "voce ta ferida", "voce se machucou", "ta sangrando",
                      "voce esta machucada", "ta doendo"],
            answers: [
                """
                acho que não. tenho um galo atrás da cabeça e as mãos ralhadas, mas eu consigo \
                andar. tá tudo funcionando.
                """,
                """
                fora a cabeça latejando, tá tudo no lugar. por enquanto.
                """,
            ]
        ),
        Topic(
            id: "alone",
            aliases: ["tem mais alguem", "voce esta sozinha", "voce ta sozinha", "tem alguem com voce",
                      "viu alguem", "encontrou alguem", "tem gente ai"],
            answers: [
                """
                eu não vi ninguém. mas eu também não me sinto sozinha, e essas duas coisas juntas \
                são horríveis.
                """,
                """
                ninguém apareceu. só que de vez em quando eu tenho certeza de que alguma coisa \
                acabou de sair do meu campo de visão.
                """,
            ]
        ),
        Topic(
            id: "whoAmI",
            aliases: ["voce sabe quem eu sou", "voce me conhece", "voce sabe com quem ta falando",
                      "por que voce me mandou mensagem", "por que eu"],
            answers: [
                """
                não faço ideia de quem você é. eu só peguei o celular e mandei mensagem pro \
                primeiro número que apareceu. você foi quem respondeu. isso já é tudo pra mim.
                """,
                """
                eu não sei quem você é e sinceramente não importa. você respondeu. ninguém mais \
                respondeu.
                """,
            ]
        ),
    ]

    /// Finds the topic a question is about, if any.
    static func topic(matching text: String) -> Topic? {
        let padded = " \(text.folded) "
        return topics.first { topic in
            topic.aliases.contains { padded.contains(" \($0.folded) ") || text.folded.contains($0.folded) }
        }
    }

    /// When she's asked something personal that has no authored answer.
    static let deflections = [
        "eu queria saber. eu tô tentando entender isso aqui tanto quanto você.",
        "não sei responder isso. minha cabeça tá uma bagunça desde que eu acordei.",
        "eu não tenho essa resposta. me pergunta outra coisa, ou me diz o que fazer.",
    ]
}
