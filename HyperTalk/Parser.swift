import Foundation

enum ParserValueKind {
    case none
    case expression
    case container
    case identifier(expected: [String])
}

public struct SyntaxElement {
    var identifiers: [String]
    var valueKind: ParserValueKind
    var required: Bool = true
    var parseState: Int = 0
    var nextParseState: Int = 0
}

public struct Syntax {
    var identifiers: [String]
    var parameters: [SyntaxElement]
}

struct Function {
    var firstInstruction: Int
    var variables = Variables()
}

public struct Script: CustomDebugStringConvertible {
    var functionStarts = [String:Function]()
    var instructions = [Instruction]()
    
    public var debugDescription: String {
        var descr = "Script {\n"
        
        var functionNames = [Int:String]()
        for (name, info) in functionStarts {
            functionNames[info.firstInstruction] = name
        }
        
        var index = 0
        for instr in instructions {
            if let funcName = functionNames[index], let funcInfo = functionStarts[funcName] {
                descr.append("\t\(funcName):\n\(funcInfo.variables.debugDesc(depth: 2))\n")
            }
            
            descr.append("\t\t\(instr)\n")

            index += 1
        }
        
        descr.append("}\n")
        
        return descr
    }
}

struct Variables: CustomDebugStringConvertible {
    var mappings = [String: Instruction]()
    var numLocals: Int = 0
    
    func debugDesc(depth: Int) -> String {
        var result = ""
        let indent = String(repeating: "\t", count: depth)
        
        for mapping in mappings {
            if let paramInstr = mapping.value as? StackValueBPRelativeInstruction {
                result += "\(indent)\"\(mapping.key)\"\tvar[\(paramInstr.index)]\n"
            } else if let paramInstr = mapping.value as? ParameterInstruction {
                result += "\(indent)\"\(mapping.key)\"\tparam[\(paramInstr.index)]\n"
            } else {
                result += "\(indent)\"\(mapping.key)\"\t\(mapping.value)\n"
            }
        }
        
        return result
    }
    
    var debugDescription: String {
        return debugDesc(depth: 0)
    }
}

public class Parser {
    public var script = Script()
    public var commandSyntaxes = [
        Syntax(identifiers: ["put"], parameters: [
            SyntaxElement(identifiers: [], valueKind: .expression),
            SyntaxElement(identifiers: [], valueKind: .identifier(expected: ["into"])),
            SyntaxElement(identifiers: [], valueKind: .container)
        ]),
        Syntax(identifiers: ["add"], parameters: [
            SyntaxElement(identifiers: [], valueKind: .expression),
            SyntaxElement(identifiers: ["to"], valueKind: .container)
        ]),
        Syntax(identifiers: ["subtract"], parameters: [
            SyntaxElement(identifiers: [], valueKind: .expression),
            SyntaxElement(identifiers: ["from"], valueKind: .container)
        ])
    ]
    
    public init() {
        
    }
    
    private func parseValue(tokenizer: Tokenizer, instructions: inout [Instruction], variables: inout Variables, writable: Bool = false) throws -> Bool {
        if tokenizer.isAtEnd { return false }
        if let str = tokenizer.hasString(updateCurrentIndexOnMatch: true) {
            instructions.append(PushStringInstruction(string: str))
        } else if let integer = tokenizer.hasInteger(updateCurrentIndexOnMatch: true) {
            instructions.append(PushIntegerInstruction(integer: integer))
        } else if let double = tokenizer.hasNumber(updateCurrentIndexOnMatch: true) {
            instructions.append(PushDoubleInstruction(double: double))
        } else if let identStr = tokenizer.hasIdentifier(updateCurrentIndexOnMatch: true) {
            if let identInstr = variables.mappings[identStr] {
                instructions.append(identInstr)
            } else if writable {
                let variableInstruction = StackValueBPRelativeInstruction(index: variables.numLocals + 2)
                variables.mappings[identStr] = variableInstruction
                variables.numLocals += 1
                instructions.append(variableInstruction)
            } else {
                instructions.append(PushStringInstruction(string: identStr))
            }
        } else {
            return false
        }
        return true
    }
    
    private indirect enum Operation: CustomDebugStringConvertible {
        case none
        case operand([Instruction])
        case operation(operator: String, lhs: Operation, rhs: Operation)
        
        func replacingRHS(with rhs: Operation, operator op: String) -> Operation {
            switch self {
            case .operand(_):
                return .operation(operator: op, lhs: self, rhs: rhs)
            case .operation(operator: let selfOp, lhs: let selfLhs, rhs: let selfRhs):
                if case .operand(_) = selfRhs {
                    return .operation(operator: selfOp, lhs: selfLhs, rhs: .operation(operator: op, lhs: selfRhs, rhs: rhs))
                } else {
                    return .operation(operator: selfOp, lhs: selfLhs, rhs: selfRhs.replacingRHS(with: rhs, operator: op))
                }
            case .none:
                fatalError("Invalid parser state: replacingRHS with .none self.")
            }
        }
        
        private static let operatorsByPrecedence = [
            "*",
            "/",
            "-",
            "+",
            "&",
            "&&",
        ]
        
        static func precedence(of operatorName: String) -> Int {
            return Operation.operatorsByPrecedence.firstIndex(of: operatorName) ?? Int.max
        }
        
        /// Lowest number is most strongly binding operator:
        var precedence: Int {
            switch self {
            case .operand(_):
                return Int.max
            case .operation(operator: let selfOp, lhs: _, rhs: _):
                return Operation.precedence(of: selfOp)
            case .none:
                fatalError("Invalid parser state: precedence called on none.")
            }
        }
        
        var rightmostOperation: Operation {
            switch self {
            case .operand(_):
                return self
            case .operation(operator: _, lhs: _, let rhs):
                if case .operation(_, _, _) = rhs {
                    return rhs.rightmostOperation
                } else {
                    return self
                }
            case .none:
                fatalError("Invalid parser state: precedence called on none.")
            }
        }
        
        private func debugDesc(depth: Int) -> String {
            let indent = String(repeating: "\t", count: depth)
            switch self {
            case .operand(let instructions):
                return indent + ".operand(\(instructions))"
            case .operation(let selfOp, let lhs, let rhs):
                return "\(indent).operation[\(selfOp)] {\n\(lhs.debugDesc(depth: depth + 1))\n\(rhs.debugDesc(depth: depth + 1))\n\(indent)}"
            case .none:
                return "\(indent).none"
            }
        }
        
        var debugDescription: String {
            return debugDesc(depth: 0)
        }
    }
    
    private func appendInstructions(from expression: Operation, to instructions: inout [Instruction]) {
        switch expression {
        case .none:
            fatalError("Invalid parser state: Expression is none when generating.")
        case .operand(let opInstructions):
            instructions.append(contentsOf: opInstructions)
        case .operation(let opName, let lhs, let rhs):
            appendInstructions(from: rhs, to: &instructions)
            appendInstructions(from: lhs, to: &instructions)
            instructions.append(PushParameterCountInstruction(parameterCount: 2))
            instructions.append(CallInstruction(message: opName))
        }
    }
    
    private func parseExpression(tokenizer: Tokenizer, instructions: inout [Instruction], variables: inout Variables, forbiddenOperators: [String] = []) throws -> Bool {
        var firstArgInstructions = [Instruction]()
        
        guard try parseValue(tokenizer: tokenizer, instructions: &firstArgInstructions, variables: &variables, writable: false) else { return false }
        
        var root = Operation.operand(firstArgInstructions)

        while true {
            guard let currentOperator = tokenizer.hasSymbol(), currentOperator != "\n" else { break }
            if forbiddenOperators.contains(currentOperator) { break }
            
            let oldIndex = tokenizer.currentIndex
            try tokenizer.expectSymbol(currentOperator)
            
            var currArgInstructions = [Instruction]()
            guard try parseValue(tokenizer: tokenizer, instructions: &currArgInstructions, variables: &variables, writable: false) else {
                tokenizer.currentIndex = oldIndex
                break
            }

            let rightmost = root.rightmostOperation
            if rightmost.precedence > Operation.precedence(of: currentOperator) {
                root = root.replacingRHS(with: .operand(currArgInstructions), operator: currentOperator)
            } else {
                root = .operation(operator: currentOperator, lhs: root, rhs: .operand(currArgInstructions))
            }
        }
        
        appendInstructions(from: root, to: &instructions)
                
        return true
    }
    
    private func parseEnglishHandlerCall(tokenizer: Tokenizer, instructions: inout [Instruction], variables: inout Variables) throws -> Bool {
        // Try each command syntax entry whether its introductory tokens match:
        for commandSyntax in commandSyntaxes {
            let originalIndex = tokenizer.currentIndex
            if !tokenizer.hasIdentifiers(commandSyntax.identifiers, updateCurrentIndexOnMatch: true) {
                continue
            }
            
            // Now parse the parameters' instructions separately into 'paramInstructions':
            var paramInstructions = [[Instruction]]()
            var paramCount = 0
            var matchedAllParams = true
            for paramSyntax in commandSyntax.parameters {
                var valueInstructions = [Instruction]()
                if !paramSyntax.identifiers.isEmpty && !tokenizer.hasIdentifiers(paramSyntax.identifiers, updateCurrentIndexOnMatch: true) {
                    matchedAllParams = false
                    break
                }
                switch paramSyntax.valueKind {
                case .expression:
                    if try !parseExpression(tokenizer: tokenizer, instructions: &valueInstructions, variables: &variables) {
                        matchedAllParams = false
                    }
                    paramCount += 1
                case .container:
                    if try !parseValue(tokenizer: tokenizer, instructions: &valueInstructions, variables: &variables, writable: true) {
                        matchedAllParams = false
                    }
                    paramCount += 1
                case .identifier(let expected):
                    if !tokenizer.hasIdentifiers(expected, updateCurrentIndexOnMatch: true) {
                        matchedAllParams = false
                    } else {
                        expected.reversed().forEach { valueInstructions.append(PushStringInstruction(string: $0)) }
                        paramCount += expected.count
                    }
                case .none:
                    break
                }
                if !matchedAllParams { break }
                paramInstructions.append(valueInstructions)
            }
            // Parameters didn't match? Backtrack and try next command:
            if !matchedAllParams {
                tokenizer.currentIndex = originalIndex
                continue
            }
            
            // Now push the parsed parameters backwards and make it like
            // any other handler call:
            for valueInstructions in paramInstructions.reversed() {
                instructions.append(contentsOf: valueInstructions)
            }
            instructions.append(PushParameterCountInstruction(parameterCount: paramCount))
            instructions.append(CallInstruction(message: commandSyntax.identifiers.joined(separator: "")))
            return true
        }
        
        return false
    }
    
    private func parseGenericHandlerCall(tokenizer: Tokenizer, instructions: inout [Instruction], variables: inout Variables) throws {
        let functionName = try tokenizer.expectIdentifier()
        
        // Parse parameters separately into `params`:
        var params = [[Instruction]]()
        while true {
            var paramInstructions = [Instruction]()
            if try !parseExpression(tokenizer: tokenizer, instructions: &paramInstructions, variables: &variables, forbiddenOperators: [","]) {
                break
            }
            params.append(paramInstructions)
            if tokenizer.hasSymbol(",") == nil {
                break
            } else {
                try tokenizer.expectSymbol(",")
            }
        }
        // Now append code for parameters in reverse, so
        //  parameter 1 is always at BP - 2, parameter 2 always BP - 3 etc.
        //  even if we were given more parameters than we actually accept.
        for paramInstructions in params.reversed() {
            instructions.append(contentsOf: paramInstructions)
        }
        // Push number of parameters on stack so we can cope with getting
        //  fewer parameters than expected or accept variadic parameters.
        instructions.append(PushParameterCountInstruction(parameterCount: params.count))
        
        // Actual CALL instruction:
        instructions.append(CallInstruction(message: functionName))
    }
    
    private func parseLoop(tokenizer: Tokenizer, instructions: inout [Instruction], variables: inout Variables) throws {
        try tokenizer.expectIdentifier("repeat")
        var conditionExpression = [Instruction]()
        if try tokenizer.hasIdentifier("while", updateCurrentIndexOnMatch: true) != nil && parseExpression(tokenizer: tokenizer, instructions: &conditionExpression, variables: &variables) {
            try tokenizer.expectNewline()
            var loopedInstructions = [Instruction]()
            while tokenizer.hasIdentifier("end") == nil && tokenizer.hasIdentifier("else") == nil { // Intentionally don't parse for "end if" here, so we catch unbalanced "end" statements with the expectIdentifiers() below if possible.
                tokenizer.skipNewlines()
                try parseOneLine(tokenizer: tokenizer, instructions: &loopedInstructions, variables: &variables)
                try tokenizer.expectNewline()
            }
            try tokenizer.expectIdentifiers("end", "repeat")

            let beforeConditionInstructionCount = instructions.count
            instructions.append(contentsOf: conditionExpression)
            instructions.append(JumpByIfFalseInstruction(instructionCount: loopedInstructions.count + 2)) // +2 for the "jump back up" and the actual "jump by if false" instruction.
            instructions.append(contentsOf: loopedInstructions)
            let afterConditionInstructionCount = instructions.count
            instructions.append(JumpByInstruction(instructionCount: beforeConditionInstructionCount - afterConditionInstructionCount))
        } else {
            throw ParseError.expectedIdentifier(string: "while", token: tokenizer.currentToken)
        }
    }

    private func parseConditional(tokenizer: Tokenizer, instructions: inout [Instruction], variables: inout Variables) throws {
        try tokenizer.expectIdentifier("if")
        var conditionExpression = [Instruction]()
        if try parseExpression(tokenizer: tokenizer, instructions: &conditionExpression, variables: &variables) {
            _ = tokenizer.hasSymbol("\n", updateCurrentIndexOnMatch: true) // Allow for a return before the "then", if desired.
            try tokenizer.expectIdentifier("then")
            var trueInstructions = [Instruction]()
            var falseInstructions = [Instruction]()
            var needsEndIf = false
            
            // Parse "true" case:
            if tokenizer.hasSymbol("\n", updateCurrentIndexOnMatch: true) == nil { // Single-line "if" statements have their statement on the same line.
                try parseOneLine(tokenizer: tokenizer, instructions: &trueInstructions, variables: &variables)
            } else { // Multi-line if has the statements on their own lines below the "then" line.
                needsEndIf = true
                while tokenizer.hasIdentifier("end") == nil && tokenizer.hasIdentifier("else") == nil { // Intentionally don't parse for "end if" here, so we catch unbalanced "end" statements with the expectIdentifiers() below if possible.
                    tokenizer.skipNewlines()
                    try parseOneLine(tokenizer: tokenizer, instructions: &trueInstructions, variables: &variables)
                    try tokenizer.expectNewline()
                }
            }
            
            tokenizer.skipNewlines()

            // Parse "false" case:
            if tokenizer.hasIdentifier("else", updateCurrentIndexOnMatch: true) != nil {
                if tokenizer.hasSymbol("\n", updateCurrentIndexOnMatch: true) == nil { // Single-line "else" statements have their statement on the same line.
                    needsEndIf = false
                    try parseOneLine(tokenizer: tokenizer, instructions: &falseInstructions, variables: &variables)
                } else { // Multi-line if has the statements on their own lines below the "then" line.
                    needsEndIf = true
                    while tokenizer.hasIdentifier("end") == nil { // Intentionally don't parse for "end if" here, so we catch unbalanced "end" statements with the expectIdentifiers() below if possible.
                        tokenizer.skipNewlines()
                        try parseOneLine(tokenizer: tokenizer, instructions: &falseInstructions, variables: &variables)
                        try tokenizer.expectNewline()
                    }
                }
            }
            
            // Parse end marker, if last case was multi-line:
            if needsEndIf {
                try tokenizer.expectIdentifiers("end", "if")
            }
            
            let skipElseCaseInstructionCount = falseInstructions.isEmpty ? 0 : 1 // If we have an "else" case, we add an instruction to jump over those instructions to the end of our "if".

            // Now actually assemble the code & branch expressions:
            instructions.append(contentsOf: conditionExpression)
            instructions.append(JumpByIfFalseInstruction(instructionCount: trueInstructions.count + skipElseCaseInstructionCount + 1)) // +1 for the "jump by if false" instruction itself.
            instructions.append(contentsOf: trueInstructions)
            if !falseInstructions.isEmpty {
                instructions.append(JumpByInstruction(instructionCount: falseInstructions.count + 1)) // +1 for the "jump by" instruction itself.
                instructions.append(contentsOf: falseInstructions)
            }
        } else {
            throw ParseError.expectedExpression(token: tokenizer.currentToken)
        }
    }

    private func parseOneLine(tokenizer: Tokenizer, instructions: inout [Instruction], variables: inout Variables) throws {
        
        // Loop:
        if tokenizer.hasIdentifier("repeat") != nil {
            try parseLoop(tokenizer: tokenizer, instructions: &instructions, variables: &variables)
            return
        }
        
        // Cobditional:
        if tokenizer.hasIdentifier("if") != nil {
            try parseConditional(tokenizer: tokenizer, instructions: &instructions, variables: &variables)
            return
        }
        
        // Built-in handler call syntax:
        if try parseEnglishHandlerCall(tokenizer: tokenizer, instructions: &instructions, variables: &variables) {
            return
        }
        
        // Try a "local" variable declaration:
        var ignoredInstructions = [Instruction]()
        if try tokenizer.hasIdentifier("local", updateCurrentIndexOnMatch: true) != nil && parseValue(tokenizer: tokenizer, instructions: &ignoredInstructions, variables: &variables, writable: true) {
            return
        }
        
        // Parse a regular handler call:
        try parseGenericHandlerCall(tokenizer: tokenizer, instructions: &instructions, variables: &variables)
    }
    
    private func parseFunction(tokenizer: Tokenizer) throws {
        var function = Function(firstInstruction: script.instructions.count)
        let functionName = try tokenizer.expectIdentifier()
        
        script.instructions.append(ReserveStackInstruction(valueCount: 0))
        
        // Parse list of parameter variable names:
        var parameterCount: Int = 0
        while let nextParamVariableName = tokenizer.hasIdentifier(updateCurrentIndexOnMatch: true) {
            parameterCount += 1
            function.variables.mappings[nextParamVariableName] = ParameterInstruction(index: parameterCount)
            if tokenizer.hasSymbol(",") == nil {
                break
            } else {
                try tokenizer.expectSymbol(",")
            }
        }
        
        try tokenizer.expectNewline()
        
        // Parse lines of commands until we hit the "end" token:
        while tokenizer.hasIdentifier("end") == nil {
            tokenizer.skipNewlines()
            try parseOneLine(tokenizer: tokenizer, instructions: &script.instructions, variables: &function.variables)
            try tokenizer.expectNewline()
        }
        
        script.instructions.append(ReturnInstruction(numVariables: function.variables.numLocals))
        
        try tokenizer.expectIdentifier("end")
        try tokenizer.expectIdentifier(functionName)
        
        script.instructions[function.firstInstruction] = ReserveStackInstruction(valueCount: function.variables.numLocals)
        
        // Add fully-parsed function to script:
        script.functionStarts[functionName] = function
    }
    
    public func parse( _ tokenizer: Tokenizer) throws {
        while !tokenizer.isAtEnd {
            if tokenizer.isAtEnd { break }
            tokenizer.skipNewlines()
            let word = tokenizer.hasIdentifier(updateCurrentIndexOnMatch: true)
            switch word {
            case "on":
                try parseFunction(tokenizer: tokenizer)
            case "function":
                try parseFunction(tokenizer: tokenizer)
            default:
                tokenizer.skipLine()
            }
        }
    }
}
