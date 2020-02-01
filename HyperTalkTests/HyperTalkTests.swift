import XCTest
@testable import HyperTalk

class HyperTalkTests: XCTestCase {
    var tokenizer: Tokenizer!
    var parser: Parser!
    
    func runScript(_ text: String) throws -> (Script, RunContext) {
        try tokenizer.addTokens(for: text)
        try parser.parse(tokenizer)
        var context = RunContext(script: parser.script)
        try! context.run("main")
        return (parser.script, context)
    }
    
    override func setUp() {
        tokenizer = Tokenizer()
        parser = Parser()
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
        let mainFunc = script.functionStarts["main"]!
        XCTAssertEqual(mainFunc.firstInstruction, 0)
        XCTAssertEqual(mainFunc.variables.numLocals, 0)
        XCTAssertEqual(mainFunc.variables.mappings.count, 0)
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction], ReserveStackInstruction(valueCount: 0)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 1], ReturnInstruction(numVariables: 0)))
        XCTAssertEqual(context.stack.count, 0)
    }
    
    func testAssignment() throws {
        let (script, context) = try runScript("""
    on main
        put "foo" into myFoo
    end main
    """)
        
        XCTAssertEqual(script.functionStarts.count, 1)
        let mainFunc = script.functionStarts["main"]!
        XCTAssertEqual(mainFunc.firstInstruction, 0)
        XCTAssertEqual(mainFunc.variables.numLocals, 1)
        XCTAssertEqual(mainFunc.variables.mappings.count, 1)
        XCTAssert(equalInstructions(mainFunc.variables.mappings["myFoo"]!, StackValueBPRelativeInstruction(index: 2)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction], ReserveStackInstruction(valueCount: 1)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 1], StackValueBPRelativeInstruction(index: 2)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 2], PushStringInstruction(string: "into")))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 3], PushStringInstruction(string: "foo")))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 4], PushParameterCountInstruction(parameterCount: 3)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 5], CallInstruction(message: "put")))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 6], ReturnInstruction(numVariables: 1)))
        XCTAssertEqual(context.stack.count, 0)
    }
    
    func testParameters() throws {
        let (script, context) = try runScript("""
    on main arg1, arg2
    end main
    """)
        
        XCTAssertEqual(script.functionStarts.count, 1)
        let mainFunc = script.functionStarts["main"]!
        XCTAssertEqual(mainFunc.firstInstruction, 0)
        XCTAssertEqual(mainFunc.variables.numLocals, 0)
        XCTAssertEqual(mainFunc.variables.mappings.count, 2)
        XCTAssert(equalInstructions(mainFunc.variables.mappings["arg1"]!, ParameterInstruction(index: 1)))
        XCTAssert(equalInstructions(mainFunc.variables.mappings["arg2"]!, ParameterInstruction(index: 2)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction], ReserveStackInstruction(valueCount: 0)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 1], ReturnInstruction(numVariables: 0)))
        XCTAssertEqual(context.stack.count, 0)
    }

    func testSubHandlerCall() throws {
        let (script, context) = try runScript("""
    on subby arg1, arg2
        put arg1
        put arg2
    end subby
    
    on main
        subby "foo"
    end main
    """)
        
        XCTAssertEqual(script.functionStarts.count, 2)
        let subFunc = script.functionStarts["subby"]!
        XCTAssertEqual(subFunc.firstInstruction, 0)
        XCTAssertEqual(subFunc.variables.numLocals, 0)
        XCTAssertEqual(subFunc.variables.mappings.count, 2)
        XCTAssert(equalInstructions(subFunc.variables.mappings["arg1"]!, ParameterInstruction(index: 1)))
        XCTAssert(equalInstructions(subFunc.variables.mappings["arg2"]!, ParameterInstruction(index: 2)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction], ReserveStackInstruction(valueCount: 0)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 1], ParameterInstruction(index: 1)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 2], PushParameterCountInstruction(parameterCount: 1)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 3], CallInstruction(message: "put")))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 4], ParameterInstruction(index: 2)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 5], PushParameterCountInstruction(parameterCount: 1)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 6], CallInstruction(message: "put")))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 7], ReturnInstruction(numVariables: 0)))
        let mainFunc = script.functionStarts["main"]!
        XCTAssertEqual(mainFunc.firstInstruction, 8)
        XCTAssertEqual(mainFunc.variables.numLocals, 0)
        XCTAssertEqual(mainFunc.variables.mappings.count, 0)
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction], ReserveStackInstruction(valueCount: 0)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 1], PushStringInstruction(string: "foo")))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 2], PushParameterCountInstruction(parameterCount: 1)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 3], CallInstruction(message: "subby")))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 4], ReturnInstruction(numVariables: 0)))
        XCTAssertEqual(context.stack.count, 0)
    }
}
