
public protocol Instruction {
    
}

public struct PushStringInstruction: Instruction, Equatable {
    let string: String
}

public struct PushIntegerInstruction: Instruction, Equatable {
    let integer: Int
}

public struct PushParameterCountInstruction: Instruction, Equatable {
    let parameterCount: Int
}

public struct PushDoubleInstruction: Instruction, Equatable {
    let double: Double
}

/// Pops last 2 values on stack and pushes result.
public struct AddInstruction: Instruction, Equatable {
    
}

/// Pops last 2 values on stack and pushes result.
public struct SubtractInstruction: Instruction, Equatable {
    
}

/// Pops last 2 values on stack and pushes result.
public struct MultiplyInstruction: Instruction, Equatable {
    
}

/// Pops last 2 values on stack and pushes result.
public struct DivideInstruction: Instruction, Equatable {
    
}

/// Pops last 2 values on stack and pushes result.
public struct ConcatenateInstruction: Instruction, Equatable {
    
}

/// Assigns SP - 2 to SP - 3 (SP - 1 is param count, 2).
public struct AssignInstruction: Instruction, Equatable {
    
}

/// Assigns SP - 2 to SP - 3 (SP - 1 is param count, 2).
/// Follows references.
public struct CopyInstruction: Instruction, Equatable {
    
}

public struct JumpByInstruction: Instruction, Equatable {
    let instructionCount: Int
}

public struct CallInstruction: Instruction, Equatable {
    let message: String
}

public struct ReturnInstruction: Instruction, Equatable {
    let numVariables: Int
}

/// Push a reference to the given stack value on the stack
/// Negative is parameters, positive is local variables.
public struct StackValueBPRelativeInstruction: Instruction, Equatable {
    let index: Int
}

/// Push a reference to the given parameter on the stack
/// or an empty string if there are fewer parameters.
public struct ParameterInstruction: Instruction, Equatable {
    let index: Int
}

/// Push the given number of empty values on the stack
public struct ReserveStackInstruction: Instruction, Equatable {
    let valueCount: Int
}


public func equalInstructions<T: Instruction & Equatable>(_ left: Instruction, _ right: T) -> Bool {
    guard let left = left as? T else { return false }
    return left == right
}
