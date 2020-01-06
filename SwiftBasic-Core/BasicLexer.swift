//
//  BasicLexer.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/4/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Cocoa

class BasicLexer: NSObject {
    
    private enum LexingMode {
        case code
        case stringLiteral
        case comment
    }
    
    //This may need to be changed at some point, but for now, I'll make this a property of the lexer: What character sets are allowable in variable names?
    
    func getTokens(inputLine: String) throws -> [BasicToken] {
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
            
            // String Literals
            // Really the only difference is that we check for a quote instead of for one of a few characters
            if inputCharArray[i] == "\"" {
                tokenBuffer.append(inputCharArray[i])
                while i < inputLine.count {
                    if inputCharArray[i+1] != "\"" {
                        tokenBuffer.append(inputCharArray[i+1])
                    } else {
                        tokenBuffer.append("\"") //Append that last quote
                        let newToken = BasicToken(tokenBuffer) //Create the new token
                        tokenArray.append(newToken) // Append it to the array
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
                    }
                    i += 1
                }
            }
            
            
            
            i += 1 //Pretend we're a for loop and increment the index.
        }
        
        //Finally, at the end of the line, add an end-of-line token.
        tokenArray.append(BasicToken.endOfLineToken())
        return tokenArray
    }
    
}
