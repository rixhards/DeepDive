//
//  MockConversation.swift
//  DeepDive
//
//  Hardcoded fixture for spec 001. Spec 002/003 replace this with the game
//  engine and story.json without touching the views.
//

import Foundation

enum MockConversation {
    static let startNodeID = "start"

    static let nodes: [ConversationNode] = [
        ConversationNode(
            id: "start",
            characterText: "tem alguém aí? por favor, preciso de ajuda",
            options: [
                ConversationOption(text: "quem é você?", nextNodeID: "node_who"),
                ConversationOption(text: "onde você está?", nextNodeID: "node_where"),
            ]
        ),
        ConversationNode(
            id: "node_who",
            characterText: "não sei bem quem sou. só sei que estou presa em algum lugar.",
            options: [
                ConversationOption(text: "presa onde?", nextNodeID: "node_place"),
                ConversationOption(text: "como isso é possível?", nextNodeID: "node_joke"),
            ]
        ),
        ConversationNode(
            id: "node_where",
            characterText: "não sei. tudo aqui parece errado. tem túneis, e as paredes têm símbolos que eu nunca vi.",
            options: [
                ConversationOption(text: "continua andando", nextNodeID: "node_place"),
                ConversationOption(text: "fica onde está, não se mexe", nextNodeID: "node_stubborn"),
            ]
        ),
        ConversationNode(
            id: "node_stubborn",
            characterText: "ok. mas as luzes daqui estão piscando, não sei por quanto tempo ainda vou enxergar algo.",
            options: [
                ConversationOption(text: "então anda, rápido", nextNodeID: "node_place"),
            ]
        ),
        ConversationNode(
            id: "node_joke",
            characterText: "queria que fosse brincadeira. mas isso é real, e eu tô com medo.",
            options: [
                ConversationOption(text: "ok, vamos com calma. me conta o que você vê", nextNodeID: "node_place"),
            ]
        ),
        ConversationNode(
            id: "node_place",
            characterText: "essa cidade não devia existir. e eu não devia estar nela.",
            options: [
                ConversationOption(text: "como você sai daí?", nextNodeID: "node_end"),
                ConversationOption(text: "tem mais alguém com você?", nextNodeID: "node_who2"),
            ]
        ),
        ConversationNode(
            id: "node_who2",
            characterText: "acho que sim. ouço vozes. gente que também tentou sair. nem todo mundo conseguiu.",
            options: [
                ConversationOption(text: "e agora, o que você vê na sua frente?", nextNodeID: "node_end"),
            ]
        ),
        ConversationNode(
            id: "node_end",
            characterText: "as luzes estão apagando. eu... acho que preciso correr.",
            options: []
        ),
    ]
}
