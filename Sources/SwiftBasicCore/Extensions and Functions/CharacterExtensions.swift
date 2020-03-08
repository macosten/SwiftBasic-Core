//
//  Character+isEmoji.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/5/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

extension Character {
    /// Simple emojis are a single Unicode scalar and look like an emoji.
    var isSimpleEmoji: Bool {
        guard let firstScalarProperties = unicodeScalars.first?.properties else { return false }
        return unicodeScalars.count == 1 && (firstScalarProperties.isEmojiPresentation || firstScalarProperties.generalCategory == .otherSymbol)
    }
    
    /// Combined emojis are multiple Unicode scalars combined into a single emoji.
    var isCombinedEmoji: Bool {
        return (unicodeScalars.count > 1 && unicodeScalars.contains { $0.properties.isJoinControl || $0.properties.isVariationSelector}) || unicodeScalars.allSatisfy({ $0.properties.isEmojiPresentation })
    }

    /// A Boolean value indicating whether this character is an emoji.
    var isEmoji: Bool { isSimpleEmoji || isCombinedEmoji }
    
    /// A Boolean value indicating if this is a valid character for a code token: Letters, Numbers, Emoji, and Underscores. TODO - Rename this.
    var isValidForGeneralToken: Bool { isLetter || isNumber || isEmoji || self == "_" || self == "." }
    
    /// A Boolean value indicating if this is a valid separator character - a semicolon, comma, or a bracket of some sort.
    var isSeparator: Bool { isSingleScalarInCharacterSet(charactersIn: ";,(){}[]") }
    
    /// A Boolean value indicating if this is a character belonging to a mathematical, relational, or logical operator.
    var isOperator: Bool { isSingleScalarInCharacterSet(charactersIn: "+-*/%=<>!|^&") }
    
    /// A Boolean value indicating if this is a quotation mark of some sort.
    var isQuote: Bool { isSingleScalarInCharacterSet(charactersIn: "\"“”«»「」") }
    
    /// Note that this is only intended to work on characters with one unicode scalar.
    private func isSingleScalarInCharacterSet(charactersIn string: String) -> Bool {
        if self.unicodeScalars.count != 1 { return false } // These do not consist of more than one Unicode scalar.
        let quoteCharacterSet = CharacterSet(charactersIn: string)
        guard let scalar = unicodeScalars.first else { return false }
        return quoteCharacterSet.contains(scalar)
    }
}
