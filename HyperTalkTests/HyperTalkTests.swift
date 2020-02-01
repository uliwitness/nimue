import XCTest
@testable import HyperTalk

class HyperTalkTests: XCTestCase {
    let tokenizer = Tokenizer()
    let parser = Parser()

    func runScript(_ text: String) throws -> (Script, RunContext) {
        try tokenizer.addTokens(for: text)
        try parser.parse(tokenizer)
        var context = RunContext(script: parser.script)
        try! context.run("main")
        return (parser.script, context)
    }
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testEmptyFunctionCall() throws {
        let (script, context) = try runScript("""
on main
end main
""")
        XCTAssertEqual(script.functionStarts.count, 1)
        XCTAssertEqual(script.functionStarts["main"]?.firstInstruction, 0)
        XCTAssertEqual(script.functionStarts["main"]?.variables.numVariables, 0)
        XCTAssertEqual(script.functionStarts["main"]?.variables.mappings.count, 0)
        XCTAssertEqual(context.stack.count, 0)
    }
    
    func testAssignment() throws {
        let (script, context) = try runScript("""
    on main
        put "foo" into myFoo
    end main
    """)
        
        XCTAssertEqual(script.functionStarts.count, 1)
        XCTAssertEqual(script.functionStarts["main"]?.firstInstruction, 0)
        XCTAssertEqual(script.functionStarts["main"]?.variables.numVariables, 1)
        XCTAssertEqual(script.functionStarts["main"]?.variables.mappings.count, 1)
        let varInstruction = script.functionStarts["main"]?.variables.mappings["myFoo"] as! StackValueBPRelativeInstruction
        XCTAssertEqual(varInstruction.index, 2)
        XCTAssertEqual(context.stack.count, 0)
    }

}
