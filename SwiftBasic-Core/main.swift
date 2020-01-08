//
//  main.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/4/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

class Console : BasicDelegate {
    func handlePrintStatement(stringToPrint: String) { print(stringToPrint) }
    func handleInput() -> String { readLine() ?? "" }
}

print("Hello, World!")


func testSymbols() {
    let lexer = BasicLexer()


    let tokens = lexer.getTokensForFileContents(input: "10 PRINT \"HELLO WORLD\"\n20 GOTO 10")
    print(tokens)

    var map = SymbolMap()
    try! map.insert(name: "var", value: 10)
    print(map.get(symbolNamed: "var")!.value)

    do {
        print(try SymbolMap.Symbol(type: .integer, value: 10) + SymbolMap.Symbol(type: .double, value: 4.20))
        print(try SymbolMap.Symbol(type: .integer, value: 10) - SymbolMap.Symbol(type: .double, value: 4.20))
        print(try SymbolMap.Symbol(type: .integer, value: 10) * SymbolMap.Symbol(type: .double, value: 4.20))
        print(try SymbolMap.Symbol(type: .integer, value: 10) / SymbolMap.Symbol(type: .double, value: 4.20))
        
        
        print(try SymbolMap.Symbol(type: .integer, value: 10) / SymbolMap.Symbol(type: .integer, value: 0))
    } catch {
        print(error)
    }
}

let code = "LET I = 0\n10 PRINT \"HELLO WORLD\"\nLET I = I + 1\nIF I < 10 THEN GOTO 10"
let console = Console()
let parser = BasicParser()
parser.delegate = console

parser.loadCode(fromString: code)
try parser.run()

let code2 = "10 "
