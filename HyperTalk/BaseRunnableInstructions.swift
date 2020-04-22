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

extension PushPropertyInstruction : RunnableInstruction {
    func run(_ context: inout RunContext) throws {
        guard let target = context.stack.popLast() else { throw RuntimeError.stackIndexOutOfRange }
        
        let value = try target.hyperTalkPropertyValue(name, stack: context.stack)
        context.stack.append(value)
        
        context.currentInstruction += 1
    }
}
