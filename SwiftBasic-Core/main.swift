//
//  main.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/4/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

print("Hello, World!")


let lexer = BasicLexer()

do {
    let tokens = try lexer.getTokens(inputLine: "10 PRINT \"HELLO WORLD\"")
    print(tokens)
} catch {
    print(error)
}
