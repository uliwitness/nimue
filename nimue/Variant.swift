enum VariantError: Error {
    case attemptToAccessSavedBackPointer
    case attemptToAccessSavedProgramCounter
    case attemptToAccessParameterCount
    case expectedSavedBackPointer
    case expectedSavedProgramCounter
    case expectedParameterCount
}

enum Value {
    case empty
    case string(_ value: String)
    case integer(_ value: Int)
    case double(_ value: Double)
    case reference(originalIndex: Int)
    case instructionIndex(index: Int)
    case stackIndex(index: Int)
    case parameterCount(_ : Int)
}

struct Variant {
    var value: Value
    
    func string(stack: [Variant]) throws -> String {
        switch value {
        case .empty:
            return ""
        case .string(let str):
            return str
        case .integer(let int):
            return "\(int)"
        case .double(let dbl):
            return "\(dbl)"
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
    
    func integer(stack: [Variant]) throws -> Int {
        switch value {
        case .empty:
            return 0
        case .string(let str):
            return Int(str) ?? 0
        case .integer(let int):
            return int
        case .double(let dbl):
            return Int(dbl)
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
    
    func double(stack: [Variant]) throws -> Double {
        switch value {
        case .empty:
            return 0.0
        case .string(let str):
            return Double(str) ?? 0.0
        case .integer(let int):
            return Double(int)
        case .double(let dbl):
            return dbl
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
    
    func referenceIndex(stack: [Variant]) -> Int? {
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
    
    init() {
        value = .empty
    }
    
    init(_ string: String) {
        value = .string(string)
    }
    
    init(_ integer: Int) {
        value = .integer(integer)
    }
    
    init(_ double: Double) {
        value = .double(double)
    }
    
    init(referenceIndex refIndex: Int) {
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
