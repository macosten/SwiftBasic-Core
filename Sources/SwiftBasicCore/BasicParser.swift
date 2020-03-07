//
//  BasicParser.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/6/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

public class BasicParser: NSObject {
    
    typealias Symbol = SymbolMap.Symbol
    
    public enum ParserError: Error {
        case unexpectedToken(expected: TokenType, actual: TokenType, atLine: Int, tokenNumber: Int) // If the expected and actual types of the current token differ, this error will be thrown.
        case badFactor(badTokenType: TokenType, atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown if we failed to parse a factor. atLine and tokenNumber are zero-indexed.
        case badStatement(badTokenType: TokenType, atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown if we failed to parse a statement. atLine and tokenNumber are zero-indexed.
        case delegateNotSet // Thrown if self.delegate is nil, but we need a delegate to continue.
        case uninitializedSymbol(name: String, atLine: Int, tokenNumber: Int) // Thrown if the program attempts to access a symbol with no value.
        case unknownLabelError(desiredLabel: Any, atLine: Int, tokenNumber: Int) // Thrown if the program attempts to jump to a label that doesn't exist.
        case unknownError(inMethodNamed: String, reason: String) // Thrown if the parser enters state that it really shouldn't (a bug, in other words).
        // Below here are errors that are essentially converted from SymbolErrors.
        case unsupportedSymbolDataType(value: Any) // Thrown instead of SymbolError.unsupportedType(value: Any).
        case badMath(failedOperation: String, atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown as an umbrella for the "cannot____" errors other than cannotCompare. If the need arises, I might split this error into the different operations (cannotAdd, cannotSubtract, etc).
        case badComparison(failedComparison: String, atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown instead of cannotCompare.
        case internalDowncastError(moreInfo: String) // Thrown instead of downcastFailed; not much is passed mostly because this isn't a problem with the user's program, but rather with SwiftBasic.
        case integerOverOrUnderflow(failedOperation: String, atLine: Int, tokenNumber: Int) // Thrown instead of integerOverflow or integerUnderflow.
        case programEndedManually // Thrown when .eat() is called after the program is ended with endProgram.
        case cannotSubscript(atLine: Int, tokenNumber: Int) // Thrown if someone tries to use a subscript on a value that can't be subscripted, like a number.
        case unknownSymbolError(moreInfo: String) // Thrown instead of SymbolError.unknownError.
        
    }
    
    private let lexer = BasicLexer()
    
    
    internal var symbolMap = SymbolMap()
    internal var labelMap = LabelMap() // [Line Number/Identifier at start of line : Index of Basic line]
    internal var basicLines = [[BasicToken]]() // One line of Basic turns into one of the arrays in this 2D array of tokens.
    
    private var programCounter = -1 // This index of the line of code we're running - an index of basicLines. We start "before" the first line of our program.
    private var tokenIndex = 0 // The index of the current token in the current line.
    private var currentToken : BasicToken { basicLines[programCounter][tokenIndex] }
    private var nextToken : BasicToken? { basicLines[programCounter].indices.contains(tokenIndex+1) ? basicLines[programCounter][tokenIndex + 1] : nil }
    
    public private(set) var running : Bool = false // True when a program is running, false otherwise...
    
    private var stack = Stack<Int>()
    
    public weak var delegate : BasicDelegate?
    
    public func loadCode(fromString: String) throws {
        // Reset the internal state of our data structures.
        symbolMap.removeAll()
        labelMap.removeAll()
        programCounter = -1
        tokenIndex = 0
        stack = Stack<Int>()
        
        // Have the lexer find the tokens in the input string.
        basicLines = lexer.getTokensForFileContents(input: fromString)
        
        // Find all the labels.
        try findLabels()
    }
    
    /// Ends the program.
    public func endProgram() {
        // This actually sets the program counter to look at the end of the program, which will then allow the loop in run() to end.
        running = false // Just in case this was called by another object -- the Basic runtime will now know that it was supposed to stop.
        programCounter = basicLines.count - 1
        tokenIndex = 0
    }
    
    /// Find all the labels in the code. A label is an Integer or an Identifier that may appear at the start of a line.
    private func findLabels() throws {
        for index in basicLines.indices {
            switch basicLines[index].first?.type {
            case .integer:
                guard let intValue = basicLines[index].first?.intValue else { // Extract the integer value.
                    throw ParserError.unknownError(inMethodNamed: "findLabels", reason: "Failed to get integer from integer token. This is a bug.")
                }
                basicLines[index][0].isLabel = true // Note that the token is a label.
                labelMap[intValue] = index // Fill in the label mapping.
            case .identifier:
                let tokenAfterId = basicLines[index].indices.contains(1) ? basicLines[index][1] : nil // Bounds-safe assignment for the token after the identifier.
                guard let rawIdentifier = basicLines[index].first?.rawValue else { // Extract the raw string value.
                    throw ParserError.unknownError(inMethodNamed: "findLabel", reason: "Failed to get raw string value from identifier token. This is a bug.")
                }
                if tokenAfterId?.isAssignment ?? false { break } // Break out of the switch statement if the next token is an assignment - this isn't a label, but rather an assignment.
                else if let type = tokenAfterId?.type, type == .leftSquareBracket { break } // Break out of the switch statement if the next token is an opening square bracket. It could be an assignment (like dictionary["key"] = value).
                else {
                    basicLines[index][0].isLabel = true // Note that the token is a label.
                    labelMap[rawIdentifier] = index // Fill in the label mapping.
                }
            default: // Otherwise, do nothing.
                break
            }
        }
    }
    
    private func eat(_ expectedType: TokenType) throws {
        if !running { throw ParserError.programEndedManually }
        if currentToken.type == expectedType { // If the current token's TokenType is what we expect...
            tokenIndex += 1 //Advance the token index.
        } else {
            throw ParserError.unexpectedToken(expected: expectedType, actual: currentToken.type, atLine: programCounter, tokenNumber: tokenIndex) // If we eat an unexpected token, throw an error.
        }
    }
    
    /// Parse a line, which is an optional label and then a statement.
    private func parseLine() throws {
        if currentToken.isLabel {
            try eat(currentToken.type) // Ignore labels -- they've already been processed in findLabels().
        }
        try parseStatement()
    }
    
    // MARK: - Parse Statement
    private func parseStatement() throws {
        switch currentToken.type {
        case .let:
            try eat(.let)
            try parseAssignment() // Attempt to parse an assignment.
        case .identifier:
            try parseAssignment() // If this identifier isn't a label, it should be an assignment.
        case .print:
            try eat(.print)
            guard let delegate = delegate else { throw ParserError.delegateNotSet }
            let expressionListString = try parseExpressionList()
            delegate.handlePrintStatement(stringToPrint: expressionListString) // Delegate must be set, or this does nothing (obviously)
            try eat(.newline)
        case .if:
            var truthValue = false // If the conditional is true, we'll set this to true.
            try eat(.if)
            let lhs = try parseExpression()
            guard currentToken.isRelation else { // This center token (IF lhs relation rhs...) must be a relation token.
                throw ParserError.badStatement(badTokenType: currentToken.type, atLine: programCounter, tokenNumber: tokenIndex, reason: "Token must be a relation, but it's not.")
            }
            let operatorType = currentToken.type
            try eat(currentToken.type) // Heh, I guess this will always succeed.
            let rhs = try parseExpression()
            switch operatorType { // Set the truth value based on the operator.
            case .equalTo: if lhs == rhs { truthValue = true }
            case .notEqualTo: if lhs != rhs { truthValue = true }
            case .lessThan: if try lhs < rhs { truthValue = true }
            case .greaterThan: if try lhs > rhs { truthValue = true }
            case .lessThanOrEqualTo: if try lhs <= rhs { truthValue = true }
            case .greaterThanOrEqualTo: if try lhs >= rhs { truthValue = true }
            default: throw ParserError.unknownError(inMethodNamed: "parseStatement", reason: "operatorType was a relation, but the switch statement on operatorType didn't catch it. This is a bug with the Basic Parser and should never happen.")
            }
            if truthValue { // Only parse the statement if the truth value is true.
                try eat(.then)
                try parseStatement()
            }
        case .input:
            try eat(.input)
            // Ensure at least one variable is being set.
            let firstVarName = currentToken.rawValue
            guard let delegate = delegate else { throw ParserError.delegateNotSet }
            let firstInputValue = delegate.handleInput()
            let firstSymbol = Symbol(fromString: firstInputValue)
            try symbolMap.insert(name: firstVarName, value: firstSymbol)
            try eat(.identifier)
            
            while (currentToken.type != .newline) { // Process further tokens
                try eat(.comma)
                let varName = currentToken.rawValue
                let inputValue = delegate.handleInput()
                let symbol = Symbol(fromString: inputValue)
                try symbolMap.insert(name: varName, value: symbol)
                try eat(.identifier)
            }
            try eat(.newline)
        case .goto: // Jump to a label.
            try eat(.goto)
            try parseJump()
        case .gosub: // Almost identical to GOTO but we push the value of the Program Counter to the stack.
            stack.push(programCounter) // Store the program counter on the stack...
            try eat(.gosub)
            try parseJump()
        case .return: // Remember when we GOSUB-ed and pushed a value to the stack? Now we'll pop that value from the stack and go there.
            try eat(.return)
            guard let target = stack.pop() else { break } // Should I hrow an error? Stop execution? Do nothing? I'm not really sure. I'll have to go look at what other Basics do.
            try eat(.newline)
            programCounter = target // We will end up at the line after the line that called the subroutine.
        case .clear:
            guard let delegate = delegate else { throw ParserError.delegateNotSet }
            delegate.handleClear()
        case .list:
            guard let delegate = delegate else { throw ParserError.delegateNotSet }
            try delegate.handleList(listOfSymbols: symbolMap.listSymbolsAsArray())
        case .rem: break //Just comments... ignore 'em all.
        case .newline: break //Ignore empty statements.
        case .end: endProgram()
        default: throw ParserError.badStatement(badTokenType: currentToken.type, atLine: programCounter, tokenNumber: tokenIndex)
        }
    }
    
    /// Parses an assignment, like "I = I + 10" or "B += 40".
    private func parseAssignment() throws {
        let varName = currentToken.rawValue
        var keySymbol: Symbol? // In case this is assigning to a key in a dictionary; if so, this will be non-nil and contain the value of the key.
        try eat(.identifier)
        
        // See if we're assigning to a subscript.
        if currentToken.type == .leftSquareBracket { // Parse a key in square brackets, if it exists.
            try eat(.leftSquareBracket)
            keySymbol = try parseExpression()
            try eat(.rightSquareBracket)
        }
        
        guard currentToken.isAssignment else { // If the current token isn't an assignment, throw an error.
            throw ParserError.badStatement(badTokenType: currentToken.type, atLine: programCounter, tokenNumber: tokenIndex, reason: "Token must be an assignment operator, but it's not.")
        }
        let assignmentType = currentToken.type // Take note of what type of assignment we're making.
        try eat(assignmentType)
        
        let valueSymbol = try parseExpression() // Calculate the value we're assigning.
        
        if let key = keySymbol { try processSubscriptedAssignment(varName: varName, key: key, assignmentType: assignmentType, valueSymbol: valueSymbol) }
        else { try processNormalAssignment(varName: varName, assignmentType: assignmentType, valueSymbol: valueSymbol) }
        
        try eat(.newline)
    }
        
    /// Process an assignment to a non-dictionary symbol.
    private func processNormalAssignment(varName: String, assignmentType: TokenType, valueSymbol: Symbol) throws {
        if assignmentType == .assign { // var = valueSymbol
            try symbolMap.insert(name: varName, value: valueSymbol)
        }
        else { // We'll need to figure out what the value of the variable we're assigning to is.
            guard let oldValueSymbol = symbolMap.get(symbolNamed: varName) else {
                throw ParserError.uninitializedSymbol(name: varName, atLine: programCounter, tokenNumber: tokenIndex - 1)
            }
            switch assignmentType {
            case .plusAssign: // var += valueSymbol
                try symbolMap.insert(name: varName, value: oldValueSymbol + valueSymbol) // Increment the existing value by the new value.
            case .minusAssign: // var -= valueSymbol
                try symbolMap.insert(name: varName, value: oldValueSymbol - valueSymbol) // Decrement the existing value by the new value.
            case .multiplyAssign: // var *= valueSymbol
                try symbolMap.insert(name: varName, value: oldValueSymbol * valueSymbol) // Multiply the existing value by the new value.
            case .divideAssign: // var /= valueSymbol
                try symbolMap.insert(name: varName, value: oldValueSymbol / valueSymbol) // Divide the existing value by the new value.
            case .modAssign: // var %= valueSymbol
                try symbolMap.insert(name: varName, value: oldValueSymbol % valueSymbol) // Mod the existing value by the new value.
            default:
                throw ParserError.unknownError(inMethodNamed: "parseNormalAssignment", reason: "There's an assignment operator on line \(programCounter) [curentToken.isAssignment == true], but it wasn't caught in the appropriate switch assignment. Type: \(assignmentType).")
            }
        }
    }
    
    /// Process an assignment to a dictionary or a subscript of a string.
    private func processSubscriptedAssignment(varName: String, key: Symbol, assignmentType: TokenType, valueSymbol: Symbol) throws {
        guard let existingSymbol = symbolMap.get(symbolNamed: varName) else {
            // If this is an uninitialized value, then assume we're just assigning this thing to a dictionary.
            try symbolMap.insert(name: varName, value: [key: valueSymbol])
            return
        }
        
        switch existingSymbol.type {
        case .dictionary:
            guard var dict = existingSymbol.value as? SymbolMap.SymbolDictionary else { throw ParserError.internalDowncastError(moreInfo: "A dictionary symbol did not contain a dictionary. This is probably a bug.") }
            if assignmentType == .assign { // Regular assignment
                dict[key] = valueSymbol // Make the assignment
                try symbolMap.insert(name: varName, value: dict)
            }
            else {
                guard let oldValueSymbol = dict[key] else { throw ParserError.uninitializedSymbol(name: varName, atLine: programCounter, tokenNumber: tokenIndex - 1) }
                switch assignmentType {
                case .plusAssign: dict[key] = try oldValueSymbol + valueSymbol
                case .minusAssign: dict[key] = try oldValueSymbol - valueSymbol
                case .multiplyAssign: dict[key] = try oldValueSymbol * valueSymbol
                case .divideAssign: dict[key] = try oldValueSymbol / valueSymbol
                case .modAssign: dict[key] = try oldValueSymbol % valueSymbol
                default:
                    throw ParserError.unknownError(inMethodNamed: "parseSubscriptedAssignment", reason: "There's an assignment operator on line \(programCounter) [curentToken.isAssignment == true], but it wasn't caught in the appropriate switch assignment. Type: \(assignmentType).")
                }
                try symbolMap.insert(name: varName, value: dict)
            }
        case .string:
            throw ParserError.unknownSymbolError(moreInfo: "This is a planned feature, but isn't implemented yet.")
        default:
            throw ParserError.cannotSubscript(atLine: programCounter, tokenNumber: tokenIndex)
        }
        
        
    }
    
    /// Parse a jump, like that as a part of a GOTO or a GOSUB.
    private func parseJump() throws {
        // If the next token is an identifier, then we should try to jump to it.
        if currentToken.type == .identifier {
            guard let target = labelMap[currentToken.rawValue] else {
                throw ParserError.unknownLabelError(desiredLabel: currentToken.rawValue, atLine: programCounter, tokenNumber: tokenIndex)
            }
            programCounter = target - 1 // - 1 because run() will increment the program counter for us afterward.
        }
        else { // Otherwise, assume it's an expression that results in an Int.
            let valueSymbol = try parseExpression()
            guard let desiredLabel = valueSymbol.value as? Int, let target = labelMap[desiredLabel] else {
                throw ParserError.unknownLabelError(desiredLabel: valueSymbol.value, atLine: programCounter, tokenNumber: tokenIndex)
            }
            programCounter = target - 1
        }
    }
    
    /// Parses an expression list, probably because we're trying to figure out what string should be PRINT-ed.
    private func parseExpressionList() throws -> String {
        var result = ""
        // Assume it's an expression. Figure out the string that corresponds to the value of the expression.
        let expressionSymbol = try parseExpression()
        switch expressionSymbol.type {
        case .double: result = String(expressionSymbol.value as! Double)
        case .integer: result = String(expressionSymbol.value as! Int)
        case .string: result = String(expressionSymbol.value as! String)
        case .dictionary: result = try expressionSymbol.asString()
        }
        if currentToken.type == .comma { // Continue down the list if there's a comma.
            try eat(.comma)
            result += try parseExpressionList()
        }
        return result
    }
    
    /// Parse an expression (plus, minus) -- the base of the order of operations.
    private func parseExpression() throws -> Symbol {
        let termSymbol = try parseTerm()
        switch currentToken.type {
        case .plus:
            try eat(.plus)
            let nextSymbol = try parseTerm()
            return try termSymbol + nextSymbol // Operators are overloaded to make the intent clearer
        case .minus:
            try eat(.minus)
            let nextSymbol = try parseTerm()
            return try termSymbol - nextSymbol
        default:
            return termSymbol
        }
    }
    
    /// Parse a term (multiply, divide, modulo).
    private func parseTerm() throws -> Symbol {
        let exponentialSymbol = try parseExponential()
        switch currentToken.type {
        case .multiply:
            try eat(.multiply)
            let nextSymbol = try parseExponential()
            return try exponentialSymbol * nextSymbol
        case .divide:
            try eat(.divide)
            let nextSymbol = try parseExponential()
            return try exponentialSymbol / nextSymbol
        case .mod:
            try eat(.mod)
            let nextSymbol = try parseExponential()
            return try exponentialSymbol % nextSymbol
        default:
            return exponentialSymbol
        }
    }
    
    /// Parse an exponential.
    private func parseExponential() throws -> Symbol { // A ** B
        let factorSymbol = try parseFactor()
        switch currentToken.type {
        case .power:
            try eat(.power)
            let nextSymbol = try parseFactor()
            return try factorSymbol ** nextSymbol
        default:
            return factorSymbol
        }
    }
    
    /// Parse a factor (literal data types, identifiers, and paretheticals -- the top of the order of operations).
    private func parseFactor() throws -> Symbol {
        switch currentToken.type {
        case .identifier: // Fetch this identifier's value and return it as a Symbol.
            var varName = currentToken.rawValue
            try eat(.identifier)
            // Get the desired symbol.
            guard var symbol = symbolMap.get(symbolNamed: varName) else {
                throw ParserError.uninitializedSymbol(name: varName, atLine: programCounter, tokenNumber: tokenIndex)
            }
            // If this is a dictionary...
            if symbol.type == .dictionary {
                while currentToken.type == .leftSquareBracket { // "While" to ensure that nested dictionaries can be read
                    try eat(.leftSquareBracket) // Eat the "["
                    let key = try parseExpression() // Parse the key
                    //if key.type == .dictionary { throw ParserError.naughty(moreInfo: "Please don't use dictionaries as keys in dictionaries.")} // Not sure if this necessarily needs to be banned, but of all the things you're allowed to do, it strikes me as the dumbest
                    // For error reporting purposes, recalculate the new variable name to make it more clear what's wrong if someone tries to get an uninitialized value.
                    varName = "\(varName)[\(try key.asString())]"
                    
                    // Ensure that the dictionary is both valid and that there's a value stored at that key (implementing optionals into Basic seems like a bit too much).
                    guard let dict = symbol.value as? SymbolMap.SymbolDictionary else { throw ParserError.unknownSymbolError(moreInfo: "Failed to extract dictionary value from \(varName).") }
                    
                    guard let value = dict[key] else { throw ParserError.uninitializedSymbol(name: varName, atLine: programCounter, tokenNumber: tokenIndex) }
                    symbol = value
                    
                    try eat(.rightSquareBracket) // Eat the "]"
                }
            }
            return symbol
        case .integer: // Return a Symbol with this integer's value.
            let intValue = currentToken.intValue!
            try eat(.integer)
            return Symbol(type: .integer, value: intValue)
        case .double: // Return a Symbol with this double's value.
            let doubleValue = currentToken.doubleValue!
            try eat(.double)
            return Symbol(type: .double, value: doubleValue)
        case .stringLiteral: // This might just be a string literal, in which case we should just return a symbol with it.
            let stringValue = currentToken.stringValue!
            try eat(.stringLiteral)
            return Symbol(type: .string, value: stringValue)
        case .dict: // This is a new empty dictionary.
            try eat(.dict)
            return Symbol(type: .dictionary, value: SymbolMap.SymbolDictionary())
        case .leftParenthesis: // Assume this is the start of a nested expression; evaluate that expression and return a Symbol with its value.
            let expValue = try parseExpression()
            try eat(.rightParenthesis)
            return expValue
        default:
            throw ParserError.badFactor(badTokenType: currentToken.type, atLine: programCounter, tokenNumber: tokenIndex)
        }
    }
    
    /// You may wish to run this on a background thread.
    public func run() throws {
        running = true
        while programCounter < basicLines.count-1 { // While we're not at the end of the program...
            tokenIndex = 0 // Reset the token index.
            programCounter += 1 // Increment the program counter (we do this here in case the line modifies the program counter; if we do it after parseLine(), we'd mess it up)
            do {
                try parseLine()
            } catch Symbol.SymbolError.unsupportedType(let value) { // Convert SymbolErrors to their equivalent ParserErrors.
                running = false
                throw ParserError.unsupportedSymbolDataType(value: value)
            } catch Symbol.SymbolError.cannotAdd(let lhs, let rhs, let reason) {
                running = false
                throw ParserError.badMath(failedOperation: "\(lhs.value) + \(rhs.value)", atLine: programCounter, tokenNumber: tokenIndex, reason: reason)
            } catch Symbol.SymbolError.cannotSubtract(let lhs, let rhs, let reason) {
                running = false
                throw ParserError.badMath(failedOperation: "\(lhs.value) - \(rhs.value)", atLine: programCounter, tokenNumber: tokenIndex, reason: reason)
            } catch Symbol.SymbolError.cannotMultiply(let lhs, let rhs, let reason) {
                running = false
                throw ParserError.badMath(failedOperation: "\(lhs.value) * \(rhs.value)", atLine: programCounter, tokenNumber: tokenIndex, reason: reason)
            } catch Symbol.SymbolError.cannotDivide(let lhs, let rhs, let reason) {
                running = false
                throw ParserError.badMath(failedOperation: "\(lhs.value) / \(rhs.value)", atLine: programCounter, tokenNumber: tokenIndex, reason: reason)
            } catch Symbol.SymbolError.cannotModulo(let lhs, let rhs, let reason) {
                running = false
                throw ParserError.badMath(failedOperation: "\(lhs.value) % \(rhs.value)", atLine: programCounter, tokenNumber: tokenIndex, reason: reason)
            } catch Symbol.SymbolError.cannotExponentiate(let lhs, let rhs, let reason) {
                running = false
                throw ParserError.badMath(failedOperation: "\(lhs.value) ** \(rhs.value)", atLine: programCounter, tokenNumber: tokenIndex, reason: reason)
            } catch Symbol.SymbolError.cannotCompare(let lhs, let rhs, let reason) {
                running = false
                throw ParserError.badComparison(failedComparison: "\(lhs.value) and \(rhs.value)", atLine: programCounter, tokenNumber: tokenIndex, reason: reason)
            } catch Symbol.SymbolError.downcastFailed(let leftSymbol, let desiredLeftType, let rightSymbol, let desiredRightType) {
                running = false
                throw ParserError.internalDowncastError(moreInfo: "An internal error ocurred (Downcasting \(leftSymbol.value) to \(desiredLeftType) and/or \(rightSymbol.value) to \(desiredRightType) failed). This shouldn't indicate a problem with your code; try running your program again.")
            } catch Symbol.SymbolError.integerOverflow(let factor0, let operation, let factor1) {
                running = false
                throw ParserError.integerOverOrUnderflow(failedOperation: "\(factor0) \(operation) \(factor1)", atLine: programCounter, tokenNumber: tokenIndex)
            } catch Symbol.SymbolError.unknownError(let moreInfo) {
                running = false
                throw ParserError.unknownSymbolError(moreInfo: moreInfo)
            } catch { // Otherwise, just propagate the error.
                running = false
                throw error
            }
        }
        running = false
    }
    
}
