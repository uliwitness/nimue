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

fileprivate func CreateInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 1 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    try printInstructionOutput.append("CREATE CALLED WITH: object type \"\(args[0].string(stack: context.stack))\"")
    if args.count > 1 {
        try printInstructionOutput.append(", name \"\(args[1].string(stack: context.stack))\"")
    }
    printInstructionOutput.append("\n")
}


class HyperTalkTests: XCTestCase {
    var tokenizer: Tokenizer!
    var parser: Parser!
    
    func runScript(_ text: String, filePath: String, commands: [String:RunContext.BuiltInFunction] = [:], functions: [String:RunContext.BuiltInFunction] = [:]) throws -> (Script, RunContext, Variant?) {
        printInstructionOutput = ""
        try tokenizer.addTokens(for: text, filePath: filePath)
        try parser.parse(tokenizer)
        var context = RunContext(script: parser.script)
        do {
            context.builtinCommands["output"] = PrintInstructionFunc
            for (key, value) in commands {
                context.builtinCommands[key] = value
            }
            for (key, value) in functions {
                context.builtinFunctions[key] = value
            }
            try context.run("main", isCommand: true)
//        } catch RuntimeError.unknownMessage(let name, let isCommand) {
//            throw RuntimeError.unknownMessage(name, isCommand: isCommand) // suppress log message below for common, obvious errors.
        } catch {
            print("error = \(error) context = \(context)")
            throw error
        }
        if context.stack.count > 1 { throw RuntimeError.stackNotCleanedUpAtEndOfCall(exessElementCount: context.stack.count - 1) }
        return (parser.script, context, context.stack.last)
    }
    
    override func setUp() {
        tokenizer = Tokenizer()
        parser = Parser()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testEmptyFunctionCall() throws {
        let (script, _, result) = try runScript("""
on main
end main
""", filePath: #function)
        XCTAssertEqual(script.commandStarts.count, 1)
        let mainFunc = script.commandStarts["main"]!
        XCTAssertEqual(mainFunc.firstInstruction, 0)
        XCTAssertEqual(mainFunc.variables.numLocals, 1)
        XCTAssertEqual(mainFunc.variables.mappings.count, 1)
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction], ReserveStackInstruction(valueCount: 1)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 1], PushUnsetInstruction()))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 2], ReturnInstruction(isCommand: true)))
        XCTAssertEqual(result, Variant())
    }
    
    func testAssignment() throws {
        let (script, _, result) = try runScript("""
    on main
        put "foo" into myFoo
    end main
    """, filePath: #function)
        
        XCTAssertEqual(script.commandStarts.count, 1)
        let mainFunc = script.commandStarts["main"]!
        XCTAssertEqual(mainFunc.firstInstruction, 0)
        XCTAssertEqual(mainFunc.variables.numLocals, 2)
        XCTAssertEqual(mainFunc.variables.mappings.count, 2)
        XCTAssert(equalInstructions(mainFunc.variables.mappings["myFoo"]!, StackValueBPRelativeInstruction(index: 3)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction], ReserveStackInstruction(valueCount: 2)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 1], StackValueBPRelativeInstruction(index: 3)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 2], PushStringInstruction(string: "into")))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 3], PushStringInstruction(string: "foo")))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 4], PushParameterCountInstruction(parameterCount: 3)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 5], CallInstruction(message: "put", isCommand: true)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 6], PushUnsetInstruction()))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 7], ReturnInstruction(isCommand: true)))
        XCTAssertEqual(result, Variant())
    }
    
    func testParameters() throws {
        let (script, _, result) = try runScript("""
    on main arg1, arg2
    end main
    """, filePath: #function)
        
        XCTAssertEqual(script.commandStarts.count, 1)
        let mainFunc = script.commandStarts["main"]!
        XCTAssertEqual(mainFunc.firstInstruction, 0)
        XCTAssertEqual(mainFunc.variables.numLocals, 1)
        XCTAssertEqual(mainFunc.variables.mappings.count, 3)
        XCTAssert(equalInstructions(mainFunc.variables.mappings["arg1"]!, ParameterInstruction(index: 1)))
        XCTAssert(equalInstructions(mainFunc.variables.mappings["arg2"]!, ParameterInstruction(index: 2)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction], ReserveStackInstruction(valueCount: 1)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 1], PushUnsetInstruction()))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 2], ReturnInstruction(isCommand: true)))
        XCTAssertEqual(result, Variant())
    }

    func testSubHandlerCall() throws {
        let (script, _, result) = try runScript("""
    on subby arg1, arg2
        output arg1
        output arg2
    end subby
    
    on main
        subby "foo"
    end main
    """, filePath: #function)
        
        XCTAssertEqual(script.commandStarts.count, 2)
        let subFunc = script.commandStarts["subby"]!
        XCTAssertEqual(subFunc.firstInstruction, 0)
        XCTAssertEqual(subFunc.variables.numLocals, 1)
        XCTAssertEqual(subFunc.variables.mappings.count, 3)
        XCTAssert(equalInstructions(subFunc.variables.mappings["arg1"]!, ParameterInstruction(index: 1)))
        XCTAssert(equalInstructions(subFunc.variables.mappings["arg2"]!, ParameterInstruction(index: 2)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction], ReserveStackInstruction(valueCount: 1)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 1], ParameterInstruction(index: 1)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 2], PushParameterCountInstruction(parameterCount: 1)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 3], CallInstruction(message: "output", isCommand: true)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 4], ParameterInstruction(index: 2)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 5], PushParameterCountInstruction(parameterCount: 1)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 6], CallInstruction(message: "output", isCommand: true)))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 7], PushUnsetInstruction()))
        XCTAssert(equalInstructions(script.instructions[subFunc.firstInstruction + 8], ReturnInstruction(isCommand: true)))
        let mainFunc = script.commandStarts["main"]!
        XCTAssertEqual(mainFunc.firstInstruction, 9)
        XCTAssertEqual(mainFunc.variables.numLocals, 1)
        XCTAssertEqual(mainFunc.variables.mappings.count, 1)
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction], ReserveStackInstruction(valueCount: 1)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 1], PushStringInstruction(string: "foo")))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 2], PushParameterCountInstruction(parameterCount: 1)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 3], CallInstruction(message: "subby", isCommand: true)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 4], PushUnsetInstruction()))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 5], ReturnInstruction(isCommand: true)))
        XCTAssertEqual(result, Variant())
    }
    
    func testSomeExpressions() throws {
        _ = try runScript("""
on doThang appName, argument, arg2, arg3
    output "It works!" & " sometimes... " & appName && argument && "'" & arg3 & "'"
    --put "message:" && "foo" into fooLocalVar
    output fooLocalVar
end doThang

on main
    local myLocalVar
    doThang "Hello, world!", 1, 42.5
    put 1 + 2 * 3 - 4 * 5 into otherVar
    output otherVar
end main
""", filePath: #function)
        
        XCTAssertEqual(printInstructionOutput, """
It works! sometimes... Hello, world! 1 ''
fooLocalVar
-13

""")
    }
        
    func testMultiLineConditionalExpressionTrue() throws {
        _ = try runScript("""
on main
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
on main
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
on main
    output "before"
    if true then output "true" else output "false"
    output "after"
end main
""", filePath: #function)
        
        XCTAssertEqual(printInstructionOutput, "before\ntrue\nafter\n")
    }

    func testOneLineConditionalExpressionFalse() throws {
        _ = try runScript("""
on main
    output "before"
    if false then output "true" else output "false"
    output "after"
end main
""", filePath: #function)
        
        XCTAssertEqual(printInstructionOutput, "before\nfalse\nafter\n")
    }

    func testWrappedOneLineConditionalExpressionTrue() throws {
        _ = try runScript("""
on main
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
on main
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
on main
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
on main
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

    func testForLoop() throws {
        _ = try runScript("""
on main
    output "before"
    repeat for 5 times
        output "looping"
    end repeat
    output "after"
end main
""", filePath: #function)

        XCTAssertEqual(printInstructionOutput, "before\nlooping\nlooping\nlooping\nlooping\nlooping\nafter\n")
    }
    
    func testRepeatWithLoop() throws {
        _ = try runScript("""
on main
    output "before"
    repeat with x from 1 to 10
        output "looping" && x
    end repeat
    output "after"
end main
""", filePath: #function)

        XCTAssertEqual(printInstructionOutput, "before\nlooping 1\nlooping 2\nlooping 3\nlooping 4\nlooping 5\nlooping 6\nlooping 7\nlooping 8\nlooping 9\nlooping 10\nafter\n")
    }

    func testCommandHandlerTopLevelReturnValue() throws {
        let (script, _, result) = try runScript("""
on main
    return "The Outer Worlds"
    output "ignored"
end main
""", filePath: #function)
        XCTAssertEqual(script.commandStarts.count, 1)
        let mainFunc = script.commandStarts["main"]!
        XCTAssertEqual(mainFunc.firstInstruction, 0)
        XCTAssertEqual(mainFunc.variables.numLocals, 1)
        XCTAssertEqual(mainFunc.variables.mappings.count, 1)
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction], ReserveStackInstruction(valueCount: 1)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 1], PushStringInstruction(string: "The Outer Worlds")))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 2], ReturnInstruction(isCommand: true)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 3], PushStringInstruction(string: "ignored")))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 4], PushParameterCountInstruction(parameterCount: 1)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 5], CallInstruction(message: "output", isCommand: true)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 6], PushUnsetInstruction()))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 7], ReturnInstruction(isCommand: true)))
        XCTAssertEqual(result, Variant("The Outer Worlds"))
    }

    func testCommandHandlerTopLevelNoReturnValue() throws {
        let (script, _, result) = try runScript("""
on main
    return
    output "ignored"
end main
""", filePath: #function)
        XCTAssertEqual(script.commandStarts.count, 1)
        let mainFunc = script.commandStarts["main"]!
        XCTAssertEqual(mainFunc.firstInstruction, 0)
        XCTAssertEqual(mainFunc.variables.numLocals, 1)
        XCTAssertEqual(mainFunc.variables.mappings.count, 1)
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction], ReserveStackInstruction(valueCount: 1)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 1], PushUnsetInstruction()))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 2], ReturnInstruction(isCommand: true)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 3], PushStringInstruction(string: "ignored")))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 4], PushParameterCountInstruction(parameterCount: 1)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 5], CallInstruction(message: "output", isCommand: true)))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 6], PushUnsetInstruction()))
        XCTAssert(equalInstructions(script.instructions[mainFunc.firstInstruction + 7], ReturnInstruction(isCommand: true)))
        XCTAssertEqual(result, Variant())

        XCTAssertEqual(printInstructionOutput, "")
    }
        
    func testCommandCallResult() throws {
        let (_, _, result) = try runScript("""
on quoted str
    return "'" & str & "'"
end quoted

on main
    quoted "yay!"
    output result
end main
""", filePath: #function)
        XCTAssertEqual(result, Variant())

        XCTAssertEqual(printInstructionOutput, "'yay!'\n")
    }
    
    func testFunctionCallAndConstants() throws {
        let (_, _, result) = try runScript("""
function quoted str
    return quote & str & quote
end quoted

on main
    output quoted("yay!")
end main
""", filePath: #function)
        XCTAssertEqual(result, Variant())

        XCTAssertEqual(printInstructionOutput, "\"yay!\"\n")
    }
            
    func testUndefinedCommandCall() throws {
        do {
            _ = try runScript("""
on quoted str
    return "'" & str & "'"
end quoted

on main
    fubar "yay!"
    output result
end main
""", filePath: #function)
            XCTFail("Expected a RuntimeError.unknownMessage exception")
        } catch RuntimeError.unknownMessage(let name, let isCommand) {
            XCTAssertEqual(name, "fubar")
            XCTAssertEqual(isCommand, true)
        }

        XCTAssertEqual(printInstructionOutput, "")
    }
    
    func testUndefinedFunctionCall() throws {
        do {
            _ = try runScript("""
function quoted str
    return "'" & str & "'"
end quoted

on main
    output fubar("yay!")
end main
""", filePath: #function)
            XCTFail("Expected a RuntimeError.unknownMessage exception")
        } catch RuntimeError.unknownMessage(let name, let isCommand) {
            XCTAssertEqual(name, "fubar")
            XCTAssertEqual(isCommand, false)
        }

        XCTAssertEqual(printInstructionOutput, "")
    }
    
    func testSeparateFunctionCommandNamespaces() throws {
        do {
            _ = try runScript("""
on quoted str
    return "'" & str & "'"
end quoted

on main
    output quoted("yay!")
end main
""", filePath: #function)
            XCTFail("Expected a RuntimeError.unknownMessage exception")
        } catch RuntimeError.unknownMessage(let name, let isCommand) {
            XCTAssertEqual(name, "quoted")
            XCTAssertEqual(isCommand, false)
        }

        XCTAssertEqual(printInstructionOutput, "")
    }

        
    func testSeparateCommandFunctionNamespaces() throws {
        do {
            _ = try runScript("""
function quoted str
    return "'" & str & "'"
end quoted

on main
    quoted "yay!"
    output result
end main
""", filePath: #function)
            XCTFail("Expected a RuntimeError.unknownMessage exception")
        } catch RuntimeError.unknownMessage(let name, let isCommand) {
            XCTAssertEqual(name, "quoted")
            XCTAssertEqual(isCommand, true)
        }

        XCTAssertEqual(printInstructionOutput, "")
    }
    
    func testLengthProperty() throws {
        let (_, _, result) = try runScript("""
on main
    return length of "Four"
end main
""", filePath: #function)
        XCTAssertEqual(result, Variant(4))
    }
    
    func testCreateCommand() throws {
        let (_, _, result) = try runScript("""
on main
    create button "OK"
    create field
end main
""", filePath: #function, commands: ["create": CreateInstructionFunc])
        XCTAssertEqual(result, Variant())
       
        XCTAssertEqual(printInstructionOutput, "CREATE CALLED WITH: object type \"button\", name \"OK\"\nCREATE CALLED WITH: object type \"field\"\n")
    }
}
