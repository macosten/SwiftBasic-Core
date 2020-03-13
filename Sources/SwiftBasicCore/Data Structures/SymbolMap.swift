//
//  SymbolMap.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/6/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

struct SymbolMap {
    
    // Dictionaries are of the following type.
    typealias SymbolDictionary = [Symbol: Symbol] // [subscript key : stored value]
    // ...same as the SymbolMap's internal storage, but different intentions.
    
    //MARK: -- Symbol Struct
    struct Symbol: Hashable {
        
        enum SymbolType { // Keeps track of what kind of value this symbol holds.
            case integer
            case double
            case string
            case dictionary
        } // Why not just use "if (symbol) is Type"? If I did that, then the switch statements wouldn't complain about being exhaustive if I decide to add another symbol type, and it'd be tougher to update...
        
        enum SymbolError : Error { // If we try to do something with two symbols that we shouldn't, an error of this type should be thrown.
            case cannotAdd(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotSubtract(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotMultiply(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotDivide(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotModulo(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotExponentiate(base: Symbol, exponent: Symbol, reason: String? = nil)
            case cannotBitShift(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotBitwiseLogical(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case cannotCompare(lhs: Symbol, rhs: Symbol, reason: String? = nil)
            case downcastFailed(leftSymbol: Symbol, _ desiredLeftType: SymbolType, rightSymbol: Symbol, _ desiredRightType: SymbolType)
            case integerOverflow(factor0: Symbol, operation: TokenType, factor1: Symbol)
            case integerUnderflow(factor0: Symbol, operation: TokenType, factor1: Symbol)
            case unknownError(moreInfo: String)
        }
        
        let type: SymbolType // The variable's type.
        let value: AnyHashable // The value itself.
        // Yes, this means that a symbol will need to be recreated whenever it's mutated.

        // Separate initializers for each supported type here to reduce the chance I misconfigure a symbol somewhere in the codebase.
        init(_ int: Int) {
            self.type = .integer
            self.value = int
        }
        
        init(_ double: Double) {
            self.type = .double
            self.value = double
        }
        
        init(_ string: String) {
            self.type = .string
            self.value = string
        }
        
        init(_ dict: SymbolDictionary) {
            self.type = .dictionary
            self.value = dict
        }
        
        // It's not possible to get a dictionary symbol from a string.
        init (fromString string: String) {
            if let intValue = Int(string) {
                self.type = .integer
                self.value = intValue
            } else if let doubleValue = Double(string){
                self.type = .double
                self.value = doubleValue
            } else {
                self.type = .string
                self.value = string
            }
        }
        
        // For the Hashable protocol.
        func hash(into hasher: inout Hasher) { hasher.combine(value) }
        
        ///Returns this symbol's value as a String.
        func asString() throws -> String {
            switch type {
            case .integer:
                if let intValue = value as? Int { return String(intValue) }
            case .double:
                if let doubleValue = value as? Double { return String(doubleValue) }
            case .string:
                if let stringValue = value as? String { return stringValue }
            case .dictionary:
                guard let dict = value as? SymbolDictionary else { break }
                // This one's a little more involved.
                var returnValue = "[" // The opening bracket...
                returnValue += try (dict.map { (key, value) -> String in
                    var keyString = try key.asString()
                    if key.type == .string { keyString = "\"\(keyString)\"" } // Put quotes around it if it's a string
                    var valueString = try value.asString()
                    if value.type == .string { valueString = "\"\(valueString)\"" }
                    return "\(keyString) = \(valueString)" // A KV-pair string for each pair...
                    }).joined(separator: ", ") // joined by a comma and then a space...
                returnValue += "]" // ...and then a closing bracket.
                return returnValue
            }
            
           throw SymbolError.unknownError(moreInfo: "Failed to create string representation of symbol \(self) - this shouldn't happen.")
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
                let (value, didOverflow) = lVal.addingReportingOverflow(rVal)
                if didOverflow { throw SymbolError.integerOverflow(factor0: lhs, operation: .plus, factor1: rhs) }
                return Symbol(value)
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                return Symbol(lVal + rVal)
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                return Symbol(lVal + Double(rVal))
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                return Symbol(Double(lVal) + rVal)
            }
            // If either side is a string, then treat this as a string concatenation.
            else if lhs.type == .string || rhs.type == .string {
                guard let lVal = try? lhs.asString(), let rVal = try? rhs.asString() else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .string, rightSymbol: rhs, .string)
                }
                return Symbol(lVal + rVal)
            }
            
            // If the function gets to this point, this is a problem -- the types aren't compatible for this operation (this may not always be reachable, but symbols might be expanded to add more data types in the future).
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
                let (value, didOverflow) = lVal.subtractingReportingOverflow(rVal)
                if didOverflow { throw SymbolError.integerOverflow(factor0: lhs, operation: .multiply, factor1: rhs) }
                return Symbol(value)
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                return Symbol(lVal - rVal)
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                return Symbol(lVal - Double(rVal))
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                return Symbol(Double(lVal) - rVal)
            }
            // If the function gets to this point, this is a problem -- the types aren't compatible for this operation (this may not always be reachable, but symbols might be expanded to add more data types in the future).
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
                let (value, didOverflow) = lVal.multipliedReportingOverflow(by: rVal)
                if didOverflow { throw SymbolError.integerOverflow(factor0: lhs, operation: .multiply, factor1: rhs) }
                return Symbol(value)
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                return Symbol(lVal * rVal)
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                return Symbol(lVal * Double(rVal))
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                return Symbol(Double(lVal) * rVal)
            }
            // If the left side is a string and the right side is an integer, then return the string repeated a number of times equal to the right side's value.
            else if lhs.type == .string && rhs.type == .integer {
                guard let lVal = lhs.value as? String, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .string, rightSymbol: rhs, .integer)
                }
                // If rVal is negative, we can't multiply.
                if rVal < 0 { throw SymbolError.cannotMultiply(lhs: lhs, rhs: rhs) }
                return Symbol(String(repeating: lVal, count: rVal))
            }
            // If the right side is a string and the left side is an integer, then return the string repeated a number of times equal to the left side's value.
            else if lhs.type == .integer && rhs.type == .string {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? String else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .string)
                }
                // If lVal is negative, we can't multiply.
                if lVal < 0 { throw SymbolError.cannotMultiply(lhs: lhs, rhs: rhs) }
                return Symbol(String(repeating: rVal, count: lVal))
            }
            
            // If the function gets to this point, this is a problem -- the types aren't compatible for this operation (this may not always be reachable, but symbols might be expanded to add more data types in the future).
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
                let (value, didOverflow) = lVal.dividedReportingOverflow(by: rVal)
                if didOverflow { throw SymbolError.integerOverflow(factor0: lhs, operation: .multiply, factor1: rhs) }
                return Symbol(value)
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                if rVal == 0.0 { throw SymbolError.cannotDivide(lhs: lhs, rhs: rhs, reason: "Division by zero") }
                return Symbol(lVal / rVal)
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                if rVal == 0 { throw SymbolError.cannotDivide(lhs: lhs, rhs: rhs, reason: "Division by zero") }
                return Symbol(lVal / Double(rVal))
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                if rVal == 0.0 { throw SymbolError.cannotDivide(lhs: lhs, rhs: rhs, reason: "Division by zero") }
                return Symbol(Double(lVal) / rVal)
            }
            // If the function gets to this point, this is a problem -- the types aren't compatible for this operation (this may not always be reachable, but symbols might be expanded to add more data types in the future).
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
                let (value, didOverflow) = lVal.remainderReportingOverflow(dividingBy: rVal)
                if didOverflow {  }
                return Symbol(value)
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .double)
                }
                if rVal == 0.0 { throw SymbolError.cannotModulo(lhs: lhs, rhs: rhs, reason: "Division (modulo) by zero") }
                return Symbol(lVal.truncatingRemainder(dividingBy: rVal))
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .double, rightSymbol: rhs, .integer)
                }
                if rVal == 0 { throw SymbolError.cannotModulo(lhs: lhs, rhs: rhs, reason: "Division by zero") }
                return Symbol(lVal.truncatingRemainder(dividingBy: Double(rVal)))
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .double)
                }
                if rVal == 0.0 { throw SymbolError.cannotModulo(lhs: lhs, rhs: rhs, reason: "Division by zero") }
                return Symbol(Double(lVal).truncatingRemainder(dividingBy: rVal))
            }
            // If the function gets to this point, this is a problem -- the types aren't compatible for this operation (this may not always be reachable, but symbols might be expanded to add more data types in the future).
            throw SymbolError.cannotModulo(lhs: lhs, rhs: rhs)
        }
        
        // MARK: - Power / Exponentiation
        static func **(base: Symbol, exponent: Symbol) throws -> Symbol {
           // For the same reason pow() isn't available for Integers, this function will always return a symbol with a Double. It gets pretty complicated pretty quickly otherwise.
            if base.type == .integer && exponent.type == .integer {
                guard let lVal = base.value as? Int, let rVal = exponent.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: base, .integer, rightSymbol: exponent, .integer)
                }
                return Symbol(lVal ** rVal)
            }
                
            else if base.type == .double && exponent.type == .double {
                guard let lVal = base.value as? Double, let rVal = exponent.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: base, .double, rightSymbol: exponent, .double)
                }
                return Symbol(lVal ** rVal)
            }
            // If the right side is an Int, cast it.
            else if base.type == .double && exponent.type == .integer {
                guard let lVal = base.value as? Double, let rVal = exponent.value as? Int else {
                    throw SymbolError.downcastFailed(leftSymbol: base, .double, rightSymbol: exponent, .integer)
                }
                return Symbol(lVal ** rVal)
            }
            // If the left side is an Int, cast it.
            else if base.type == .integer && exponent.type == .double {
                guard let lVal = base.value as? Int, let rVal = exponent.value as? Double else {
                    throw SymbolError.downcastFailed(leftSymbol: base, .integer, rightSymbol: exponent, .double)
                }
                return Symbol(lVal ** rVal)
            }
            // If the function gets to this point, this is a problem -- the types aren't compatible for this operation (this may not always be reachable, but symbols might be expanded to add more data types in the future).
            throw SymbolError.cannotExponentiate(base: base, exponent: exponent)
        }
        
        // MARK: -- Bitwise
        // MARK: - Shift Left
        static func <<(lhs: Symbol, rhs: Symbol) throws -> Symbol { // A << B
            // Both sides need to be integers.
            guard lhs.type == .integer, rhs.type == .integer else { throw SymbolError.cannotBitShift(lhs: lhs, rhs: rhs, reason: "Only integers can be bitshifted, and only by another integer.") }
            guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else { throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer) }
            return Symbol(lVal << rVal)
        }
        
        // MARK: - Shift Right
        static func >>(lhs: Symbol, rhs: Symbol) throws -> Symbol { // A >> B
            // Both sides need to be integers.
            guard lhs.type == .integer, rhs.type == .integer else { throw SymbolError.cannotBitShift(lhs: lhs, rhs: rhs, reason: "Only integers can be bitshifted, and only by another integer.") }
            guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else { throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer) }
            return Symbol(lVal >> rVal)
        }
        
        // MARK: - Bitwise And
        static func &(lhs: Symbol, rhs: Symbol) throws -> Symbol {
            // Both sides need to be integers.
            guard lhs.type == .integer, rhs.type == .integer else { throw SymbolError.cannotBitwiseLogical(lhs: lhs, rhs: rhs, reason: "Only integers support bitwise and, but an attempt was made with at least one non-integer type.") }
            guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else { throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer) }
            return Symbol(lVal & rVal)
        }
        
        // MARK: - Bitwise Or
        static func |(lhs: Symbol, rhs: Symbol) throws -> Symbol {
            // Both sides need to be integers.
            guard lhs.type == .integer, rhs.type == .integer else { throw SymbolError.cannotBitwiseLogical(lhs: lhs, rhs: rhs, reason: "Only integers support bitwise or, but an attempt was made with at least one non-integer type.") }
            guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else { throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer) }
            return Symbol(lVal | rVal)
        }
        
        // MARK: - Bitwise Xor
        static func ^(lhs: Symbol, rhs: Symbol) throws -> Symbol {
            // Both sides need to be integers.
            guard lhs.type == .integer, rhs.type == .integer else { throw SymbolError.cannotBitwiseLogical(lhs: lhs, rhs: rhs, reason: "Only integers support bitwise or, but an attempt was made with at least one non-integer type.") }
            guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else { throw SymbolError.downcastFailed(leftSymbol: lhs, .integer, rightSymbol: rhs, .integer) }
            return Symbol(lVal ^ rVal)
        }
        
        // MARK: -- Comparisons
        // MARK: - Equality
        static func ==(lhs: Symbol, rhs: Symbol) -> Bool {
            // An integer symbol will be returned iff both symbols contain integers.
            if lhs.type == .integer && rhs.type == .integer {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Int else { return false }
                return lVal == rVal
            }
            // If one or both types is a double, then return a double.
            else if lhs.type == .double && rhs.type == .double {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Double else { return false }
                return lVal == rVal
            }
            // If the right side is an Int, cast it.
            else if lhs.type == .double && rhs.type == .integer {
                guard let lVal = lhs.value as? Double, let rVal = rhs.value as? Int else { return false }
                return lVal == Double(rVal)
            }
            // If the left side is an Int, cast it.
            else if lhs.type == .integer && rhs.type == .double {
                guard let lVal = lhs.value as? Int, let rVal = rhs.value as? Double else { return false }
                return Double(lVal) == rVal
            }
            // If both sides are strings, compare them.
            else if lhs.type == .string && rhs.type == .string {
                guard let lVal = lhs.value as? String, let rVal = rhs.value as? String else { return false }
                return lVal == rVal
            }
            // If both sides are dictionaries, compare them.
            else if lhs.type == .dictionary && rhs.type == .dictionary {
                guard let lVal = lhs.value as? SymbolDictionary, let rVal = rhs.value as? SymbolDictionary else { return false }
                return lVal == rVal
            }
            // If the function gets to this point, then we're comparing types we shouldn't compare. Since this is needed for Hashable, it can't throw an error, so we'll just return false.
            return false
       }
        
        // MARK: - Inequality
        static func !=(lhs: Symbol, rhs: Symbol) -> Bool { !(lhs == rhs) }
        
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
    
    /// Returns the in-memory variables as an array of tuples. The first element of each tuple is the variable's name. The second element is the value, as a String. The array is sorted by the lexicographical order of the first element of each tuple.
    func listSymbolsAsArray() throws -> [(String, String)] {
        var result = [(String, String)]()
        for pair in map {
            let symbolStringKey = pair.0
            let symbolStringValue = try pair.1.asString()
            result.append((symbolStringKey, symbolStringValue))
        }
        result.sort { $0.0 < $1.0 }
        return result
    }
    
    func get(symbolNamed name: String) -> Symbol? { return map[name] }
    
    func typeOf(symbolNamed name: String) -> Symbol.SymbolType? { return map[name]?.type }
    
    // Separate insert functions to avoid runtime type-checking, eliminate an error type, and reduce the amount of "try"ing.
    /// Attempt to insert a symbol.
    mutating func insert(name: String, value: Symbol) { map[name] = value }
    mutating func insert(name: String, value: Int) { map[name] = Symbol(value) }
    mutating func insert(name: String, value: Double) { map[name] = Symbol(value) }
    mutating func insert(name: String, value: String) { map[name] = Symbol(value) }
    mutating func insert(name: String, value: SymbolDictionary) { map[name] = Symbol(value) }
    
    mutating func removeAll() { map.removeAll() }
    
}
