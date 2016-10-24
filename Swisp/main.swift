//
//  main.swift
//  Swisp
//
//  Created by Arthur Dexter on 10/24/16.
//  Copyright © 2016 LivingSocial. All rights reserved.
//

import Foundation

/// A prompt-read-eval-print loop.
func repl(prompt: String = "swisp> ") {
    while true {
        do {
            print(prompt, terminator: "")
            guard let input = readLine() else { break }
            let val = try eval(parse(input), env: &globalEnvironment)
            print(val)
        } catch {
            print("swisp error: \(error)")
        }
    }
}

/// Evaluate an expression in an environment.
func eval(_ x: Expression, env: inout Environment) throws -> Expression {
    switch x {
    case .symbol(let value):
        return env[value] ?? .list(value: [])
    case .number:
        return x
    case .proc:
        return x
    case .list(let value):
        switch value.first {
        case .some(.symbol(value: "quote")):
            return .list(value: Array(value.suffix(from: 1)))
        case .some(.symbol(value: "if")):
            let (test, conseq, alt) = (value[1], value[2], value[3])
            if case .list(let resultValue) = try eval(test, env: &env), resultValue.isEmpty {
                return alt
            } else {
                return conseq
            }
        case .some(.symbol(value: "define")):
            if case .symbol(let name) = value[1] {
                env[name] = try eval(value[2], env: &env)
            }
            return value[2]
        case .some(.symbol(value: "set!")):
            if case .symbol(let name) = value[1] {
                env[name] = try eval(value[2], env: &env)
            }
            throw SwispError.syntaxError(description: "Bad syntax")
        case .some(.symbol(value: "lambda")):
            if case .list(let parameters) = value[1] {
                let parameterNames = try asSymbols(parameters)
                let body = value[2]
                let parentEnvironment = Environment(parent: env)
                return .proc(value: { args in
                    var procEnv = Environment(
                        parent: parentEnvironment,
                        values: zip(parameterNames, args).reduce([:]) { var r = $0; r[$1.0] = $1.1; return r })
                    return try eval(body, env: &procEnv)
                })
            }
            throw SwispError.syntaxError(description: "Bad syntax")
        case .some(let procName):
            if case .proc(let proc) = try eval(procName, env: &env) {
                let args = try value.suffix(from: 1).map { try eval($0, env: &env) }
                return try proc(args)
            }
            throw SwispError.applicationError(description: "Not a procedure: \(procName)")
        default:
            throw SwispError.applicationError(description: "Not a procedure: \(value.first)")
        }
    }
}

/// Read a Scheme expression from a string.
func parse(_ program: String) throws -> Expression {
    var tokens = tokenize(program)
    return try readExpression(from: &tokens)
}

/// Read an expresion from a sequence of tokens.
func readExpression(from tokens: inout [String]) throws -> Expression {
    if tokens.isEmpty {
        throw SwispError.syntaxError(description: "unexpected EOF while reading")
    }
    let token = tokens.removeFirst()
    switch token {
    case "(":
        var list: [Expression] = []
        while tokens.first != ")" {
            list.append(try readExpression(from: &tokens))
        }
        tokens.removeFirst() // remove ")"
        return .list(value: list)
    case ")":
        throw SwispError.syntaxError(description: "unexpected )")
    default:
        return atom(token)
    }
}

/// Numbers become numbers; every other token is a symbol.
func atom(_ token: String) -> Expression {
    if let number = Decimal(string: token, locale: nil), !["+", "-"].contains(token) {
        return .number(value: number)
    } else {
        return .symbol(value: token)
    }
}

/// Convert a string of characters into a list of tokens.
func tokenize(_ chars: String) -> [String] {
    return chars
        .replacingOccurrences(of: "(", with: " ( ")
        .replacingOccurrences(of: ")", with: " ) ")
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
}

/// An environment with some Scheme standard procedures.
func standardEnvironment() -> Environment {
    return Environment(values: [
        // env.update(vars(math)) # sin, cos, sqrt, pi, ...
        "pi":      .number(value: Decimal(Double.pi)),
        "+":       .proc(value: add),
        "-":       .proc(value: subtract),
        "*":       .proc(value: multiply),
        "/":       .proc(value: divide),
//        ">":       op.gt,
//        "<":       op.lt,
//        ">=":      op.ge,
//        "<=":      op.le,
//        "=":       op.eq,
//        "abs":     abs,
//        "append":  op.add,
//        "apply":   apply,
        "begin":   .proc(value: { (x: [Expression]) in x.last! })
//        "car":     lambda x: x[0],
//        "cdr":     lambda x: x[1:],
//        "cons":    lambda x,y: [x] + y,
//        "eq?":     op.is_,
//        "equal?":  op.eq,
//        "length":  len,
//        "list":    lambda *x: list(x),
//        "list?":   lambda x: isinstance(x,list),
//        "map":     map,
//        "max":     max,
//        "min":     min,
//        "not":     op.not_,
//        "null?":   lambda x: x == [],
//        "number?": lambda x: isinstance(x, Number),
//        "procedure?": callable,
//        "round":   round,
//        "symbol?": lambda x: isinstance(x, Symbol),
    ])
}

//typealias Environment = [String: Expression]

class Environment: CustomDebugStringConvertible {

    init(parent: Environment? = nil, values: [String: Expression] = [:]) {
        self.parent = parent
        self.values = values
    }

    subscript(key: String) -> Expression? {
        get {
            return values[key] ?? parent?[key]
        }
        set {
            values[key] = newValue
        }
    }

    var debugDescription: String {
        return values.debugDescription
    }

    private let parent: Environment?
    private var values: [String: Expression] = [:]

}

enum Expression: CustomDebugStringConvertible {

    case number(value: Decimal)
    case symbol(value: String)
    case list(value: [Expression])
    case proc(value: ([Expression]) throws -> Expression)

    var debugDescription: String {
        switch self {
        case .number(let value):
            return "\(value)"
        case .symbol(let value):
            return value
        case .list(let value):
            return "(" + value.map { $0.debugDescription }.joined(separator: " ") + ")"
        case .proc:
            return "proc"
        }
    }

}

enum SwispError: Error {

    case syntaxError(description: String)
    case applicationError(description: String)
    case typeError(description: String)
    case arityError(description: String)

}

var globalEnvironment = standardEnvironment()
//let program = "(begin (define r 10) (* pi (* r)))"
//do {
//    var program = "(define circle-area (lambda (r) (* pi (* r r))))"
//    print("result=\(try eval(parse(program), env: &globalEnvironment))")
//    print("env=\(globalEnvironment)")
//
//    program = "(circle-area 3)"
//    print("result=\(try eval(parse(program), env: &globalEnvironment))")
//    print("env=\(globalEnvironment)")
//} catch {
//    print("failed=\(error)")
//}
repl()

