import Foundation

public enum ParseError: Error {
    case expectedFunctionName
    case expectedEndOfLine
    case expectedIdentifier(string: String)
    case expectedOperator(string: String)
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
    var numVariables: Int = 0
}

public class Parser {
    public var script = Script()
    
    private func parseValue(tokenizer: Tokenizer, instructions: inout [Instruction], variables: inout Variables, writable: Bool = false) throws -> Bool {
        if let str = try? tokenizer.expectString() {
            instructions.append(PushStringInstruction(string: str))
        } else if let integer = try? tokenizer.expectInteger() {
            instructions.append(PushIntegerInstruction(integer: integer))
        } else if let double = try? tokenizer.expectNumber() {
            instructions.append(PushDoubleInstruction(double: double))
        } else if let identStr = try? tokenizer.expectIdentifier() {
            if let identInstr = variables.mappings[identStr] {
                instructions.append(identInstr)
            } else if writable {
                variables.mappings[identStr] = StackValueBPRelativeInstruction(index: variables.numVariables + 2)
                variables.numVariables += 1
            } else {
                instructions.append(PushStringInstruction(string: identStr))
            }
        } else {
            return false
        }
        return true
    }
    
    private func parseCommand(tokenizer: Tokenizer, instructions: inout [Instruction], variables: inout Variables) throws {
        let functionName = try tokenizer.expectIdentifier()
        
        if try functionName == "local" && parseValue(tokenizer: tokenizer, instructions: &instructions, variables: &variables, writable: true) {
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
            if !tokenizer.hasSymbol(",") {
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
        instructions.append(PushIntegerInstruction(integer: params.count))
        
        // Actual CALL instruction:
        instructions.append(CallInstruction(message: functionName))
    }
    
    private func parseFunction(tokenizer: Tokenizer) throws {
        var function = Function(firstInstruction: script.instructions.count)
        let functionName = try tokenizer.expectIdentifier()
        
        script.instructions.append(ReserveStackInstruction(valueCount: 0))
        
        // Parse list of parameter variable names:
        var parameterCount: Int = 0
        while let nextParamVariableName = try? tokenizer.expectIdentifier() {
            parameterCount += 1
            function.variables.mappings[nextParamVariableName] = ParameterInstruction(index: parameterCount)
            if !tokenizer.hasSymbol(",") {
                break
            } else {
                try tokenizer.expectSymbol(",")
            }
        }
        
        try tokenizer.expectNewline()
        
        // Parse lines of commands until we hit the "end" token:
        while !tokenizer.hasIdentifier("end") {
            tokenizer.skipNewlines()
            try parseCommand(tokenizer: tokenizer, instructions: &script.instructions, variables: &function.variables)
            try tokenizer.expectNewline()
        }
        
        script.instructions.append(ReturnInstruction(numVariables: function.variables.numVariables))
        
        try tokenizer.expectIdentifier("end")
        try tokenizer.expectIdentifier(functionName)
        
        script.instructions[function.firstInstruction] = ReserveStackInstruction(valueCount: function.variables.numVariables)
        
        // Add fully-parsed function to script:
        script.functionStarts[functionName] = function
    }
    
    
    func parse( _ tokenizer: Tokenizer) throws {
        while !tokenizer.isAtEnd {
            if tokenizer.isAtEnd { break }
            tokenizer.skipNewlines()
            let word = try? tokenizer.expectIdentifier()
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
