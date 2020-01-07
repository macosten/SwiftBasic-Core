//
//  SymbolMap.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/6/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

struct SymbolMap {
    struct Symbol<T> {
        enum SymbolType { // Keeps track of what kind of value this symbol holds.
            case integer
            case double
        }
        let type: SymbolType // The variable's type.
        let value: T // The value itself.
        // Yes, this means that a symbol will need to be recreated whenever it's mutated.
    }
    
    private var map = [String : Symbol<Any>]() // [Variable Name : Corresponding Symbol]
    
    func get(symbolNamed name: String) -> Symbol<Any>? { return map[name] }
    mutating func insert<T>(name: String, value: T) {
        if value is Double { map[name] = Symbol(type: .double, value: value) }
        else if value is Int { map[name] = Symbol(type: .integer, value: value) }
        else { fatalError("Attempted to insert a symbol (named \"\(name)\" of unsupported type \(T.self). This should never happen.") }
    }
    
}
