//
//  StoryCondition.swift
//  DeepDive
//

import Foundation

enum ConditionOperator: String, Codable {
    case eq
    case gte
    case lte
}

enum StateValue: Codable, Equatable {
    case bool(Bool)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else {
            self = .int(try container.decode(Int.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        }
    }
}

struct StoryCondition: Codable, Equatable {
    let variable: String
    let op: ConditionOperator
    let value: StateValue

    private enum CodingKeys: String, CodingKey {
        case variable = "var"
        case op
        case value
    }
}

struct StoryEffect: Codable, Equatable {
    enum Mode: Equatable {
        case delta(Int)
        case set(StateValue)
    }

    let variable: String
    let mode: Mode

    private enum CodingKeys: String, CodingKey {
        case variable = "var"
        case delta
        case set
    }

    init(variable: String, mode: Mode) {
        self.variable = variable
        self.mode = mode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        variable = try container.decode(String.self, forKey: .variable)
        if let deltaValue = try container.decodeIfPresent(Int.self, forKey: .delta) {
            mode = .delta(deltaValue)
        } else {
            mode = .set(try container.decode(StateValue.self, forKey: .set))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(variable, forKey: .variable)
        switch mode {
        case .delta(let amount):
            try container.encode(amount, forKey: .delta)
        case .set(let value):
            try container.encode(value, forKey: .set)
        }
    }
}
