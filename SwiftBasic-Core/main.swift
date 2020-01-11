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
    func handleInput() -> String {
        while true {
            if let returnValue = readLine(), returnValue != "" { return returnValue }
        }
    }
    func handleClear() { print("\u{001B}[2J") } // This doesn't work in XCode's terminal, but should work in a normal one.
    func handleList(listOfSymbols: [(String, String)]) {
        for symbol in listOfSymbols { print("\(symbol.0) == \(symbol.1)") }
    }
}

// Prints 10 copies of "HELLO WORLD"
let code = "LET I = 0\n10 PRINT \"Hello, World!\"\nI += 1\nIF I < 10 THEN GOTO 10"
let console = Console()
let parser = BasicParser()
parser.delegate = console

//try parser.loadCode(fromString: code)
//try parser.run()

// Demonstrates the supported mathematical operators
let code2 = """
PRINT "Input two numbers and I'll perform all kinds of math on them!"
INPUT A, B
LIST
PRINT A, " + ", B, " == ", A + B
PRINT A, " - ", B, " == ", A - B
PRINT A, " * ", B, " == ", A * B
IF B == 0 THEN GOTO SkipDivision
PRINT A, " / ", B, " == ", A / B
PRINT A, " % ", B, " == ", A % B
SkipDivision
PRINT A, " ** ", B, " == ", A ** B
"""
try parser.loadCode(fromString: code2)
try parser.run()

// Demonstrates the use of GOSUB.
let code3 = "print \"Want to GOSUB? 0 for yes.\"\nINPUT variable\nIF variable == 0 THEN GOSUB FunkySubroutine🎉\nEND\nFunkySubroutine🎉 PRINT \"🎉HELLO from the Subroutine!🎉\"\nRETURN"
try parser.loadCode(fromString: code3)
try parser.run()

// Demonstrates an alternate assignment.
let code4 = "a = pi\na /= 4\nprint a\nclear"
try parser.loadCode(fromString: code4)
try parser.run()

// TODO - Make actual tests with XCTest.
