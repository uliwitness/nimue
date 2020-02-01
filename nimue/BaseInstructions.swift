
protocol Instruction {
    
}

struct PushStringInstruction: Instruction {
    let string: String
}

struct PushIntegerInstruction: Instruction {
    let integer: Int
}

struct PushParameterCountInstruction: Instruction {
    let parameterCount: Int
}

struct PushDoubleInstruction: Instruction {
    let double: Double
}

/// Pops last 2 values on stack and pushes result.
struct AddInstruction: Instruction {
    
}

/// Pops last 2 values on stack and pushes result.
struct SubtractInstruction: Instruction {
    
}

/// Pops last 2 values on stack and pushes result.
struct MultiplyInstruction: Instruction {
    
}

/// Pops last 2 values on stack and pushes result.
struct DivideInstruction: Instruction {
    
}

/// Pops last 2 values on stack and pushes result.
struct ConcatenateInstruction: Instruction {
    
}

/// Assigns SP - 2 to SP - 3 (SP - 1 is param count, 2).
struct AssignInstruction: Instruction {
    
}

/// Assigns SP - 2 to SP - 3 (SP - 1 is param count, 2).
/// Follows references.
struct CopyInstruction: Instruction {
    
}

struct JumpByInstruction: Instruction {
    let instructionCount: Int
}

struct CallInstruction: Instruction {
    let message: String
}

struct ReturnInstruction: Instruction {
    let numVariables: Int
}

/// Push a reference to the given stack value on the stack
/// Negative is parameters, positive is local variables.
struct StackValueBPRelativeInstruction: Instruction {
    let index: Int
}

/// Push a reference to the given parameter on the stack
/// or an empty string if there are fewer parameters.
struct ParameterInstruction: Instruction {
    let index: Int
}

/// Push the given number of empty values on the stack
struct ReserveStackInstruction: Instruction {
    let valueCount: Int
}
