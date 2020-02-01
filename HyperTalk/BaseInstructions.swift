
public protocol Instruction {
    
}

public struct PushStringInstruction: Instruction {
    let string: String
}

public struct PushIntegerInstruction: Instruction {
    let integer: Int
}

public struct PushParameterCountInstruction: Instruction {
    let parameterCount: Int
}

public struct PushDoubleInstruction: Instruction {
    let double: Double
}

/// Pops last 2 values on stack and pushes result.
public struct AddInstruction: Instruction {
    
}

/// Pops last 2 values on stack and pushes result.
public struct SubtractInstruction: Instruction {
    
}

/// Pops last 2 values on stack and pushes result.
public struct MultiplyInstruction: Instruction {
    
}

/// Pops last 2 values on stack and pushes result.
public struct DivideInstruction: Instruction {
    
}

/// Pops last 2 values on stack and pushes result.
public struct ConcatenateInstruction: Instruction {
    
}

/// Assigns SP - 2 to SP - 3 (SP - 1 is param count, 2).
public struct AssignInstruction: Instruction {
    
}

/// Assigns SP - 2 to SP - 3 (SP - 1 is param count, 2).
/// Follows references.
public struct CopyInstruction: Instruction {
    
}

public struct JumpByInstruction: Instruction {
    let instructionCount: Int
}

public struct CallInstruction: Instruction {
    let message: String
}

public struct ReturnInstruction: Instruction {
    let numVariables: Int
}

/// Push a reference to the given stack value on the stack
/// Negative is parameters, positive is local variables.
public struct StackValueBPRelativeInstruction: Instruction {
    let index: Int
}

/// Push a reference to the given parameter on the stack
/// or an empty string if there are fewer parameters.
public struct ParameterInstruction: Instruction {
    let index: Int
}

/// Push the given number of empty values on the stack
public struct ReserveStackInstruction: Instruction {
    let valueCount: Int
}
