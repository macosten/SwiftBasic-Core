import Foundation
import SwiftBasicCore

class TestConsole : BasicDelegate {
    var output = "" // This is the output, equivalent to what strings would be printed to a console.
    var inputBuffer = [String]() // Buffered pseudo-input; each element of this array is like a value returned from a call to readLine().
    
    func handlePrintStatement(stringToPrint: String) { output += (stringToPrint + "\n") }
    func handleInput() -> String { inputBuffer.removeFirst() }
    func handleClear() { output = "" }
    func handleList(listOfSymbols: [(String, String)]) {
        for symbol in listOfSymbols { handlePrintStatement(stringToPrint: "\(symbol.0) == \(symbol.1)") }
    }
}
