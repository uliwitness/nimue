enum RuntimeError: Error {
    /// Internal error: Somebody referenced entries on the stack that do no longer exist.
    case stackIndexOutOfRange
    /// Too few parameters passed to a built-in function or operator.
    case tooFewOperands
    /// Too many parameters passed to a built-in function or operator.
    case tooManyOperands
    /// A divide command or operator was asked to do the impossible.
    case zeroDivision
    /// A command or function was called that isn't a known built-in or user-defined function.
    case unknownMessage(_ name: String, isCommand: Bool)
    /// Internal error: The parser generated an instruction that the runtime doesn't know how to execute.
    case unknownInstruction(_ name: String)
    /// The "put" command was asked to put into something that's not a variable, like a string constant.
    case invalidPutDestination
    /// Internal error: Something did not clean up the stack properly before returning from the top-level function.
    case stackNotCleanedUpAtEndOfCall(exessElementCount: Int)
}

/// Implement the "output" command. (Also used when "put" is used without a destination)
func PrintInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count == 1 {
        try print("\(args[0].string(stack: context.stack))")
    } else if args.count < 1 {
        throw RuntimeError.tooFewOperands
    } else {
        throw RuntimeError.tooManyOperands
    }
}

func PutInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count == 1 { // For HyperCard compatibility, let's accept put with 0 arguments as meaning "output".
        try PrintInstructionFunc(args, context: &context)
        return
    }
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

func AddCommandFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    if let index = args[1].referenceIndex(stack: context.stack) {
        if let a = try? context.stack[index].integerIfPossible(stack: context.stack), let b = try? args[0].integerIfPossible(stack: context.stack) {
            context.stack[index] = Variant(a + b)
        } else {
            try context.stack[index] = Variant(context.stack[index].double(stack: context.stack) + args[0].double(stack: context.stack))
        }
    } else {
        throw RuntimeError.invalidPutDestination
    }
}

func SubtractCommandFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    if let index = args[1].referenceIndex(stack: context.stack) {
        if let a = try? context.stack[index].integerIfPossible(stack: context.stack), let b = try? args[0].integerIfPossible(stack: context.stack) {
            context.stack[index] = Variant(a - b)
        } else {
            try context.stack[index] = Variant(context.stack[index].double(stack: context.stack) - args[0].double(stack: context.stack))
        }
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

func GreaterThanInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let comparisonBool = try args[0].double(stack: context.stack) > args[1].double(stack: context.stack)
    context.stack.append(Variant(comparisonBool))
}

func LessThanInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let comparisonBool = try args[0].double(stack: context.stack) < args[1].double(stack: context.stack)
    context.stack.append(Variant(comparisonBool))
}

func LessThanEqualInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let comparisonBool = try args[0].double(stack: context.stack) <= args[1].double(stack: context.stack)
    context.stack.append(Variant(comparisonBool))
}

func GreaterThanEqualInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let comparisonBool = try args[0].double(stack: context.stack) >= args[1].double(stack: context.stack)
    context.stack.append(Variant(comparisonBool))
}

func EqualInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let comparisonBool: Bool
    if let a = try? args[0].integer(stack: context.stack), let b = try? args[1].integer(stack: context.stack) {
        comparisonBool = a == b
    } else if let a = try? args[0].double(stack: context.stack), let b = try? args[1].double(stack: context.stack) {
        comparisonBool = abs(a - b) < 0.00001
    } else {
        comparisonBool = try args[0].string(stack: context.stack) == args[1].string(stack: context.stack)
    }
    context.stack.append(Variant(comparisonBool))
}

func NotEqualInstructionFunc(_ args: [Variant], context: inout RunContext) throws {
    if args.count < 2 {
        throw RuntimeError.tooFewOperands
    } else if args.count > 2 {
        throw RuntimeError.tooManyOperands
    }
    
    let comparisonBool: Bool
    if let a = try? args[0].integer(stack: context.stack), let b = try? args[1].integer(stack: context.stack) {
        comparisonBool = a != b
    } else if let a = try? args[0].double(stack: context.stack), let b = try? args[1].double(stack: context.stack) {
        comparisonBool = abs(a - b) > 0.00001
    } else {
        comparisonBool = try args[0].string(stack: context.stack) != args[1].string(stack: context.stack)
    }
    context.stack.append(Variant(comparisonBool))
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
    
    public mutating func run(_ handler: String, isCommand: Bool, _ params: Variant...) throws {
        for param in params.reversed() {
            stack.append(param)
        }
        stack.append(Variant(parameterCount: params.count))
        let foundHandler = isCommand ? script.commandStarts[handler] : script.functionStarts[handler]
        currentInstruction = foundHandler?.firstInstruction ?? -1
        backPointer = 1

        stack.append(Variant(instructionIndex: -1))
        stack.append(Variant(stackIndex: -1))
        
        if currentInstruction < 0 { throw RuntimeError.unknownMessage(handler, isCommand: isCommand) }
        
        while currentInstruction >= 0 {
            guard let currInstr = script.instructions[currentInstruction] as? RunnableInstruction else { throw RuntimeError.unknownInstruction("\(script.instructions[currentInstruction])") }
            try currInstr.run(&self)
        }
    }
    
    public var builtinCommands: [String:BuiltInFunction] = [
        "output": PrintInstructionFunc,
        "put": PutInstructionFunc,
        "add": AddCommandFunc,
        "subtract": SubtractCommandFunc,
    ]
    public var builtinFunctions: [String:BuiltInFunction] = [
        "-": SubtractInstructionFunc,
        "+": AddInstructionFunc,
        "*": MultiplyInstructionFunc,
        "/": DivideInstructionFunc,
        ">": GreaterThanInstructionFunc,
        "<": LessThanInstructionFunc,
        ">=": GreaterThanEqualInstructionFunc,
        "<=": LessThanEqualInstructionFunc,
        "=": EqualInstructionFunc,
        "≠": NotEqualInstructionFunc,
        "&": ConcatenateInstructionFunc,
        "&&": ConcatenateSpaceInstructionFunc,
    ]

}

protocol RunnableInstruction {
    func run(_ context: inout RunContext) throws
}

extension RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        fatalError("Unknown instruction \(self)")
    }
}

extension PushUnsetInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        context.stack.append(Variant())
        context.currentInstruction += 1
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
        context.currentInstruction += instructionCount
    }
}

extension JumpByIfTrueInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        if try context.stack.popLast()!.boolean(stack: context.stack) {
            context.currentInstruction += instructionCount
        } else {
            context.currentInstruction += 1
        }
    }
}

extension JumpByIfFalseInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        if try !context.stack.popLast()!.boolean(stack: context.stack) {
            context.currentInstruction += instructionCount
        } else {
            context.currentInstruction += 1
        }
    }
}

extension CallInstruction : RunnableInstruction {
    /// Stack during a call looks like:
    /// ... params
    /// paramCount
    /// returnAddress ← back pointer
    /// backPointer
    /// ... variables
    func run(_ context: inout RunContext) throws {
        if isCommand, let destinationInstruction = context.script.commandStarts[message]?.firstInstruction {
            let newBackPointer = context.stack.count
            context.stack.append(Variant(instructionIndex: context.currentInstruction + 1))
            context.stack.append(Variant(stackIndex: context.backPointer))
            context.backPointer = newBackPointer
            context.currentInstruction = destinationInstruction
        } else if !isCommand, let destinationInstruction = context.script.functionStarts[message]?.firstInstruction {
            let newBackPointer = context.stack.count
            context.stack.append(Variant(instructionIndex: context.currentInstruction + 1))
            context.stack.append(Variant(stackIndex: context.backPointer))
            context.backPointer = newBackPointer
            context.currentInstruction = destinationInstruction
        } else if !isCommand, let builtinFunction = context.builtinFunctions[message] {
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
        } else if isCommand, let builtinCommand = context.builtinCommands[message] {
            do {
                let paramCount = try context.stack.popLast()!.parameterCount()
                var args = [Variant]()
                for _ in 0 ..< paramCount {
                    args.append(context.stack.popLast()!)
                }
                try builtinCommand(args, &context)
                context.currentInstruction += 1
            } catch {
                print("error = \(error)\ncontext = \(context)")
                throw error
            }
        } else {
            throw RuntimeError.unknownMessage(message, isCommand: isCommand)
        }
    }
}

extension ReturnInstruction : RunnableInstruction {
    /// Stack at end of a call looks like:
    /// ... params
    /// paramCount
    /// returnAddress ← back pointer
    /// backPointer
    /// ... variables
    /// returnValue
    func run(_ context: inout RunContext) throws {
        guard let returnValue = context.stack.popLast() else { throw RuntimeError.stackIndexOutOfRange }
        let numVariables = context.stack.count - (context.backPointer + 2)
        for _ in 0 ..< numVariables {
            context.stack.removeLast()
        }
        
        context.backPointer = try context.stack.popLast()!.stackIndex()
        context.currentInstruction = try context.stack.popLast()!.instructionIndex()
        let paramCount = try context.stack.popLast()!.parameterCount()
        for _ in 0 ..< paramCount {
            context.stack.removeLast()
        }
        
        if isCommand && context.backPointer >= 0 { // If this is the top-level call, just push the result like a function would, as there is no calling stack frame with a "result" variable.
            context.stack[context.backPointer + Variables.resultVarBPIndex] = returnValue
        } else {
            context.stack.append(returnValue)
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
