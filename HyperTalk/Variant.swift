public enum VariantError: Error {
    case attemptToAccessSavedBackPointer
    case attemptToAccessSavedProgramCounter
    case attemptToAccessParameterCount
    case expectedSavedBackPointer
    case expectedSavedProgramCounter
    case expectedParameterCount
    case expectedIntegerHere
    case expectedNumberHere
    case expectedBooleanHere
}

public enum Value {
    case empty
    case string(_ value: String)
    case integer(_ value: Int)
    case double(_ value: Double)
    case boolean(_ value: Bool)
    case reference(originalIndex: Int)
    case instructionIndex(index: Int)
    case stackIndex(index: Int)
    case parameterCount(_ : Int)
}

public struct Variant {
    var value: Value
    
    public func string(stack: [Variant]) throws -> String {
        switch value {
        case .empty:
            return ""
        case .string(let str):
            return str
        case .integer(let int):
            return "\(int)"
        case .double(let dbl):
            return "\(dbl)"
        case .boolean(let bool):
            return bool ? "true" : "false"
        case .reference(let index):
            return try stack[index].string(stack: stack)
        case .instructionIndex(_):
            throw VariantError.attemptToAccessSavedProgramCounter
        case .stackIndex(_):
            throw VariantError.attemptToAccessSavedBackPointer
        case .parameterCount(_):
            throw VariantError.attemptToAccessParameterCount
        }
    }
    
    public func integer(stack: [Variant]) throws -> Int {
        switch value {
        case .empty:
            return 0
        case .string(let str):
            return Int(str) ?? 0
        case .integer(let int):
            return int
        case .double(let dbl):
            return Int(dbl)
        case .boolean(_):
            throw VariantError.expectedIntegerHere
        case .reference(let index):
            return try stack[index].integer(stack: stack)
        case .instructionIndex(_):
            throw VariantError.attemptToAccessSavedProgramCounter
        case .stackIndex(_):
            throw VariantError.attemptToAccessSavedBackPointer
        case .parameterCount(_):
            throw VariantError.attemptToAccessParameterCount
        }
    }
    
    public func double(stack: [Variant]) throws -> Double {
        switch value {
        case .empty:
            return 0.0
        case .string(let str):
            return Double(str) ?? 0.0
        case .integer(let int):
            return Double(int)
        case .double(let dbl):
            return dbl
        case .boolean(_):
            throw VariantError.expectedNumberHere
        case .reference(let index):
            return try stack[index].double(stack: stack)
        case .instructionIndex(_):
            throw VariantError.attemptToAccessSavedProgramCounter
        case .stackIndex(_):
            throw VariantError.attemptToAccessSavedBackPointer
        case .parameterCount(_):
            throw VariantError.attemptToAccessParameterCount
        }
    }
    
    public func boolean(stack: [Variant]) throws -> Bool {
        switch value {
        case .empty:
            throw VariantError.expectedBooleanHere
        case .string(let str):
            if str.caseInsensitiveCompare("true") == .orderedSame { return true }
            if str.caseInsensitiveCompare("false") == .orderedSame { return false }
            throw VariantError.expectedBooleanHere
        case .integer(_):
            throw VariantError.expectedBooleanHere
        case .double(_):
            throw VariantError.expectedBooleanHere
        case .boolean(let boolean):
            return boolean
        case .reference(let index):
            return try stack[index].boolean(stack: stack)
        case .instructionIndex(_):
            throw VariantError.attemptToAccessSavedProgramCounter
        case .stackIndex(_):
            throw VariantError.attemptToAccessSavedBackPointer
        case .parameterCount(_):
            throw VariantError.attemptToAccessParameterCount
        }
    }

    public func referenceIndex(stack: [Variant]) -> Int? {
        if case let .reference(index) = value {
            return stack[index].referenceIndex(stack: stack) ?? index
        }
        return nil
    }
    
    func stackIndex() throws -> Int {
        if case let .stackIndex(index) = value {
            return index
        }
        
        throw VariantError.expectedSavedBackPointer
    }
    
    func instructionIndex() throws -> Int {
        if case let .instructionIndex(index) = value {
            return index
        }
        
        throw VariantError.expectedSavedProgramCounter
    }
    
    func parameterCount() throws -> Int {
        if case let .parameterCount(index) = value {
            return index
        }
        
        throw VariantError.expectedParameterCount
    }
    
    public init() {
        value = .empty
    }
    
    public init(_ string: String) {
        value = .string(string)
    }
    
    public init(_ integer: Int) {
        value = .integer(integer)
    }
    
    public init(_ double: Double) {
        value = .double(double)
    }
    
    public init(_ boolean: Bool) {
        value = .boolean(boolean)
    }
    
    public init(referenceIndex refIndex: Int) {
        value = .reference(originalIndex: refIndex)
    }
    
    init(stackIndex refIndex: Int) {
        value = .stackIndex(index: refIndex)
    }
    
    init(instructionIndex refIndex: Int) {
        value = .instructionIndex(index: refIndex)
    }
    
    init(parameterCount: Int) {
        value = .parameterCount(parameterCount)
    }
}
