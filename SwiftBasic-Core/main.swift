//
//  main.swift
//  SwiftBasic-Core
//
//  Created by Zaccari Silverman on 1/4/20.
//  Copyright © 2020 Zaccari Silverman. All rights reserved.
//

import Foundation

/// An example of a class that conforms to BasicDelegate; it handles console I/O for the BasicParser.
class Console : BasicDelegate {
    func handlePrintStatement(stringToPrint: String) { print(stringToPrint) }
    func handleInput() -> String { readLine() ?? "" }
}

// Prints 10 copies of "HELLO WORLD"
let code = "LET I = 0\n10 PRINT \"Hello, World!\"\nLET I = I + 1\nIF I < 10 THEN GOTO 10"
let console = Console()
let parser = BasicParser()
parser.delegate = console

try parser.loadCode(fromString: code)
try parser.run()

// Multiplies the 2 numbers you input, even if one is an integer and the other is a double/float
let code2 = "INPUT A, B\nPRINT A * B"
try parser.loadCode(fromString: code2)
try parser.run()

// Demonstrates the use of GOSUB.
let code3 = "PRINT \"Want to GOSUB? 0 for yes.\"\nINPUT A\nIF A == 0 THEN GOSUB FunkySubroutine\nEND\nFunkySubroutine PRINT \"🎉HELLO from the Subroutine!🎉\"\nRETURN"
try parser.loadCode(fromString: code3)
try parser.run()


