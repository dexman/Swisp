//
//  builtins.swift
//  Swisp
//
//  Created by Arthur Dexter on 10/25/16.
//  Copyright © 2016 LivingSocial. All rights reserved.
//

import Foundation

func add(_ args: [Expression]) throws -> Expression {
    let numbers = try asNumbers(args)
    let result = numbers.reduce(Decimal(0), +)
    return .number(value: result)
}

func subtract(_ args: [Expression]) throws -> Expression {
    var numbers = try asNumbers(args)
    if numbers.count == 1 {
        numbers.insert(Decimal(0), at: 0)
    }
    guard let initialValue = numbers.first else {
        throw SwispError.arityError(description: "Expected at least 1 argument")
    }
    let remainingValues = numbers.suffix(from: 1)
    let result = remainingValues.reduce(initialValue, -)
    return .number(value: result)
}

func multiply(_ args: [Expression]) throws -> Expression {
    let numbers = try asNumbers(args)
    let result = numbers.reduce(Decimal(1), *)
    return .number(value: result)
}

func divide(_ args: [Expression]) throws -> Expression {
    var numbers = try asNumbers(args)
    if numbers.count == 1 {
        numbers.insert(Decimal(1), at: 0)
    }
    guard let initialValue = numbers.first else {
        throw SwispError.arityError(description: "Expected at least 1 argument")
    }
    let remainingValues = numbers.suffix(from: 1)
    let result = remainingValues.reduce(initialValue, /)
    return .number(value: result)
}

func comparisonProc(_ comparison: @escaping (Decimal, Decimal) -> Bool) -> ([Expression]) throws -> Expression {
    return { args in
        let numbers = try asNumbers(args)
        if numbers.count < 2 {
            throw SwispError.arityError(description: "Expected at least 2 arguments")
        }

        let result = zip(numbers, numbers.suffix(from: 1)).map(comparison).reduce(true) { $0 && $1 }
        if result {
            return args.last!
        } else {
            return .list(value: [])
        }
    }

}

func asNumbers(_ args: [Expression]) throws -> [Decimal] {
    return try args.map { arg in
        if case .number(let value) = arg {
            return value
        }
        throw SwispError.typeError(description: "Expected a number but got \(arg)")
    }
}

func asSymbols(_ args: [Expression]) throws -> [String] {
    return try args.map { arg in
        if case .symbol(let value) = arg {
            return value
        }
        throw SwispError.typeError(description: "Expected a symbol but got \(arg)")
    }
}
