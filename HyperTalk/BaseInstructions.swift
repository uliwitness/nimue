
public protocol Instruction {
    
}

public struct PushUnsetInstruction: Instruction, Equatable {
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
/// Does _not_ follow references.
public struct AssignInstruction: Instruction, Equatable {
    
}

/// Assigns SP - 2 to SP - 3 (SP - 1 is param count, 2).
/// Follows references.
public struct CopyInstruction: Instruction, Equatable {
    
}

/// Advances currentInstruction by the given count, "jumping"
/// forward or backward by that many instructions, skipping
/// the instructions that lie in between.
public struct JumpByInstruction: Instruction, Equatable {
    let instructionCount: Int
}

/// Pops the last value off the stack, does nothing (except for
/// advancing to the next instruction) if it is FALSE,
/// jumps by the given number of instructions if it is TRUE.
public struct JumpByIfTrueInstruction: Instruction, Equatable {
    let instructionCount: Int
}

/// Pops the last value off the stack, does nothing (except for
/// advancing to the next instruction) if it is TRUE,
/// jumps by the given number of instructions if it is FALSE.
public struct JumpByIfFalseInstruction: Instruction, Equatable {
    let instructionCount: Int
}

/// This instruction requires you to have pushed the parameters on the stack,
/// in reverse order, and the number of parameters as the last element. Then
/// it will send a message of the given name with those parameters.
/// This also saves the Back Pointer (BP) and return address
/// (currentInstruction (PC) + 1) on the stack and sets the back pointer to
/// right before where they are saved (right after the parameter count) so
/// you can consistently reference parameters and local variables.
public struct CallInstruction: Instruction, Equatable {
    let message: String
    let isCommand: Bool
}

/// Pops the backmost value off the stack, then cleans up the stack space
/// claimed for variables by ReserveStackInstruction (by calculating the number
/// of variables based on the back pointer) and then restores the saved
/// back pointer (BP) and return address (PC) from the stack. It will then
/// remove the parameters from the stack as well and push the value from the
/// first step so it is available as the return value.
public struct ReturnInstruction: Instruction, Equatable {
    let isCommand: Bool
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

/// Push the property with the given name of the last element on the stack onto the stack in its place.
public struct PushPropertyInstruction: Instruction, Equatable {
    let name: String
}

/// Compare 2 instructions for equality. Useful for unit tests.
public func equalInstructions<T: Instruction & Equatable>(_ left: Instruction, _ right: T) -> Bool {
    guard let left = left as? T else { return false }
    return left == right
}
