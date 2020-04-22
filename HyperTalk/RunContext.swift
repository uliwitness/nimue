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
