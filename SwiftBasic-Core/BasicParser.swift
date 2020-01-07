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
        case unexpectedToken(expected: BasicToken.TokenType, actual: BasicToken.TokenType)
        case badLineBeginning
    }
    
    private let lexer = BasicLexer()
    private var symbolMap = [Int : Int]() // [Line Number : Index of Basic line]
    private var basicLines = [[BasicToken]]() // One line of Basic turns into one of the arrays in this 2D array of tokens.
    
    private var programCounter = 0 // This corresponds to a line of code, and thus to an index of basicLines.
    private var tokenIndex = 0
    private var currentToken : BasicToken { basicLines[programCounter][tokenIndex] }
    
    private var stack = Stack<Int>()
    
    func loadCode(fromString: String){
        basicLines = lexer.getTokensForFileContents(input: fromString)
        programCounter = 0
        tokenIndex = 0
        stack = Stack<Int>()
        symbolMap.removeAll()
    }

    
    private func eat(_ expectedType: BasicToken.TokenType) throws {
        if currentToken.type == expectedType { // If the current token's TokenType is what we expect...
            tokenIndex += 1 //Advance the token index.
        } else {
            throw ParserError.unexpectedToken(expected: expectedType, actual: currentToken.type) // If we eat an unexpected token, throw an error.
        }
    }
    
    private func parseLine() throws {
        if currentToken.type == .integer { try eat(.integer) }
        try parseStatement()
    }
    
    private func parseStatement() throws {
        switch currentToken.type {
        case .let:
            try eat(.let)
            let varName = currentToken.rawValue
            try eat(.identifier)
            try eat(.assign)
            //let value = parseExpression()
        default: throw ParserError.badLineBeginning
        }
        
    }
    
    private func parseExpression() throws {
        
    }
    
    private func parseTerm(){
        
    }
    
    private func parseFactor(){
        
    }
    
}
