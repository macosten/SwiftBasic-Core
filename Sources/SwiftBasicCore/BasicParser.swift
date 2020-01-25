//
//  BasicParser.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/6/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

public class BasicParser: NSObject {
    
    enum ParserError: Error {
        case unexpectedToken(expected: BasicToken.TokenType, actual: BasicToken.TokenType, atLine: Int, tokenNumber: Int) // If the expected and actual types of the current token differ, this error will be thrown.
        case badFactor(badTokenType: BasicToken.TokenType, atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown if we failed to parse a factor. atLine and tokenNumber are zero-indexed.
        case badStatement(badTokenType: BasicToken.TokenType, atLine: Int, tokenNumber: Int, reason: String? = nil) // Thrown if we failed to parse a statement. atLine and tokenNumber are zero-indexed.
        case delegateNotSet // Thrown if self.delegate is nil, but we need a delegate to continue.
        case uninitializedSymbol(name: String, atLine: Int, tokenNumber: Int) // Thrown if the program attempts to access a symbol with no value.
        case unknownLabelError(desiredLabel: Any, atLine: Int, tokenNumber: Int) // Thrown if the program attempts to jump to a label that doesn't exist.
        case unknownError(inMethodNamed: String, reason: String) // Thrown if the parser enters state that it really shouldn't (a bug, in other words).
    }
    
    private let lexer = BasicLexer()
    
    
    private var symbolMap = SymbolMap()
    private var labelMap = LabelMap() // [Line Number/Identifier at start of line : Index of Basic line]
    private var basicLines = [[BasicToken]]() // One line of Basic turns into one of the arrays in this 2D array of tokens.
    
    private var programCounter = -1 // This index of the line of code we're running - an index of basicLines. We start "before" the first line of our program.
    private var tokenIndex = 0 // The index of the current token in the current line.
    private var currentToken : BasicToken { basicLines[programCounter][tokenIndex] }
    private var nextToken : BasicToken? { basicLines[programCounter].indices.contains(tokenIndex+1) ? basicLines[programCounter][tokenIndex + 1] : nil }
    
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
                else {
                    basicLines[index][0].isLabel = true // Note that the token is a label.
                    labelMap[rawIdentifier] = index // Fill in the label mapping.
                }
            default: // Otherwise, do nothing.
                break
            }
        }
    }
    
    private func eat(_ expectedType: BasicToken.TokenType) throws {
        if currentToken.type == expectedType { // If the current token's TokenType is what we expect...
            tokenIndex += 1 //Advance the token index.
        } else {
            throw ParserError.unexpectedToken(expected: expectedType, actual: currentToken.type, atLine: programCounter, tokenNumber: tokenIndex) // If we eat an unexpected token, throw an error.
        }
    }
    
    /// Parse a line, which is an optional label and then a statement.
    private func parseLine() throws {
        let nextTokenIsAssignmentOperator = nextToken?.isAssignment ?? false
        if currentToken.type == .integer || (currentToken.type == .identifier && !nextTokenIsAssignmentOperator) { // Labels are either integers at the start of a line, or identifiers at the start of a line not followed by an assignment operator.
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
            case .equalTo: if try lhs == rhs { truthValue = true }
            case .notEqualTo: if try lhs != rhs { truthValue = true }
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
            let firstSymbol = try SymbolMap.Symbol(fromString: firstInputValue)
            try symbolMap.insert(name: firstVarName, value: firstSymbol)
            try eat(.identifier)
            
            while (currentToken.type != .newline) { // Process further tokens
                try eat(.comma)
                let varName = currentToken.rawValue
                let inputValue = delegate.handleInput()
                let symbol = try SymbolMap.Symbol(fromString: inputValue)
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
        try eat(.identifier)
        guard currentToken.isAssignment else { // If the current token isn't an assignment, throw an error.
            throw ParserError.badStatement(badTokenType: currentToken.type, atLine: programCounter, tokenNumber: tokenIndex, reason: "Token must be an assignment operator, but it's not.")
        }
        let assignmentType = currentToken.type // Take note of what type of assignment we're making.
        try eat(assignmentType)
        
        let valueSymbol = try parseExpression() // Calculate the value we're assigning.
        
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
                throw ParserError.unknownError(inMethodNamed: "parseAssignment", reason: "There's an assignment operator on line \(programCounter) [curentToken.isAssignment == true], but it wasn't caught in the appropriate switch assignment. Type: \(assignmentType).")
            }
        }
        try eat(.newline)
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
        if currentToken.type == .stringLiteral { // Trying to print a string literal? Make it the result.
            result = currentToken.stringValue!
            try eat(.stringLiteral)
        } else { // Assume it's an expression. Figure out the string that corresponds to the value of the expression.
            let expressionSymbol = try parseExpression()
            switch expressionSymbol.type {
            case .double: result = String(expressionSymbol.value as! Double)
            case .integer: result = String(expressionSymbol.value as! Int)
            }
        }
        if currentToken.type == .comma { // Continue down the list if there's a comma.
            try eat(.comma)
            result += try parseExpressionList()
        }
        return result
    }
    
    /// Parse an expression.
    private func parseExpression() throws -> SymbolMap.Symbol {
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
    
    /// Parse a term.
    private func parseTerm() throws -> SymbolMap.Symbol {
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
    private func parseExponential() throws -> SymbolMap.Symbol { // A ** B
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
    
    /// Parse a factor.
    private func parseFactor() throws -> SymbolMap.Symbol {
        switch currentToken.type {
        case .identifier: // Fetch this identifier's value and return it as a Symbol.
            let varName = currentToken.rawValue
            try eat(.identifier)
            guard let symbol = symbolMap.get(symbolNamed: varName) else {
                throw ParserError.uninitializedSymbol(name: varName, atLine: programCounter, tokenNumber: tokenIndex)
            }
            return symbol
        case .integer: // Return a Symbol with this integer's value.
            let intValue = currentToken.intValue!
            try eat(.integer)
            return SymbolMap.Symbol(type: .integer, value: intValue)
        case .double: // Return a Symbol with this double's value.
            let doubleValue = currentToken.doubleValue!
            try eat(.double)
            return SymbolMap.Symbol(type: .double, value: doubleValue)
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
        while programCounter < basicLines.count-1 { // While we're not at the end of the program...
            tokenIndex = 0 // Reset the token index.
            programCounter += 1 // Increment the program counter (we do this here in case the line modifies the program counter; if we do it after parseLine(), we'd mess it up)
            try parseLine()
        }
    }
    
}
