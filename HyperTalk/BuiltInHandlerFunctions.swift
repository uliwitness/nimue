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
