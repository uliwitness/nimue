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
                descr.append("\t\(funcName): \(funcInfo.variables)\n")
            }
            
            descr.append("\t\t\(instr)\n")
            
            index += 1
        }
        
        descr.append("}\n")
        
        return descr
    }
}

struct Variables {
    var mappings = [String: Instruction]()
    var numLocals: Int = 0
}

public class Parser {
    public var script = Script()
    public var commandSyntaxes = [
        Syntax(identifiers: ["put"], parameters: [
            SyntaxElement(identifiers: [], valueKind: .expression),
            SyntaxElement(identifiers: [], valueKind: .identifier(expected: ["into"])),
            SyntaxElement(identifiers: [], valueKind: .container)
        ])]
    
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
    
    private func parseCommand(tokenizer: Tokenizer, instructions: inout [Instruction], variables: inout Variables) throws {
        for commandSyntax in commandSyntaxes {
            let originalIndex = tokenizer.currentIndex
            if !tokenizer.hasIdentifiers(commandSyntax.identifiers, updateCurrentIndexOnMatch: true) {
                continue
            }
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
                    if try !parseValue(tokenizer: tokenizer, instructions: &valueInstructions, variables: &variables) {
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
            if !matchedAllParams {
                tokenizer.currentIndex = originalIndex
                continue
            }
            
            for valueInstructions in paramInstructions.reversed() {
                instructions.append(contentsOf: valueInstructions)
            }
            instructions.append(PushParameterCountInstruction(parameterCount: paramCount))
            instructions.append(CallInstruction(message: commandSyntax.identifiers.joined(separator: "")))
            return
        }
        
        let functionName = try tokenizer.expectIdentifier()
        
        var ignoredInstructions = [Instruction]()
        if try functionName == "local" && parseValue(tokenizer: tokenizer, instructions: &ignoredInstructions, variables: &variables, writable: true) {
            return
        }

        // Parse parameters separately into `params`:
        var params = [[Instruction]]()
        while true {
            var paramInstructions = [Instruction]()
            if try !parseValue(tokenizer: tokenizer, instructions: &paramInstructions, variables: &variables) {
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
            try parseCommand(tokenizer: tokenizer, instructions: &script.instructions, variables: &function.variables)
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
