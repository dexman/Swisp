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
            let value = try eval(parse(input), env: globalEnvironment).run()
            print(value)
        } catch {
            print("swisp error: \(error)")
        }
    }
}

/// Evaluate an expression in an environment.
func eval(_ x: Expression, env: Environment) -> Trampoline<Expression> {
    do {
        switch x {
        case .symbol(let value):
            guard let result = env[value] else {
                throw SwispError.undefinedIdentifier(description: "undefined identifier \(value)")
            }
            return .result(result)
        case .number:
            return .result(x)
        case .proc:
            return .result(x)
        case .list(let value):
            switch value.first {
            case .some(.symbol("quote")):
                return .result(.list(Array(value.suffix(from: 1))))
            case .some(.symbol("if")):
                let (test, conseq, alt) = (value[1], value[2], value[3])
                if case .list(let resultValue) = try eval(test, env: env).run(), resultValue.isEmpty {
                    return .result(try eval(alt, env: env).run())
                } else {
                    return .result(try eval(conseq, env: env).run())
                }
            case .some(.symbol("define")):
                if case .symbol(let name) = value[1] {
                    env[name] = try eval(value[2], env: env).run()
                }
                return .result(value[2])
            case .some(.symbol("set!")):
                if case .symbol(let name) = value[1] {
                    env[name] = try eval(value[2], env: env).run()
                }
                throw SwispError.syntaxError(description: "Bad syntax")
            case .some(.symbol("lambda")):
                if case .list(let parameters) = value[1] {
                    return .result(.proc(.interpreted(
                        parameters: try asSymbols(parameters),
                        body: Array(value.suffix(from: 2)))))
                }
                throw SwispError.syntaxError(description: "Bad syntax")
            case .some(let procName):
                let result = try eval(procName, env: env).run()
                if case .proc(let procedure) = result {
                    let arguments = try value.suffix(from: 1).map { try eval($0, env: env).run() }
                    switch procedure {
                    case .native(let f):
                        return .result(try f(arguments))
                    case .interpreted(let parameters, let body):
                        let procEnv = Environment(parent: env, values: Dictionary(keys: parameters, values: arguments))
                        return .call { eval(body.first!, env: procEnv) }
                    }
                }
                throw SwispError.applicationError(description: "Not a procedure: \(procName)")
            default:
                throw SwispError.applicationError(description: "Not a procedure: \(value.first)")
            }
        }
    } catch {
        return .error(error)
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
        return .list(list)
    case ")":
        throw SwispError.syntaxError(description: "unexpected )")
    default:
        return atom(token)
    }
}

/// Numbers become numbers; every other token is a symbol.
func atom(_ token: String) -> Expression {
    if let number = Decimal(string: token, locale: nil), !["+", "-"].contains(token) {
        return .number(number)
    } else {
        return .symbol(token)
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
        "pi":      .number(Decimal(Double.pi)),
        "+":       .proc(.native(add)),
        "-":       .proc(.native(subtract)),
        "*":       .proc(.native(multiply)),
        "/":       .proc(.native(divide)),
        ">":       .proc(.native(comparisonProc(>))),
        "<":       .proc(.native(comparisonProc(<))),
        ">=":      .proc(.native(comparisonProc(>=))),
        "<=":      .proc(.native(comparisonProc(<=))),
        "=":       .proc(.native(comparisonProc(==))),
//        "abs":     abs,
//        "append":  op.add,
//        "apply":   apply,
//        "begin":   .proc({ (x: [Expression]) in x.last! })
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

/// Contains either the result of a procedure call, an error, or the next procedure call to make.
enum Trampoline<V> {

    case result(V)
    case error(Error)
    case call(() -> Trampoline)

    func run() throws -> V {
        var trampoline = self
        while true {
            switch trampoline {
            case .call(let proc):
                trampoline = proc()
            case .error(let error):
                throw error
            case .result(let value):
                return value
            }
        }
    }
    
}

/// Linked list of contexts for evaluations.
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

    case number(Decimal)
    case symbol(String)
    case list([Expression])
    case proc(Procedure)

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

enum Procedure {

    case native(([Expression]) throws -> Expression)
    case interpreted(parameters: [String], body: [Expression])

}

enum SwispError: Error {

    case syntaxError(description: String)
    case applicationError(description: String)
    case typeError(description: String)
    case arityError(description: String)
    case undefinedIdentifier(description: String)

}

var globalEnvironment = standardEnvironment()

repl()

