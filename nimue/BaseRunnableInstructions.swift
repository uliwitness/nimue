enum RuntimeError: Error {
    case stackIndexOutOfRange
    case tooFewOperands
    case zeroDivision
    case unknownMessage(_ name: String)
    case unknownInstruction(_ name: String)
}

func PrintInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    var str = ""
    for arg in args {
        str.append(arg.string(stack: context.stack))
    }
    print("\(str)");
}

public struct RunContext {
    var script: Script
    var currentInstruction: Int = 0 // Program Counter (PC)
    
    var stack = [Variant]()
    var backPointer: Int = 0 // (BP) End of parameters/start of local variables.
    
    mutating func run(_ handler: String, _ params: Variant...) throws {
        for param in params.reversed() {
            stack.append(param)
        }
        stack.append(Variant(params.count))
        currentInstruction = script.functionStarts[handler]?.firstInstruction ?? -1
        backPointer = 1

        stack.append(Variant(-1))
        stack.append(Variant(-1))
        
        while currentInstruction >= 0 {
            guard let currInstr = script.instructions[currentInstruction] as? RunnableInstruction else { throw RuntimeError.unknownInstruction("\(script.instructions[currentInstruction])") }
            try! currInstr.run(&self)
        }
    }
        
    static var builtinFunctions: [String:(_ : [Variant], _: inout RunContext) throws -> Void] = ["put": PrintInstructionFunc]
}

protocol RunnableInstruction {
    func run(_ context: inout RunContext) throws
}

extension RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        fatalError("Unknown instruction \(self)")
    }
}

extension PushStringInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        context.stack.append(Variant(string))
        context.currentInstruction += 1
    }
}

extension PushIntegerInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        context.stack.append(Variant(integer))
        context.currentInstruction += 1
    }
}

extension PushDoubleInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        context.stack.append(Variant(double))
        context.currentInstruction += 1
    }
}

extension AddInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let paramCount = context.stack.popLast()?.integer(stack: context.stack), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        guard let arg1 = context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        guard let arg2 = context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }

        context.stack.append(Variant(arg1 + arg2))
        context.currentInstruction += 1
    }
}

extension SubtractInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let paramCount = context.stack.popLast()?.integer(stack: context.stack), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        guard let arg1 = context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        guard let arg2 = context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }

        context.stack.append(Variant(arg1 - arg2))
        context.currentInstruction += 1
    }
}

extension MultiplyInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let paramCount = context.stack.popLast()?.integer(stack: context.stack), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        guard let arg1 = context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        guard let arg2 = context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }

        context.stack.append(Variant(arg1 * arg2))
        context.currentInstruction += 1
    }
}

extension DivideInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let paramCount = context.stack.popLast()?.integer(stack: context.stack), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        guard let arg1 = context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        guard let arg2 = context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        
        if arg2 == 0.0 {
            throw RuntimeError.zeroDivision
        }

        context.stack.append(Variant(arg1 / arg2))
        context.currentInstruction += 1
    }
}

extension ConcatenateInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let paramCount = context.stack.popLast()?.integer(stack: context.stack), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        guard let arg1 = context.stack.popLast()?.string(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        guard let arg2 = context.stack.popLast()?.string(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        
        context.stack.append(Variant(arg1 + arg2))
        context.currentInstruction += 1
    }
}

extension CopyInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let paramCount = context.stack.popLast()?.integer(stack: context.stack), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        
        guard let arg1 = context.stack.popLast() else { throw RuntimeError.tooFewOperands }
        if let index = arg1.referenceIndex(stack: context.stack) {
            context.stack[context.stack.count - 1] = context.stack[index]
        } else {
            context.stack[context.stack.count - 1] = arg1
        }
        context.currentInstruction += 1
    }
}

extension JumpByInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        context.currentInstruction += instructionCount
    }
}

extension CallInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        if let destinationInstruction = context.script.functionStarts[message]?.firstInstruction {
            let newBackPointer = context.stack.count
            context.stack.append(Variant(context.currentInstruction + 1))
            context.stack.append(Variant(context.backPointer))
            context.backPointer = newBackPointer
            context.currentInstruction = destinationInstruction
        } else if let builtinFunction = RunContext.builtinFunctions[message] {
            let paramCount = context.stack.popLast()!.integer(stack: context.stack)
            var args = [Variant]()
            for _ in 0 ..< paramCount {
                args.append(context.stack.popLast()!)
            }
            try builtinFunction(args, &context)
            context.currentInstruction += 1
        } else {
            throw RuntimeError.unknownMessage(message)
        }
    }
}

extension ReturnInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        context.backPointer = context.stack.popLast()!.integer(stack: context.stack)
        context.currentInstruction = context.stack.popLast()!.integer(stack: context.stack)
        let paramCount = context.stack.popLast()!.integer(stack: context.stack)
        for _ in 0 ..< paramCount {
            context.stack.removeLast()
        }
    }
}

extension StackValueBPRelativeInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        let actualIndex = context.backPointer + index
        guard actualIndex >= 0 && actualIndex < context.stack.count else { throw RuntimeError.stackIndexOutOfRange }
        context.stack.append(Variant(referenceIndex: actualIndex))
        context.currentInstruction += 1
    }
}

extension ParameterInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        if context.stack[context.backPointer - 1].integer(stack: context.stack) < index {
            context.stack.append(Variant())
        } else {
            context.stack.append(Variant(referenceIndex: context.backPointer - 1 - index)) // - 1 because param count is first.
        }
        context.currentInstruction += 1
    }
}
