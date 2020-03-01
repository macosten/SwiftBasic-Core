import XCTest
@testable import SwiftBasicCore

final class SwiftBasicCoreTests: XCTestCase {
    
    static var allTests = [
        ("testArithmetic", testArithmetic),
        ("testEndFunction", testEndFunction),
        ("testEndKeyword", testEndKeyword),
        ("testAssigningDoubles", testAssigningDoubles),
        ("testStringOperators", testStringOperators)
    ]
    
    /// Tests the arithmetic operators. This also tests INPUT and PRINT.
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
        
        XCTAssert(testConsole.output == expectedOutput)
    }
    
    /// Test BasicParser.endProgram(), meant to be called by another function on another thread.
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
    
    /// Test the END Basic keyword, which should terminate the program.
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
    
    /// Test the assignment of doubles (to symbols) in Basic.
    func testAssigningDoubles() {
        let parser = BasicParser()
        let testConsole = TestConsole()
        parser.delegate = testConsole
        let code = """
        I = .123
        J = 0.234
        K = 456.789
        PRINT I, " ", J, " ", K
        """
        try! parser.loadCode(fromString: code)
        try! parser.run()
        // print(testConsole.output)
        XCTAssert(testConsole.output == "0.123 0.234 456.789\n")
    }
    
    /// Test the assignment of strings (to symbols) in Basic.
    func testAssigningStrings() {
        let parser = BasicParser()
        let testConsole = TestConsole()
        parser.delegate = testConsole
        
        let myName = "Zac"
        testConsole.inputBuffer = [myName]
        
        let code = """
        PRINT "What's your name?"
        INPUT A
        PRINT "Hello, ", A, "!"
        LET stringLiteral = "Welcome to SwiftBasicCore!"
        PRINT stringLiteral
        """
        
        try! parser.loadCode(fromString: code)
        try! parser.run()
        print(testConsole.output)
        XCTAssert(testConsole.output == "What's your name?\nHello, \(myName)!\nWelcome to SwiftBasicCore!\n")
    }
    
    /// Tests the string operators (plus and multiply) in Basic.
    func testStringOperators() {
        let parser = BasicParser()
        let testConsole = TestConsole()
        parser.delegate = testConsole
        
        let code = """
        string = "We like " + 2
        string += " eat "
        dessert = "🍪" * 5
        string += dessert
        print string + " ", 4.0 + " ever!"
        """
        
        try! parser.loadCode(fromString: code)
        try! parser.run()
        XCTAssert(testConsole.output == "We like 2 eat 🍪🍪🍪🍪🍪 4.0 ever!\n")
        
        testConsole.handleClear()
        
        let code2 = """
        dessert = "🍪"
        dessert *= 5
        print dessert
        dessert = 5
        dessert *= "🎂"
        print dessert
        print "🧁" * 5
        """
        
        try! parser.loadCode(fromString: code2)
        try! parser.run()
        XCTAssert(testConsole.output == "🍪🍪🍪🍪🍪\n🎂🎂🎂🎂🎂\n🧁🧁🧁🧁🧁\n")
        
    }

}
