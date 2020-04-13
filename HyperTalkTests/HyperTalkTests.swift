import XCTest
@testable import HyperTalk

fileprivate var printInstructionOutput = ""

fileprivate func PrintInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count == 1 {
        try printInstructionOutput.append("\(args[0].string(stack: context.stack))\n")
    } else if args.count < 1 {
        throw RuntimeError.tooFewOperands
    } else {
        throw RuntimeError.tooManyOperands
    }
}

class HyperTalkTests: XCTestCase {
    var tokenizer: Tokenizer!
    var parser: Parser!
    
    func runScript(_ text: String, filePath: String, functions: [String:RunContext.BuiltInFunction] = [:]) throws -> (Script, RunContext) {
        printInstructionOutput = ""
        try tokenizer.addTokens(for: text, filePath: filePath)
        try parser.parse(tokenizer)
        var context = RunContext(script: parser.script)
        context.builtinFunctions["output"] = PrintInstructionFunc
        for (key, value) in functions {
            context.builtinFunctions[key] = value
        }
        print("context = \(context)")
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
""", filePath: #function)
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
    """, filePath: #function)
        
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
    """, filePath: #function)
        
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
        output arg1
        output arg2
    end subby
    
    on main
        subby "foo"
    end main
    """, filePath: #function)
        
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
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 3], CallInstruction(message: "output")))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 4], ParameterInstruction(index: 2)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 5], PushParameterCountInstruction(parameterCount: 1)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 6], CallInstruction(message: "output")))
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
    
    func testSomeExpressions() throws {
        _ = try runScript("""
on doThang appName, argument, arg2, arg3
    output "It works!"
    output " sometimes... "
    output appName
    output argument
    output arg3
    --put "message:" && "foo" into fooLocalVar
    output fooLocalVar
end doThang

function main
    local myLocalVar
    doThang "Hello, world!", 1, 42.5
    put 1 + 2 * 3 - 4 * 5 into otherVar
    output otherVar
end main
""", filePath: #function)
        
        XCTAssertEqual(printInstructionOutput, """
It works!
 sometimes... 
Hello, world!
1

fooLocalVar
-13.0

""")
    }
        
    func testMultiLineConditionalExpressionTrue() throws {
        _ = try runScript("""
function main
    output "before"
    if true then
        output "true"
    else
        output "false"
    end if
    output "after"
end main
""", filePath: #function)
        
        XCTAssertEqual(printInstructionOutput, "before\ntrue\nafter\n")
    }

    func testMultiLineConditionalExpressionFalse() throws {
        _ = try runScript("""
function main
    output "before"
    if false then
        output "true"
    else
        output "false"
    end if
    output "after"
end main
""", filePath: #function)
        
        XCTAssertEqual(printInstructionOutput, "before\nfalse\nafter\n")
    }

    func testOneLineConditionalExpressionTrue() throws {
        _ = try runScript("""
function main
    output "before"
    if true then output "true" else output "false"
    output "after"
end main
""", filePath: #function)
        
        XCTAssertEqual(printInstructionOutput, "before\ntrue\nafter\n")
    }

    func testOneLineConditionalExpressionFalse() throws {
        _ = try runScript("""
function main
    output "before"
    if false then output "true" else output "false"
    output "after"
end main
""", filePath: #function)
        
        XCTAssertEqual(printInstructionOutput, "before\nfalse\nafter\n")
    }

    func testWrappedOneLineConditionalExpressionTrue() throws {
        _ = try runScript("""
function main
    output "before"
    if true
    then output "true"
    else output "false"
    output "after"
end main
""", filePath: #function)
        
        XCTAssertEqual(printInstructionOutput, "before\ntrue\nafter\n")
    }

    func testWrappedOneLineConditionalExpressionFalse() throws {
        _ = try runScript("""
function main
    output "before"
    if false
    then output "true"
    else output "false"
    output "after"
end main
""", filePath: #function)
        
        XCTAssertEqual(printInstructionOutput, "before\nfalse\nafter\n")
    }

    func testWhileLoopFalse() throws {
        _ = try runScript("""
function main
    output "before"
    repeat while false
        output "looping"
    end repeat
    output "after"
end main
""", filePath: #function)
        
        XCTAssertEqual(printInstructionOutput, "before\nafter\n")
    }

    func testWhileLoopCount() throws {
        _ = try runScript("""
function main
    output "before"
    put 5 into x
    repeat while x > 0
        output "looping" && x
        subtract 1 from x
    end repeat
    output "after"
end main
""", filePath: #function)

        XCTAssertEqual(printInstructionOutput, "before\nlooping 5\nlooping 4\nlooping 3\nlooping 2\nlooping 1\nafter\n")
    }
}
