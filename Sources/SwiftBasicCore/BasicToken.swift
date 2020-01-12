//
//  BasicToken.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/4/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

struct BasicToken {
    //A type that represents a BASIC lexical token.
    
    enum TokenType {

        case identifier
        
        // MARK: - Keywords
        case print
        case `if`
        case goto
        case input
        case `let`
        case gosub
        case `return`
        case clear
        case list
        case run
        case end
        case then
        case rem
        
        // case `break`
        
        // MARK: - Operators
        case plus
        case minus
        case multiply
        case divide
        case mod
        case increment
        case decrement
        
        // MARK: - Assignment
        case assign
        case plusAssign
        case minusAssign
        case multiplyAssign
        case divideAssign
        case modAssign
        
        // MARK: - Relations
        case equalTo
        case greaterThan
        case lessThan
        case notEqualTo
        case greaterThanOrEqualTo
        case lessThanOrEqualTo
        
        // MARK: - Logical
        case logicalAnd
        case logicalOr
        case logicalNot
        
        // MARK: - Bitwise Operations
        case bitwiseAnd
        case bitwiseOr
        case bitwiseXor
        case bitwiseShiftLeft
        case bitwiseShiftRight
        
        // MARK: - Math Functions
        case sine
        case cosine
        case tangent
        case arcsine
        case arccosine
        case arctangent
        case secant
        case cosecant
        case cotangent
        case power
        
        // MARK: - Other Standard Tokens
        case leftParenthesis
        case rightParenthesis
        case leftCurlyBracket
        case rightCurlyBracket
        case comma
        case leftSquareBracket
        case rightSquareBracket
        case quotationMarks
        case apostrophe
        case semicolon
        case period
        
        // MARK: - Data Types
        case integer
        case double
        case stringLiteral
        
        
        // MARK: - Newline
        case newline
        
        // case octothorpe
        case function
        
    }
    // MARK: - Variables
    let type: TokenType
    let rawValue: String // The raw string value of this token.
    var isLabel: Bool = false // This will be set to true if the Parser determines that this token is a label at the beginning of a line. This lets us differentiate between line-starting identifiers that are labels and that are the first token of an assignment.
    var stringValue : String? {
        if type != .stringLiteral { return nil }
        //Return the raw value without the leading and trailing quotes.
        let startIndex = rawValue.index(after: rawValue.startIndex)
        let endIndex = rawValue.index(before: rawValue.endIndex)
        return String(rawValue[startIndex..<endIndex])
    }
    var intValue : Int? { return Int(rawValue) }
    var doubleValue : Double? { return Double(rawValue) }
    
    /// Returns true if this token is a relation, like .notEqualTo.
    var isRelation : Bool {
        return type == .equalTo || type == .notEqualTo || type == .lessThan || type == .greaterThan || type == .lessThanOrEqualTo || type == .greaterThanOrEqualTo
    }
    
    /// Returns true if this token is an assignment, like .assign or .plusAssign.
    var isAssignment : Bool {
        return type == .assign || type == .plusAssign || type == .minusAssign || type == .multiplyAssign || type == .divideAssign || type == .modAssign
    }
    
    // MARK: - Initializers
    init(_ inString: String) {
        let compareString = inString.lowercased() //Lowercase the input so that tokens can be written however the user wants (ideally all UPPERCASE or all lowercase)
        
        // Special token cases/values go here, like pi -- these will have different raw values than the input string.
        if compareString == "pi" || compareString == "π" {
            rawValue = String(Double.pi)
        } else { // Most tokens just have their raw value equal the input string.
            rawValue = inString // Store a copy of the raw string input here.
        }
        
        
        
        
        // Attempt to match the string to a known keyword, separator, or operator.
        switch compareString {
            
        // Keywords
        case "print": type = .print
        case "let": type = .let
        case "if": type = .if
        case "input": type = .input
        case "then": type = .then
        case "goto": type = .goto
        case "gosub": type = .gosub
        case "return": type = .return
        case "clear": type = .clear
        case "list": type = .list
        // case "run": type = .run Files will generally be loaded from a string so RUN may not be necessary.
        case "end": type = .end
        case "rem": type = .rem
        
        // Operators
        case "+": type = .plus
        case "-": type = .minus
        case "*": type = .multiply
        case "/": type = .divide
        case "%": type = .mod
            
        // Assignments
        case "=": type = .assign
        case "+=": type = .plusAssign
        case "-=": type = .minusAssign
        case "*=": type = .multiplyAssign
        case "/=": type = .divideAssign
        case "%=": type = .modAssign
        
        // Relations
        case "==": type = .equalTo
        case ">": type = .greaterThan
        case "<": type = .lessThan
        case "!=": type = .notEqualTo
        case ">=": type = .greaterThanOrEqualTo
        case "<=": type = .lessThanOrEqualTo
        
        // Logical
        case "&&": type = .logicalAnd
        case "||": type = .logicalOr
        case "!": type = .logicalNot
        
        //Bitwise
        case "&": type = .bitwiseAnd
        case "|": type = .bitwiseOr
        case "^": type = .bitwiseXor
        case "<<": type = .bitwiseShiftLeft
        case ">>": type = .bitwiseShiftRight // Arithmetic right shift
            
        // Math
        case "π": type = .double
        case "pi": type = .double
        case "**": type = .power
        case "sin": type = .sine
        case "cos": type = .cosine
        case "tan": type = .tangent
        case "arcsin": type = .arcsine
        case "arccos": type = .arccosine
        case "arctan": type = .arctangent
        case "sec": type = .secant
        case "csc": type = .cosecant
        case "cot": type = .cotangent
            
            
        // Others
        case ",": type = .comma
        case ";": type = .semicolon
        
        // Otherwise...
        default:
            //
            if Int(inString) != nil { type = .integer }
            else if Double(inString) != nil {type = .double }
            else if (inString.prefix(1) == "\"") && (inString.suffix(1) == "\"") { type = .stringLiteral }
            else { type = .identifier }
            
        }
        
    }
    
    init(_ inCharArray: [Character]) {
        let inString = String(inCharArray)
        self.init(inString)
    }
    
    /// You shouldn't see this initializer.
    private init (withType: TokenType, withRawValue: String) {
        type = withType
        rawValue = withRawValue
    }
    
    // MARK: - Functions
    /// Returns an end-of-line BasicToken.
    static func endOfLineToken() -> BasicToken {
        return BasicToken(withType: .newline, withRawValue: "\n")
    }
    
    
}