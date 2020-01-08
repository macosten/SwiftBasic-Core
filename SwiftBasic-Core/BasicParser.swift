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
        case unexpectedToken(expected: BasicToken.TokenType, actual: BasicToken.TokenType, reason: String? = nil)
        case badTerm(badTokenType: BasicToken.TokenType)
        case badFactor(badTokenType: BasicToken.TokenType)
        case badExpression(badTokenType: BasicToken.TokenType)
        case badStatement(badTokenType: BasicToken.TokenType, reason: String? = nil)
        case badLine(badTokenType: BasicToken.TokenType)
        case delegateNotSet
        case uninitializedFactor(name: String)
        case unknownLabelError(desiredLabel: Any)
        case unknownError(inMethodNamed: String, reason: String)
    }
    
    private let lexer = BasicLexer()
    
    
    private var symbolMap = SymbolMap()
    private var labelMap = [Int : Int]() // [Line Number : Index of Basic line]
    private var basicLines = [[BasicToken]]() // One line of Basic turns into one of the arrays in this 2D array of tokens.
    
    private var programCounter = -1 // This corresponds to a line of code, and thus to an index of basicLines.
    private var tokenIndex = 0
    private var currentToken : BasicToken { basicLines[programCounter][tokenIndex] }
    
    private var stack = Stack<Int>()
    
    var delegate : BasicDelegate?
    
    func loadCode(fromString: String){
        symbolMap.removeAll()
        labelMap.removeAll()
        basicLines = lexer.getTokensForFileContents(input: fromString)
        programCounter = -1
        tokenIndex = 0
        stack = Stack<Int>()
    }

    
    private func eat(_ expectedType: BasicToken.TokenType) throws {
        if currentToken.type == expectedType { // If the current token's TokenType is what we expect...
            tokenIndex += 1 //Advance the token index.
        } else {
            throw ParserError.unexpectedToken(expected: expectedType, actual: currentToken.type) // If we eat an unexpected token, throw an error.
        }
    }
    
    private func parseLine() throws {
        if currentToken.type == .integer {
            labelMap[currentToken.intValue!] = programCounter
            try eat(.integer)
        }
        try parseStatement()
    }
    
    // MARK: - Parse Statement
    private func parseStatement() throws {
        switch currentToken.type {
        case .let:
            try eat(.let)
            let varName = currentToken.rawValue
            try eat(.identifier)
            try eat(.assign)
            let valueSymbol = try parseExpression()
            try symbolMap.insert(name: varName, value: valueSymbol)
            try eat(.newline)
        case .print:
            try eat(.print)
            let expressionListString = try parseExpressionList()
            delegate?.handlePrintStatement(stringToPrint: expressionListString) // Delegate must be set, or this does nothing (obviously)
            try eat(.newline)
        case .if:
            var truthValue = false // If the conditional is true, we'll set this to true.
            try eat(.if)
            let lhs = try parseExpression()
            guard currentToken.isRelation else { // This center token (IF lhs relation rhs...) must be a relation token.
                throw ParserError.badStatement(badTokenType: currentToken.type, reason: "Token must be a relation, but it's not.")
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
        case .goto:
            try eat(.goto)
            let valueSymbol = try parseExpression()
            guard let desiredLabel = valueSymbol.value as? Int, let target = labelMap[desiredLabel] else {
                throw ParserError.unknownLabelError(desiredLabel: valueSymbol.value)
            }
            programCounter = target - 1 // - 1 because run() will increment the program counter for us afterward.
        case .gosub:
            stack.push(programCounter) // Store the program counter on the stack...
            try eat(.gosub)
            let valueSymbol = try parseExpression()
            guard let desiredLabel = valueSymbol.value as? Int, let target = labelMap[desiredLabel] else {
                throw ParserError.unknownLabelError(desiredLabel: valueSymbol.value)
            }
            programCounter = target - 1 // - 1 because run() will increment the program counter for us afterward.
        case .return:
            try eat(.return)
            let target = stack.pop()
            if let target = target { programCounter = target - 1 }
            try eat(.newline)
        case .rem: break //Just comments...
        case .end: programCounter = basicLines.count
        default: throw ParserError.badStatement(badTokenType: currentToken.type)
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
            return try termSymbol + nextSymbol
        case .minus:
            try eat(.minus)
            let nextSymbol = try parseTerm()
            return try termSymbol - nextSymbol
        default:
            return termSymbol
            // throw ParserError.badExpression(badTokenType: currentToken.type)
        }
    }
    
    /// Parse a term.
    private func parseTerm() throws -> SymbolMap.Symbol {
        let factorSymbol = try parseFactor()
        switch currentToken.type {
        case .multiply:
            try eat(.multiply)
            let nextSymbol = try parseFactor()
            return try factorSymbol * nextSymbol // Operators are overloaded to make the intent clearer
        case .divide:
            try eat(.divide)
            let nextSymbol = try parseFactor()
            return try factorSymbol / nextSymbol
        case .mod:
            try eat(.mod)
            let nextSymbol = try parseFactor()
            return try factorSymbol % nextSymbol
        default:
            return factorSymbol
            // throw ParserError.badTerm(badTokenType: currentToken.type)
        }
    }
    
    /// Parse a factor.
    private func parseFactor() throws -> SymbolMap.Symbol {
        switch currentToken.type {
        case .identifier:
            let varName = currentToken.rawValue
            try eat(.identifier)
            guard let symbol = symbolMap.get(symbolNamed: varName) else {
                throw ParserError.uninitializedFactor(name: varName)
            }
            return symbol
        case .integer:
            let intValue = currentToken.intValue!
            try eat(.integer)
            return SymbolMap.Symbol(type: .integer, value: intValue)
        case .double:
            let doubleValue = currentToken.doubleValue!
            try eat(.double)
            return SymbolMap.Symbol(type: .double, value: doubleValue)
        case .leftParenthesis: // MARK: - Program Flow Differs from TinyBasic
            let expValue = try parseExpression()
            try eat(.rightParenthesis)
            return expValue
        default:
            throw ParserError.badFactor(badTokenType: currentToken.type)
        }
    }
    
    func run() throws {
        while programCounter < basicLines.count-1 { // While we're not at the end of the program...
            tokenIndex = 0 // Reset the token index.
            programCounter += 1 // Increment the program counter (we do this here in case the line modifies the program counter; if we do it after parseLine(), we'd mess it up)
            try parseLine()
        }
    }
    
}
