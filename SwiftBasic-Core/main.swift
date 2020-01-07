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


let tokens = lexer.getTokensForFileContents(input: "10 PRINT \"HELLO WORLD\"\n20 GOTO 10")
print(tokens)

var map = SymbolMap()
map.insert(name: "var", value: 10)
print(map.get(symbolNamed: "var")!.value)
