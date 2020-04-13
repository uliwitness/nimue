enum RuntimeError: Error {
    case stackIndexOutOfRange
    case tooFewOperands
    case tooManyOperands
    case zeroDivision
    case unknownMessage(_ name: String)
    case unknownInstruction(_ name: String)
    case invalidPutDestination
}

func PrintInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count == 1 {
        try print("\(args[0].string(stack: context.stack))")
        return
    } else if args.count < 1 {
        throw RuntimeError.tooFewOperands
    } else {
        throw RuntimeError.tooManyOperands
    }
}

func PutInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 3 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 3 {
        throw RuntimeError.tooManyOperands
    }
    if let index = args[2].referenceIndex(stack: context.stack) {
        context.stack[index] = args[0]
    } else {
        throw RuntimeError.invalidPutDestination
    }
}

func SubtractInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let sum = try args[0].double(stack: context.stack) - args[1].double(stack: context.stack)
    context.stack.append(Variant(sum))
}

func AddInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let sum = try args[0].double(stack: context.stack) + args[1].double(stack: context.stack)
    context.stack.append(Variant(sum))
}

func MultiplyInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let sum = try args[0].double(stack: context.stack) * args[1].double(stack: context.stack)
    context.stack.append(Variant(sum))
}

func DivideInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let sum = try args[0].double(stack: context.stack) * args[1].double(stack: context.stack)
    context.stack.append(Variant(sum))
}

func ConcatenateInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let concatenated = try args[0].string(stack: context.stack) + args[1].string(stack: context.stack)
    context.stack.append(Variant(concatenated))
}

func ConcatenateSpaceInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let concatenated = try args[0].string(stack: context.stack) + " " + args[1].string(stack: context.stack)
    context.stack.append(Variant(concatenated))
}


public struct RunContext {
    public typealias BuiltInFunction = (_ : [Variant], _: inout RunContext) throws -> Void
    
    public var script: Script
    public var currentInstruction: Int = 0 // Program Counter (PC)
    
    public var stack = [Variant]()
    public var backPointer: Int = 0 // (BP) End of parameters/start of local variables.
    
    public init(script: Script) {
        self.script = script
    }
    
    public mutating func run(_ handler: String, _ params: Variant...) throws {
        for param in params.reversed() {
            stack.append(param)
        }
        stack.append(Variant(parameterCount: params.count))
        currentInstruction = script.functionStarts[handler]?.firstInstruction ?? -1
        backPointer = 1

        stack.append(Variant(instructionIndex: -1))
        stack.append(Variant(stackIndex: -1))
        
        while currentInstruction >= 0 {
            guard let currInstr = script.instructions[currentInstruction] as? RunnableInstruction else { throw RuntimeError.unknownInstruction("\(script.instructions[currentInstruction])") }
            try! currInstr.run(&self)
        }
    }
        
    public var builtinFunctions: [String:BuiltInFunction] = [
        "output": PrintInstructionFunc,
        "put": PutInstructionFunc,
        "-": SubtractInstructionFunc,
        "+": AddInstructionFunc,
        "*": MultiplyInstructionFunc,
        "/": DivideInstructionFunc,
        "&": ConcatenateInstructionFunc,
        "&&": ConcatenateSpaceInstructionFunc]
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

extension PushParameterCountInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        context.stack.append(Variant(parameterCount: parameterCount))
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
        guard let paramCount = try context.stack.popLast()?.parameterCount(), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        guard let arg1 = try context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        guard let arg2 = try context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }

        context.stack.append(Variant(arg1 + arg2))
        context.currentInstruction += 1
    }
}

extension SubtractInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let paramCount = try context.stack.popLast()?.parameterCount(), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        guard let arg1 = try context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        guard let arg2 = try context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }

        context.stack.append(Variant(arg1 - arg2))
        context.currentInstruction += 1
    }
}

extension MultiplyInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let paramCount = try context.stack.popLast()?.parameterCount(), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        guard let arg1 = try context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        guard let arg2 = try context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }

        context.stack.append(Variant(arg1 * arg2))
        context.currentInstruction += 1
    }
}

extension DivideInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let paramCount = try context.stack.popLast()?.parameterCount(), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        guard let arg1 = try context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        guard let arg2 = try context.stack.popLast()?.double(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        
        if arg2 == 0.0 {
            throw RuntimeError.zeroDivision
        }

        context.stack.append(Variant(arg1 / arg2))
        context.currentInstruction += 1
    }
}

extension ConcatenateInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let paramCount = try context.stack.popLast()?.parameterCount(), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        guard let arg1 = try context.stack.popLast()?.string(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        guard let arg2 = try context.stack.popLast()?.string(stack: context.stack) else { throw RuntimeError.tooFewOperands }
        
        context.stack.append(Variant(arg1 + arg2))
        context.currentInstruction += 1
    }
}

extension CopyInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let paramCount = try context.stack.popLast()?.parameterCount(), paramCount == 2 else { throw RuntimeError.tooFewOperands }
        
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
        context.currentInstruction += 1
        context.currentInstruction += instructionCount
    }
}

extension JumpByIfTrueInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        context.currentInstruction += 1
        if try context.stack.popLast()!.boolean(stack: context.stack) {
            context.currentInstruction += instructionCount
        }
    }
}

extension JumpByIfFalseInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        context.currentInstruction += 1
        if try !context.stack.popLast()!.boolean(stack: context.stack) {
            context.currentInstruction += instructionCount
        }
    }
}

extension CallInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        if let destinationInstruction = context.script.functionStarts[message]?.firstInstruction {
            let newBackPointer = context.stack.count
            context.stack.append(Variant(instructionIndex: context.currentInstruction + 1))
            context.stack.append(Variant(stackIndex: context.backPointer))
            context.backPointer = newBackPointer
            context.currentInstruction = destinationInstruction
        } else if let builtinFunction = context.builtinFunctions[message] {
            do {
                let paramCount = try context.stack.popLast()!.parameterCount()
                var args = [Variant]()
                for _ in 0 ..< paramCount {
                    args.append(context.stack.popLast()!)
                }
                try builtinFunction(args, &context)
                context.currentInstruction += 1
            } catch {
                print("error = \(error)\ncontext = \(context)")
                throw error
            }
        } else {
            throw RuntimeError.unknownMessage(message)
        }
    }
}

extension ReturnInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        for _ in 0 ..< numVariables {
            context.stack.removeLast()
        }
        context.backPointer = try context.stack.popLast()!.stackIndex()
        context.currentInstruction = try context.stack.popLast()!.instructionIndex()
        let paramCount = try context.stack.popLast()!.parameterCount()
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
        if try context.stack[context.backPointer - 1].parameterCount() < index {
            context.stack.append(Variant())
        } else {
            context.stack.append(Variant(referenceIndex: context.backPointer - 1 - index)) // - 1 because param count is first.
        }
        context.currentInstruction += 1
    }
}

extension ReserveStackInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        context.stack.append(contentsOf: Array(repeating: Variant(), count: valueCount))
        context.currentInstruction += 1
    }
}
