//
//  AnyValue.swift
//  Avenue
//
//  Created by Szymon Lorenz on 1/2/20.
//

import Foundation

struct AnyValue: Codable {
    private var int: Int?
    private var string: String?
    private var bool: Bool?
    private var double: Double?

    init(_ int: Int) {
        self.int = int
    }

    init(_ string: String) {
        self.string = string
    }

    init(_ bool: Bool) {
        self.bool = bool
    }

    init(_ double: Double) {
        self.double = double
    }

    init(from decoder: Decoder) throws {
        if let int = try? decoder.singleValueContainer().decode(Int.self) {
            self.int = int
            return
        }

        if let string = try? decoder.singleValueContainer().decode(String.self) {
            self.string = string
            return
        }

        if let bool = try? decoder.singleValueContainer().decode(Bool.self) {
            self.bool = bool
            return
        }

        if let double = try? decoder.singleValueContainer().decode(Double.self) {
            self.double = double
        }
    }


    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let anyValue = self.value() {
            if let value = anyValue as? Int {
                try container.encode(value)
                return
            }

            if let value = anyValue as? String {
                try container.encode(value)
                return
            }

            if let value = anyValue as? Bool {
                try container.encode(value)
                return
            }

            if let value = anyValue as? Double {
                try container.encode(value)
                return
            }
        }

        try container.encodeNil()
    }


    func value() -> Any? {
        return self.int ?? self.string ?? self.bool ?? self.double
    }
}
