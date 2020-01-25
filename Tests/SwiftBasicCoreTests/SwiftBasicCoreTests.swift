import XCTest
@testable import SwiftBasicCore

final class SwiftBasicCoreTests: XCTestCase {
    
    static var allTests = [
        ("testArithmetic", testArithmetic),
    ]
    
    /// Tests the arithmetic operators.
    func testArithmetic() {
        let parser = BasicParser()
        let testConsole = TestConsole()
        parser.delegate = testConsole
        let a = Int.random(in: 0...10)
        let b = Int.random(in: 0...10)
        testConsole.inputBuffer = ["\(a)", "\(b)"]
        let code = """
        INPUT A, B
        PRINT A, " + ", B, " == ", A + B
        PRINT A, " - ", B, " == ", A - B
        PRINT A, " * ", B, " == ", A * B
        IF B == 0 THEN GOTO SkipDivision
        PRINT A, " / ", B, " == ", A / B
        PRINT A, " % ", B, " == ", A % B
        SkipDivision
        PRINT A, " ** ", B, " == ", A ** B
        """
        
        var expectedOutput = """
        \(a) + \(b) == \(a + b)
        \(a) - \(b) == \(a - b)
        \(a) * \(b) == \(a * b)\n
        """
        if b != 0 {
            expectedOutput += """
            \(a) / \(b) == \(a / b)
            \(a) % \(b) == \(a % b)\n
            """
        }
        expectedOutput += """
        \(a) ** \(b) == \(a ** b)
        
        """
        
        try! parser.loadCode(fromString: code)
        try! parser.run()
        
        print("Expected:\n\"\(expectedOutput)\"")
        print("Actual:\n\"\(testConsole.output)\"")
        
        XCTAssert(testConsole.output == expectedOutput)
    }
    
    func testEndFunction(){
        let parser = BasicParser()
        let testConsole = TestConsole()
        parser.delegate = testConsole
        let code = """
        10 GOTO 20
        20 GOTO 10
        """
        try! parser.loadCode(fromString: code)
        DispatchQueue.main.async {
            try! parser.run()
        }
        usleep(1000)
        parser.endProgram()
    }
    
    func testEndKeyword(){
        let parser = BasicParser()
        let testConsole = TestConsole()
        parser.delegate = testConsole
        let code = """
        END
        PRINT "This shouldn't be printed"
        """
        try! parser.loadCode(fromString: code)
        try! parser.run()
        XCTAssert(testConsole.output == "")
    }
}
