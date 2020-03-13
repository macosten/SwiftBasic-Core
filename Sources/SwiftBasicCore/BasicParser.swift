//
//  BasicParser.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/6/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

final public class BasicParser: NSObject {
    
    typealias Symbol = SymbolMap.Symbol
    typealias SymbolDictionary = [Symbol:Symbol]
    
    public enum ParserError: Error {
        case unexpectedToken(expected: TokenType, actual: TokenType, atLine: Int, tokenNumber: Int) // If the expected and actual types of the current token differ, this error will be thrown.
        case badFactor(badTokenType: TokenType, atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown if we failed to parse a factor. atLine and tokenNumber are zero-indexed.
        case badStatement(badTokenType: TokenType, atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown if we failed to parse a statement. atLine and tokenNumber are zero-indexed.
        case delegateNotSet // Thrown if self.delegate is nil, but we need a delegate to continue.
        case uninitializedSymbol(name: String, atLine: Int, tokenNumber: Int) // Thrown if the program attempts to access a symbol with no value.
        case unknownLabelError(desiredLabel: Any, atLine: Int, tokenNumber: Int) // Thrown if the program attempts to jump to a label that doesn't exist.
        case unknownError(inMethodNamed: String, reason: String) // Thrown if the parser enters state that it really shouldn't (a bug, in other words).
        // Below here are errors that are essentially converted from SymbolErrors.
        case badMath(failedOperation: String, atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown as an umbrella for the "cannot____" errors other than cannotCompare. If the need arises, I might split this error into the different operations (cannotAdd, cannotSubtract, etc).
        case badComparison(failedComparison: String, atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown instead of cannotCompare.
        case internalDowncastError(moreInfo: String) // Thrown instead of downcastFailed; not much is passed mostly because this isn't a problem with the user's program, but rather with SwiftBasic.
        case integerOverOrUnderflow(failedOperation: String, atLine: Int, tokenNumber: Int) // Thrown instead of integerOverflow or integerUnderflow.
        case programEndedManually // Thrown when .eat() is called after the program is ended with endProgram.
        case cannotSubscript(atLine: Int, tokenNumber: Int) // Thrown if someone tries to use a subscript on a value that can't be subscripted, like a number.
        case badSubscript(atLine: Int, tokenNumber: Int) // Thrown if someone tries to subscript a string with a non-integer type.
        case badFunctionArgument(failedOperation: String, atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown if there's a type mismatch between what a built-in function expects and what was passed in.
        case unknownSymbolError(moreInfo: String) // Thrown instead of SymbolError.unknownError.
        case cannotReturn(atLine: Int, tokenNumber: Int) // Thrown if the program encounters a return but there's no value on the jumpStack.
        case cannotIterate(atLine: Int, tokenNumber: Int) // Thrown if the program encounters a next but there's no value on the forStack.
        case badIndex(atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown if a non-variable (non-identifier) index is used in a for loop.
        case badRangeBound(atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown if a bound in a range for a for loop isn't an integer.
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
    
    private var jumpStack = Stack<Int>()
    private var forStack = Stack<LoopEntry>()
    
    public weak var delegate : BasicDelegate?
    
    public func loadCode(fromString: String) throws {
        // Reset the internal state of our data structures.
        symbolMap.removeAll()
        labelMap.removeAll()
        programCounter = -1
        tokenIndex = 0
        jumpStack = Stack<Int>()
        
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
            symbolMap.insert(name: firstVarName, value: firstSymbol)
            try eat(.identifier)
            
            while (currentToken.type != .newline) { // Process further tokens
                try eat(.comma)
                let varName = currentToken.rawValue
                let inputValue = delegate.handleInput()
                let symbol = Symbol(fromString: inputValue)
                symbolMap.insert(name: varName, value: symbol)
                try eat(.identifier)
            }
            try eat(.newline)
        case .goto: // Jump to a label.
            try eat(.goto)
            try parseJump()
        case .gosub: // Almost identical to GOTO but we push the value of the Program Counter to the stack.
            jumpStack.push(programCounter) // Store the program counter on the stack...
            try eat(.gosub)
            try parseJump()
        case .return: // Remember when we GOSUB-ed and pushed a value to the stack? Now we'll pop that value from the stack and go there.
            try eat(.return)
            guard let target = jumpStack.pop() else { throw ParserError.cannotReturn(atLine: programCounter, tokenNumber: tokenIndex) }
            try eat(.newline)
            programCounter = target // We will end up at the line after the line that called the subroutine.
        case .for: // The start of a for loop!
            try eat(.for) // FOR <index> IN <lowerBound> TO <upperBound>\n
            guard currentToken.type == .identifier else { throw ParserError.badIndex(atLine: programCounter, tokenNumber: tokenIndex) }
            let indexVar = currentToken
            try eat(.identifier)
            try eat(.in)
            let lowerBound = try parseExpression()
            guard lowerBound.type == .integer else { throw ParserError.badRangeBound(atLine: programCounter, tokenNumber: tokenIndex, reason: "The lower bound must be an integer, but it wasn't.") }
            try eat(.to)
            let upperBound = try parseExpression()
            guard upperBound.type == .integer else { throw ParserError.badRangeBound(atLine: programCounter, tokenNumber: tokenIndex, reason: "The upper bound must be an integer, but it wasn't.") }
            guard let lVal = lowerBound.value as? Int, let uVal = upperBound.value as? Int else { throw ParserError.internalDowncastError(moreInfo: "Failed to extract integer information while constructing a range.") }
            guard lVal < uVal else { throw ParserError.badRangeBound(atLine: programCounter, tokenNumber: tokenIndex, reason: "The lower bound of the range must be less than the upper bound.") }
            try eat(.newline)
            // Now that we know for sure that line was well-formed, let's push the data to the appropriate stack and initialize the index.
            symbolMap.insert(name: indexVar.rawValue, value: lVal)
            let newLoopEntry = LoopEntry(indexName: indexVar.rawValue, range: lVal..<uVal, startLine: programCounter) // run() will increment this value for us, so
            forStack.push(newLoopEntry)
        case .next: // Jump back to the start of the for loop we're in, if it's appropriate to do so, while incrementing the index variable.
            try eat(.next) // NEXT\n
            try eat(.newline)
            // Let's take a peek at the data now that we know that was a well-formed line...
            guard let loopEntry = forStack.peek() else { throw ParserError.cannotIterate(atLine: programCounter, tokenNumber: 0) }
            guard let index = symbolMap.get(symbolNamed: loopEntry.indexName), index.type == .integer else { throw ParserError.badIndex(atLine: loopEntry.startLine, tokenNumber: 1, reason: "Did you change the type of this variable in the loop? The loop can't work if you did.") }
            guard let iVal = index.value as? Int else { throw ParserError.internalDowncastError(moreInfo: "Failed to extract integer information while determining where to jump at the end of a for loop's body.")}
            symbolMap.insert(name: loopEntry.indexName, value: iVal + 1) // Increment the index.
            if loopEntry.range.contains(iVal + 1) { // If the new index is still within the range...
                programCounter = loopEntry.startLine // Jump back to the start of this for loop.
            } else { // otherwise...
                _ = forStack.pop() // Pop this entry for good.
            }
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
            symbolMap.insert(name: varName, value: valueSymbol)
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
            symbolMap.insert(name: varName, value: [key: valueSymbol])
            return
        }
        
        switch existingSymbol.type {
        case .dictionary:
            guard var dict = existingSymbol.value as? SymbolMap.SymbolDictionary else { throw ParserError.internalDowncastError(moreInfo: "A dictionary symbol did not contain a dictionary. This is probably a bug.") }
            if assignmentType == .assign { // Regular assignment
                dict[key] = valueSymbol // Make the assignment
                symbolMap.insert(name: varName, value: dict)
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
                symbolMap.insert(name: varName, value: dict)
            }
        case .string:
            throw ParserError.unknownSymbolError(moreInfo: "Subscripting strings and modifying them is a planned feature, but isn't implemented yet.")
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
    
    /// Infix operators equivalent to AdditionPrecedence in Swift go here (like +, -, |, and ^).
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
        case .bitwiseOr:
            try eat(.bitwiseOr)
            let nextSymbol = try parseFactor()
            return try termSymbol | nextSymbol
        case .bitwiseXor:
            try eat(.bitwiseXor)
            let nextSymbol = try parseFactor()
            return try termSymbol ^ nextSymbol
        default:
            return termSymbol
        }
    }
    
    /// Infix operators equivalent to MultiplicationPrecedence go here (like *, /, and &).
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
        case .bitwiseAnd:
            try eat(.bitwiseAnd)
            let nextSymbol = try parseFactor()
            return try exponentialSymbol & nextSymbol
        default:
            return exponentialSymbol
        }
    }
    
    /// Infix operators equivalent to ExponentiationPrecedence (defined in Exponentiation.swift) go here.
    private func parseExponential() throws -> Symbol { // A ** B
        let bitShiftSymbol = try parseBitwiseShift()
        switch currentToken.type {
        case .power:
            try eat(.power)
            let nextSymbol = try parseBitwiseShift()
            return try bitShiftSymbol ** nextSymbol
        default:
            return bitShiftSymbol
        }
    }
    
    /// Infix operators equivalent to BitwiseShiftPrecedence go here.
    private func parseBitwiseShift() throws -> Symbol {
        let factorSymbol = try parseFactor()
        switch currentToken.type {
        case .bitwiseShiftLeft:
            try eat(.bitwiseShiftLeft)
            let nextSymbol = try parseFactor()
            return try factorSymbol << nextSymbol
        case .bitwiseShiftRight:
            try eat(.bitwiseShiftRight)
            let nextSymbol = try parseFactor()
            return try factorSymbol >> nextSymbol
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
            // If this is a string...
            else if symbol.type == .string && currentToken.type == .leftSquareBracket { // ...and we're subscripting it...
                try eat(.leftSquareBracket)
                
                let indexSymbol = try parseExpression() // Parse the subexpression
                // Get the character at the appropriate index.
                guard let string = symbol.value as? String else { throw ParserError.internalDowncastError(moreInfo: "Failed to extract string value from \(varName).") }
                guard let indexValue = indexSymbol.value as? Int else { throw ParserError.badSubscript(atLine: programCounter, tokenNumber: tokenIndex) }
                let index = string.index(string.startIndex, offsetBy: indexValue)
                guard string.indices.contains(index) else { throw ParserError.badSubscript(atLine: programCounter, tokenNumber: tokenIndex) }

                symbol = Symbol(String(string[index])) // Replace the symbol with one whose value is just the character in a string.
                
                try eat(.rightSquareBracket)
            }
            return symbol
        case .integer: // Return a Symbol with this integer's value.
            let intValue = currentToken.intValue!
            try eat(.integer)
            return Symbol(intValue)
        case .double: // Return a Symbol with this double's value.
            let doubleValue = currentToken.doubleValue!
            try eat(.double)
            return Symbol(doubleValue)
        case .stringLiteral: // This might just be a string literal, in which case we should just return a symbol with it.
            let stringValue = currentToken.stringValue!
            try eat(.stringLiteral)
            return Symbol(stringValue)
// MARK: - Math Function Parsing
        case .rand: // rand(lowerBound, upperBound) == (number between lowerBound and upperBound)
            let arguments = try parseBuiltinFunctionArguments(.rand, argumentCount: 2)
            let lowerBound = arguments[0]
            let upperBound = arguments[1]

            guard lowerBound.type == .integer else { throw ParserError.badFunctionArgument(failedOperation: "rand", atLine: programCounter, tokenNumber: tokenIndex, reason: "The lower bound for rand() must be an integer.") }
            guard upperBound.type == .integer else { throw ParserError.badFunctionArgument(failedOperation: "rand", atLine: programCounter, tokenNumber: tokenIndex, reason: "The upper bound for rand() must be an integer.") }

            guard let lInt = lowerBound.value as? Int, let hInt = upperBound.value as? Int else { throw ParserError.internalDowncastError(moreInfo: "While computing a random number, the upper and lower integer bounds weren't integers. This is probably a bug with something somewhere...") }
            guard lInt < hInt else { throw ParserError.badMath(failedOperation: "rand(\(lInt), \(hInt))", atLine: programCounter, tokenNumber: tokenIndex, reason: "The lower bound for rand() must be less than the upper bound.") }
            
            return Symbol(Int.random(in: lInt...hInt))
        case .sine: // sin(arg)
            let argument = try parseBuiltinFunctionArguments(.sine, argumentCount: 1)[0] // Calculate the argument.
            // Evaluate the function.
            if let intValue = argument.value as? Int {
                return Symbol(sin(Double(intValue)))
            } else if let doubleValue = argument.value as? Double {
                return Symbol(sin(doubleValue))
            } else {
                throw ParserError.badFunctionArgument(failedOperation: "sin", atLine: programCounter, tokenNumber: tokenIndex, reason: "The argument must be a number.")
            }
        case .cosine: // cos(arg)
            let argument = try parseBuiltinFunctionArguments(.cosine, argumentCount: 1)[0] // Calculate the argument.
            // Evaluate the function.
            if let intValue = argument.value as? Int {
                return Symbol(cos(Double(intValue)))
            } else if let doubleValue = argument.value as? Double {
                return Symbol(cos(doubleValue))
            } else {
                throw ParserError.badFunctionArgument(failedOperation: "cos", atLine: programCounter, tokenNumber: tokenIndex, reason: "The argument must be a number.")
            }
        case .tangent: // tan(arg)
            let argument = try parseBuiltinFunctionArguments(.tangent, argumentCount: 1)[0] // Calculate the argument.
            // Evaluate the function.
            if let intValue = argument.value as? Int {
                return Symbol(tan(Double(intValue)))
            } else if let doubleValue = argument.value as? Double {
                return Symbol(tan(doubleValue))
            } else {
                throw ParserError.badFunctionArgument(failedOperation: "tan", atLine: programCounter, tokenNumber: tokenIndex, reason: "The argument must be a number.")
            }
        case .secant: // sec(arg)
            let argument = try parseBuiltinFunctionArguments(.secant, argumentCount: 1)[0] // Calculate the argument.
            // Evaluate the function.
            if let intValue = argument.value as? Int {
                // These will never be completely precise -- it's just the nature of limited-precision numbers like Doubles. Thus, the risk of accidentally dividing by zero is not actually 
                return Symbol(1 / cos(Double(intValue)))
            } else if let doubleValue = argument.value as? Double {
                return Symbol(1 / cos(doubleValue))
            } else {
                throw ParserError.badFunctionArgument(failedOperation: "sec", atLine: programCounter, tokenNumber: tokenIndex, reason: "The argument must be a number.")
            }
        case .cosecant: // csc(arg)
            let argument = try parseBuiltinFunctionArguments(.cosecant, argumentCount: 1)[0] // Calculate the argument.
            // Evaluate the function.
            if let intValue = argument.value as? Int {
                return Symbol(1 / sin(Double(intValue)))
            } else if let doubleValue = argument.value as? Double {
                return Symbol(1 / sin(doubleValue))
            } else {
                throw ParserError.badFunctionArgument(failedOperation: "csc", atLine: programCounter, tokenNumber: tokenIndex, reason: "The argument must be a number.")
            }
        case .cotangent: // cot(arg)
            let argument = try parseBuiltinFunctionArguments(.cotangent, argumentCount: 1)[0] // Calculate the argument.
            // Evaluate the function.
            if let intValue = argument.value as? Int {
                return Symbol(1 / tan(Double(intValue)))
            } else if let doubleValue = argument.value as? Double {
                return Symbol(1 / tan(doubleValue))
            } else {
                throw ParserError.badFunctionArgument(failedOperation: "cot", atLine: programCounter, tokenNumber: tokenIndex, reason: "The argument must be a number.")
            }
        case .arcsine:
            let argument = try parseBuiltinFunctionArguments(.arcsine, argumentCount: 1)[0] // Calculate the argument.
            if let intValue = argument.value as? Int {
                return Symbol(asin(Double(intValue)))
            } else if let doubleValue = argument.value as? Double {
                return Symbol(asin(doubleValue))
            } else {
                throw ParserError.badFunctionArgument(failedOperation: "asin", atLine: programCounter, tokenNumber: tokenIndex, reason: "The argument must be a number.")
            }
        case .arccosine:
            let argument = try parseBuiltinFunctionArguments(.arccosine, argumentCount: 1)[0] // Calculate the argument.
            if let intValue = argument.value as? Int {
                return Symbol(acos(Double(intValue)))
            } else if let doubleValue = argument.value as? Double {
                return Symbol(acos(doubleValue))
            } else {
                throw ParserError.badFunctionArgument(failedOperation: "acos", atLine: programCounter, tokenNumber: tokenIndex, reason: "The argument must be a number.")
            }
        case .arctangent:
            let argument = try parseBuiltinFunctionArguments(.arctangent, argumentCount: 1)[0] // Calculate the argument.
            if let intValue = argument.value as? Int {
                return Symbol(atan(Double(intValue)))
            } else if let doubleValue = argument.value as? Double {
                return Symbol(atan(doubleValue))
            } else {
                throw ParserError.badFunctionArgument(failedOperation: "atan", atLine: programCounter, tokenNumber: tokenIndex, reason: "The argument must be a number.")
            }
        case .length: // Returns the length of a string.
            let argument = try parseBuiltinFunctionArguments(.length, argumentCount: 1)[0]
            if let stringValue = argument.value as? String {
                return Symbol(stringValue.count)
            } else {
                throw ParserError.badFunctionArgument(failedOperation: "len", atLine: programCounter, tokenNumber: tokenIndex, reason: "The argument must be a string.")
            }
        case .count: // Returns the number of elements in a dictionary.
            let argument = try parseBuiltinFunctionArguments(.count, argumentCount: 1)[0]
            if let dict = argument.value as? SymbolDictionary {
                return Symbol(dict.count)
            } else {
                throw ParserError.badFunctionArgument(failedOperation: "count", atLine: programCounter, tokenNumber: tokenIndex, reason: "The argument must be a dictionary.")
            }
        case .leftParenthesis: // Assume this is the start of a nested expression; evaluate that expression and return a Symbol with its value.
            let expValue = try parseExpression()
            try eat(.rightParenthesis)
            return expValue
        case .leftSquareBracket: // Assume this is the start of a dictionary literal.
            return try parseDictionaryLiteral()
        default:
            throw ParserError.badFactor(badTokenType: currentToken.type, atLine: programCounter, tokenNumber: tokenIndex)
        }
    }
    
    /// Given an argument count, parses the arguments in the built-in function and returns them in an array of symbols.
    func parseBuiltinFunctionArguments(_ type: TokenType, argumentCount: UInt) throws -> [Symbol] {
        try eat(type)
        try eat(.leftParenthesis)
        var arguments = [Symbol]()
        for i in 0..<argumentCount {
            arguments.append(try parseExpression())
            if i < argumentCount - 1 { try eat(.comma) }
        }
        try eat(.rightParenthesis)
        return arguments
    }
    
    /// Parses a dictionary literal, starting with a [ and ending with a ].
    private func parseDictionaryLiteral() throws -> Symbol {
        var newDict = SymbolDictionary()
        try eat(.leftSquareBracket)
        var arrayIndexCounter = 0
        while currentToken.type != .rightSquareBracket {
            // Parse the first symbol before the comma.
            let newKey = try parseExpression()
            switch currentToken.type {
            case .colon: // If there's a colon, then newKey is a key, and the expression after it is the value.
                try eat(.colon)
                let newValue = try parseExpression()
                // Add it to the dictionary.
                newDict[newKey] = newValue
            default: // Otherwise, newKey is the value we're trying to store, so let's put it in with an integer key.
                newDict[Symbol(arrayIndexCounter)] = newKey
                arrayIndexCounter += 1 // Increment the counter, so that the next symbol we add will be keyed to the next index.
            }
            if currentToken.type != .rightSquareBracket { try eat(.comma) }
        }
        try eat(.rightSquareBracket)
        return Symbol(newDict)
    }
   
    // private func parseRemainderOfDictionaryAsArrayLiteral() throws -> Symbol { }
    
    /// You may wish to run this on a background thread.
    public func run() throws {
        running = true
        while programCounter < basicLines.count-1 { // While we're not at the end of the program...
            tokenIndex = 0 // Reset the token index.
            programCounter += 1 // Increment the program counter (we do this here in case the line modifies the program counter; if we do it after parseLine(), we'd mess it up)
            do {
                try parseLine()
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
