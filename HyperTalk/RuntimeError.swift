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
    /// A script requested a property from an object or value that does not have a property of that name.
    case unknownProperty(_ name: String)
    /// A script tried to modify a property that is read-only.
    case cantChangeReadOnlyProperty(_ name: String)
    /// An object in an expression was referenced but does not or no longer exist.
    case objectDoesNotExist
}
