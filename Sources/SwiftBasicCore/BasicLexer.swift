//
//  BasicLexer.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/4/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

/// A Lexer for Basic. More of a namespace than an actual class.
final class BasicLexer: NSObject {
    
    /// Tokenize one line of Basic code.
    private func getTokensForLine(inputLine: Substring) -> [BasicToken] {
        // This array will store our tokens.
        var tokenArray = [BasicToken]()
        
        // Convert the input line into a Character array -- we'll go through this one character at a time. We'll also add a trailing newline.
        let inputCharArray = Array(inputLine) + ["\n"]
        
        
        var tokenBuffer = [Character]() // Since we're going through the input one character at a time, we're going to want a space to construct our token. This won't contain the "guts" for more than one token at a time.
        
        var i = 0 // Since we're going through the input one character at a time, we'll need tighter control over the loop index than we normally get with a for loop...
        
        //For each character...
        while i < inputLine.count {
            
            //Skip this character if it's whitespace.
            if inputCharArray[i].isWhitespace {
                i += 1
                continue
            }
            
            //If:
            //1. We're in code mode
            //2. The first character of this token is a letter, underscore, emoji, or number:
            //We're making a token.
            if inputCharArray[i].isValidForGeneralToken {
                tokenBuffer.append(inputCharArray[i])
                //Append to this token until we reach whitespace
                while i < inputLine.count {
                    //While the next character is valid for a token,
                    if inputCharArray[i+1].isValidForGeneralToken {
                        tokenBuffer.append(inputCharArray[i+1])
                    } else {
                        let newToken = BasicToken(tokenBuffer) //Create the new token (struct).
                        tokenArray.append(newToken) //Append the new token to the token array.
                        tokenBuffer.removeAll() // Clear the token buffer.
                        break
                    }
                    i += 1
                }
            }
                        
            // Operators
            if inputCharArray[i].isOperator {
                tokenBuffer.append(inputCharArray[i])
                while i < inputLine.count {
                    if inputCharArray[i+1].isOperator {
                        tokenBuffer.append(inputCharArray[i+1])
                    } else {
                        let newToken = BasicToken(tokenBuffer) // Create the new token
                        tokenArray.append(newToken) // Append it to the array
                        tokenBuffer.removeAll() // Clear the token buffer.
                        break
                    }
                    i += 1
                }
            }
            
            // Separators
            if inputCharArray[i].isSeparator {
                tokenBuffer.append(inputCharArray[i]) // Assuming all separators are only one character.
                let newToken = BasicToken(tokenBuffer)
                tokenArray.append(newToken)
                tokenBuffer.removeAll()
            }
            
            // String Literals
            if inputCharArray[i].isQuote { // Note that this will allow for string literals with mismatched quotes (i.e two left-quotes). This is ugly, but it's easier to just have the check happen when the BasicToken is initialized.
                tokenBuffer.append(inputCharArray[i])
                while i < inputLine.count {
                    if !inputCharArray[i+1].isQuote {
                        tokenBuffer.append(inputCharArray[i+1])
                    } else {
                        tokenBuffer.append(inputCharArray[i+1]) //Append that last quote
                        let newToken = BasicToken(tokenBuffer) //Create the new token
                        tokenArray.append(newToken) // Append it to the array
                        tokenBuffer.removeAll() // Clear the token buffer.
                        break
                    }
                    i += 1
                }
                i += 1
                // Keep this one at the end of the loop for sanity's sake.
            }
            
            i += 1 //Pretend we're a for loop and increment the index.
        }
        
        //Finally, at the end of the line, add an end-of-line token.
        tokenArray.append(BasicToken.endOfLineToken())
        return tokenArray
    }
    
    /// Tokenize one or more lines of Basic code.
    func getTokensForFileContents(input: String) -> [[BasicToken]] {
        var tokens = [[BasicToken]]()
        //let lines = input.split { $0.isNewline }
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false) // New behavior -- retains empty lines to make line numbers thrown by errors make more sense to the end-user.
        for line in lines { tokens.append(getTokensForLine(inputLine: line)) }
        return tokens
    }
    
}
