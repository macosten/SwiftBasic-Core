//
//  SymbolMap.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/6/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

struct SymbolMap {
    
    //MARK: -- Symbol Struct
    struct Symbol {
        
        enum SymbolType { // Keeps track of what kind of value this symbol holds.
            case integer
            case double
            // Future: support for strings in symbols?
            //case string
        } // Why not just use "if (symbol) is Type"? If I did that, then the switch statements wouldn't complain about being exhaustive if I decide to add another symbol type, and it'd be tougher to update...
        
        enum SymbolError : Error { // If we try to do something with two symbols that we shouldn't, an error of this type should be thrown.
            case unsupportedType(value: Any)
            case cannotAdd(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotSubtract(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotMultiply(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotDivide(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotModulo(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotCompare(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case downcastFailed(leftSymbol: Symbol, _ desiredLeftType: SymbolType, rightSymbol: Symbol, _ desiredRightType: SymbolType)
            case generic(moreInfo: String)
        }
        
        let type: SymbolType // The variable's type.
        let value: Any // The value itself.
        // Yes, this means that a symbol will need to be recreated whenever it's mutated.
        
        init (type: SymbolType, value: Any){
            self.type = type
            self.value = value
        }
        
        init (fromString string: String) throws {
            if let intValue = Int(string) {
                self.type = .integer
                self.value = intValue
            } else if let doubleValue = Double(string){
                self.type = .double
                self.value = doubleValue
            }
            throw SymbolError.unsupportedType(value: string)
        }
        
        // I really don't like how repetitive this code is, but I suppose this is the price I'm paying for trying to have Symbols support storing multiple types.
        
        // MARK: - Symbol Operators - Add
        /// Add the values of two symbols, and return a symbol containing the sum. The values of lhs and rhs may not be of the same type.
        static func +(lhs: Symbol, rhs: Symbol) throws -> Symbol {
            // An integer symbol will be returned iff both symbols contain integers.
            if lhs.type == .integer && rhs.type == .integer {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer)
                }
                return Symbol(type: .integer, value: lVal + rVal)
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                return Symbol(type: .double, value: lVal + rVal)
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                return Symbol(type: .double, value: lVal + Double(rVal))
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                return Symbol(type: .double, value: Double(lVal) + rVal)
            }
            // If the function gets to this point, this is a problem -- the types we're trying to add can't be added (this may not always be reachable, but symbols might be expanded to add more data types in the future).
            throw SymbolError.cannotAdd(lhs: lhs, rhs: rhs)
        }
        
        // MARK: - Subrtract
        /// Subtracts the values of two symbols, and return a symbol containing the result. The values of lhs and rhs may not be of the same type.
        static func -(lhs: Symbol, rhs: Symbol) throws -> Symbol {
            // An integer symbol will be returned iff both symbols contain integers.
            if lhs.type == .integer && rhs.type == .integer {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer)
                }
                return Symbol(type: .integer, value: lVal - rVal)
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                return Symbol(type: .double, value: lVal - rVal)
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                return Symbol(type: .double, value: lVal - Double(rVal))
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                return Symbol(type: .double, value: Double(lVal) - rVal)
            }
            // If the function gets to this point, this is a problem -- the types we're trying to add can't be added (this may not always be reachable, but symbols might be expanded to add more data types in the future).
            throw SymbolError.cannotSubtract(lhs: lhs, rhs: rhs)
        }
        
        // MARK: - Multiply
        /// Multiplies the values of two symbols, and return a symbol containing the result. The values of lhs and rhs may not be of the same type.
        static func *(lhs: Symbol, rhs: Symbol) throws -> Symbol {
            // An integer symbol will be returned iff both symbols contain integers.
            if lhs.type == .integer && rhs.type == .integer {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer)
                }
                return Symbol(type: .integer, value: lVal * rVal)
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                return Symbol(type: .double, value: lVal * rVal)
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                return Symbol(type: .double, value: lVal * Double(rVal))
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                return Symbol(type: .double, value: Double(lVal) * rVal)
            }
            // If the function gets to this point, this is a problem -- the types we're trying to add can't be added (this may not always be reachable, but symbols might be expanded to add more data types in the future).
            throw SymbolError.cannotMultiply(lhs: lhs, rhs: rhs)
        }
        
        // MARK: - Divide
        /// Divides the values of two symbols, and return a symbol containing the result. The values of lhs and rhs may not be of the same type.
        static func /(lhs: Symbol, rhs: Symbol) throws -> Symbol {
            // An integer symbol will be returned iff both symbols contain integers.
            if lhs.type == .integer && rhs.type == .integer {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer)
                }
                if rVal == 0 { throw SymbolError.cannotDivide(lhs: lhs, rhs: rhs, reason: "Division by zero") }
                return Symbol(type: .integer, value: lVal / rVal)
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                if rVal == 0.0 { throw SymbolError.cannotDivide(lhs: lhs, rhs: rhs, reason: "Division by zero") }
                return Symbol(type: .double, value: lVal / rVal)
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                if rVal == 0 { throw SymbolError.cannotDivide(lhs: lhs, rhs: rhs, reason: "Division by zero") }
                return Symbol(type: .double, value: lVal / Double(rVal))
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                if rVal == 0.0 { throw SymbolError.cannotDivide(lhs: lhs, rhs: rhs, reason: "Division by zero") }
                return Symbol(type: .double, value: Double(lVal) / rVal)
            }
            // If the function gets to this point, this is a problem -- the types we're trying to add can't be added (this may not always be reachable, but symbols might be expanded to add more data types in the future).
            throw SymbolError.cannotDivide(lhs: lhs, rhs: rhs)
        }
        
        // MARK: - Modulo / Remainder
        /// Takes lhs and rhs, and returns a symbol containing either the result of lhs % rhs if both are integers, or lhs.truncatingRemainder(dividingBy: rhs). The values of lhs and rhs may not be of the same type.
        static func %(lhs: Symbol, rhs: Symbol) throws -> Symbol {
            // An integer symbol will be returned iff both symbols contain integers.
            if lhs.type == .integer && rhs.type == .integer {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer)
                }
                if rVal == 0 { throw SymbolError.cannotModulo(lhs: lhs, rhs: rhs, reason: "Division (modulo) by zero") }
                return Symbol(type: .integer, value: lVal % rVal)
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                if rVal == 0.0 { throw SymbolError.cannotModulo(lhs: lhs, rhs: rhs, reason: "Division (modulo) by zero") }
                return Symbol(type: .double, value: lVal.truncatingRemainder(dividingBy: rVal))
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                if rVal == 0 { throw SymbolError.cannotModulo(lhs: lhs, rhs: rhs, reason: "Division by zero") }
                return Symbol(type: .double, value: lVal.truncatingRemainder(dividingBy: Double(rVal)))
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                if rVal == 0.0 { throw SymbolError.cannotModulo(lhs: lhs, rhs: rhs, reason: "Division by zero") }
                return Symbol(type: .double, value: Double(lVal).truncatingRemainder(dividingBy: rVal))
            }
            // If the function gets to this point, this is a problem -- the types we're trying to add can't be added (this may not always be reachable, but symbols might be expanded to add more data types in the future).
            throw SymbolError.cannotModulo(lhs: lhs, rhs: rhs)
        }
        
        // MARK: - Equality
        static func ==(lhs: Symbol, rhs: Symbol) throws -> Bool {
            // An integer symbol will be returned iff both symbols contain integers.
            if lhs.type == .integer && rhs.type == .integer {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer)
                }
                return lVal == rVal
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                return lVal == rVal
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                return lVal == Double(rVal)
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                return Double(lVal) == rVal
            }
            // If the function gets to this point, then we're comparing types we shouldn't compare and we'll throw an error to complain about it.
            throw SymbolError.cannotCompare(lhs: lhs, rhs: rhs)
       }
        
        // MARK: - Inequality
        static func !=(lhs: Symbol, rhs: Symbol) throws -> Bool {
            if lhs.type == .integer && rhs.type == .integer {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer)
                }
                return lVal != rVal
            }
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                return lVal != rVal
            }
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                return lVal != Double(rVal)
            }
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                return Double(lVal) != rVal
            }
             throw SymbolError.cannotCompare(lhs: lhs, rhs: rhs)
        }
        
        // MARK: - Less Than
        static func <(lhs: Symbol, rhs: Symbol) throws -> Bool {
            if lhs.type == .integer && rhs.type == .integer {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer)
                }
                return lVal < rVal
            }
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                return lVal < rVal
            }
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                return lVal < Double(rVal)
            }
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                return Double(lVal) < rVal
            }
             throw SymbolError.cannotCompare(lhs: lhs, rhs: rhs)
        }
        
        // MARK: - Greater Than
        static func >(lhs: Symbol, rhs: Symbol) throws -> Bool {
            if lhs.type == .integer && rhs.type == .integer {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer)
                }
                return lVal > rVal
            }
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                return lVal > rVal
            }
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                return lVal > Double(rVal)
            }
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                return Double(lVal) > rVal
            }
             throw SymbolError.cannotCompare(lhs: lhs, rhs: rhs)
        }
        
        // MARK: - Less Than or Equal To
        static func <=(lhs: Symbol, rhs: Symbol) throws -> Bool {
            // This is less efficient, but marginally nicer to maintain and to look at... it won't be hard to optimize later on.
            return try lhs < rhs || lhs == rhs
        }
        
        // MARK: - Greater Than or Equal To
        static func >=(lhs: Symbol, rhs: Symbol) throws -> Bool { return try lhs > rhs || lhs == rhs }
        
    }
    
    // MARK: - Symbol Map
    private var map = [String : Symbol]() // [Variable Name : Corresponding Symbol]
    
    func get(symbolNamed name: String) -> Symbol? { return map[name] }
    
    /// Attempt to insert a symbol. Throws if the provided value cannot be stored in a symbol.
    mutating func insert(name: String, value: Any) throws {
        if value is Symbol { map[name] = (value as! Symbol) }
        else if value is Double { map[name] = Symbol(type: .double, value: value) }
        else if value is Int { map[name] = Symbol(type: .integer, value: value) }
        else { throw Symbol.SymbolError.unsupportedType(value: value) }
    }
    
    mutating func removeAll() { map.removeAll() }
    
}
