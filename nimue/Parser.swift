import Foundation

public enum ParseError: Error {
    case expectedFunctionName
    case expectedEndOfLine
    case expectedIdentifier(string: String)
    case expectedOperator(string: String)
}

fileprivate let identifierCS = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
fileprivate let operatorCS = CharacterSet.punctuationCharacters.union(CharacterSet.symbols)
fileprivate let whitespaceCS = CharacterSet.whitespaces
fileprivate let newlineCS = CharacterSet.newlines

struct Function {
    var firstInstruction: Int
    var variables = [String:Instruction]()
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
            if let funcName = functionNames[index] {
                descr.append("\t\(funcName): \(functionStarts[funcName]?.variables ?? [:])\n")
            }
            
            descr.append("\t\t\(instr)\n")
            
            index += 1
        }
        
        descr.append("}\n")
        
        return descr
    }
}

fileprivate extension Scanner {
    func expectNewline() throws {
        guard scanCharacters(from: newlineCS) != nil else {
            throw ParseError.expectedEndOfLine
        }
    }
    
    func expectIdentifier(_ string: String) throws {
        guard let ident = scanCharacters(from: identifierCS) else {
            throw ParseError.expectedIdentifier(string: string)
        }
        guard ident.caseInsensitiveCompare(string) == .orderedSame else {
            throw ParseError.expectedIdentifier(string: string)
        }
    }
    
    func expectOperator(_ string: String) throws {
        guard let character = scanCharacter(), character.isPunctuation || character.isSymbol else {
            throw ParseError.expectedOperator(string: string)
        }
        guard String(character) == string else {
            throw ParseError.expectedOperator(string: string)
        }
    }
    
    func haveNewline() -> Bool {
        let oldIndex = currentIndex
        defer { currentIndex = oldIndex }
        guard scanCharacters(from: newlineCS) != nil else {
            return false
        }
        return true
    }
    
    func haveIdentifier(_ string: String) -> Bool {
        let oldIndex = currentIndex
        defer { currentIndex = oldIndex }
        guard let ident = scanCharacters(from: identifierCS) else {
            return false
        }
        guard ident.caseInsensitiveCompare(string) == .orderedSame else {
            return false
        }
        
        return true
    }
    
    func haveOperator(_ string: String) -> Bool {
        let oldIndex = currentIndex
        defer { currentIndex = oldIndex }
        guard let character = scanCharacter(), character.isPunctuation || character.isSymbol else {
            return false
        }
        guard String(character) == string else {
            return false
        }
        
        return true
    }
    
    func scanIdentifier() throws -> String {
        guard let string = scanCharacters(from: identifierCS) else {
            throw ParseError.expectedIdentifier(string: "")
        }
        return string
    }
    
    func scanOperator() throws -> String {
        guard let character = scanCharacter(), character.isPunctuation || character.isSymbol else {
            throw ParseError.expectedOperator(string: "")
        }
        
        return String(character)
    }
}

public class Parser {
    public var script = Script()
    
    private func parseValue(scanner: Scanner, instructions: inout [Instruction], variables: inout [String: Instruction]) throws -> Bool {
        if scanner.scanString("\"") != nil {
            scanner.charactersToBeSkipped = nil
            defer { scanner.charactersToBeSkipped = whitespaceCS }
            var str = ""
            while true {
                let currPart = scanner.scanUpToString("\"") ?? ""
                str.append(currPart)
                if currPart.hasSuffix("\\") {
                    _ = scanner.scanString("\"")
                    str.append("\"")
                } else {
                    _ = scanner.scanString("\"")
                    break
                }
            }
            instructions.append(PushStringInstruction(string: str))
        } else if let numStr = scanner.scanCharacters(from: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))) {
            if numStr.contains(".") {
                instructions.append(PushDoubleInstruction(double: Double(numStr) ?? 0.0))
            } else {
                instructions.append(PushIntegerInstruction(integer: Int(numStr) ?? 0))
            }
        } else if let identStr = scanner.scanCharacters(from: identifierCS) {
            if let identInstr = variables[identStr] {
                instructions.append(identInstr)
            } else { // TODO: Add implicitly declared variables.
                instructions.append(PushStringInstruction(string: identStr))
            }
        } else {
            return false
        }
        return true
    }
    
    private func parseCommand(scanner: Scanner, instructions: inout [Instruction], variables: inout [String: Instruction]) throws {
        let functionName = try scanner.scanIdentifier()
        
        // Parse parameters separately into `params`:
        var params = [[Instruction]]()
        while true {
            var paramInstructions = [Instruction]()
            if try !parseValue(scanner: scanner, instructions: &paramInstructions, variables: &variables) {
                break
            }
            params.append(paramInstructions)
            if !scanner.haveOperator(",") {
                break
            } else {
                try scanner.expectOperator(",")
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
    
    private func parseFunction(scanner: Scanner) throws {
        var function = Function(firstInstruction: script.instructions.count)
        let functionName = try scanner.scanIdentifier()
        
        // Parse list of parameter variable names:
        var parameterCount: Int = 0
        while let nextParamVariableName = try? scanner.scanIdentifier() {
            parameterCount += 1
            function.variables[nextParamVariableName] = StackValueBPRelativeInstruction(index: -parameterCount - 1) // - 1 to account for parameter count at BP -1.
            if !scanner.haveOperator(",") {
                break
            } else {
                try scanner.expectOperator(",")
            }
        }
        
        try scanner.expectNewline()
        
        // Parse lines of commands until we hit the "end" token:
        while !scanner.haveIdentifier("end") {
            if scanner.haveNewline() { continue }
            try parseCommand(scanner: scanner, instructions: &script.instructions, variables: &function.variables)
            if scanner.scanCharacters(from: newlineCS) == nil {
                throw ParseError.expectedOperator(string: "\n")
            }
        }
        
        script.instructions.append(ReturnInstruction())
        
        try scanner.expectIdentifier("end")
        try scanner.expectIdentifier(functionName)
        
        // Add fully-parsed function to script:
        script.functionStarts[functionName] = function
    }
    
    
    func parse( _ text: String) throws {
        let scanner = Scanner(string: text)
        scanner.caseSensitive = false
        scanner.charactersToBeSkipped = whitespaceCS
        
        while !scanner.isAtEnd {
            _ = scanner.scanCharacters(from: newlineCS)
            if scanner.isAtEnd { break }
            let word = try scanner.scanIdentifier()
            switch word {
            case "on":
                try parseFunction(scanner: scanner)
            case "function":
                try parseFunction(scanner: scanner)
            default:
                _ = scanner.scanUpToCharacters(from: newlineCS)
                _ = scanner.scanCharacters(from: newlineCS)
            }
        }
    }
}
