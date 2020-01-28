enum Value {
    case empty
    case string(_ value: String)
    case integer(_ value: Int)
    case double(_ value: Double)
    case reference(originalIndex: Int)
}

struct Variant {
    var value: Value
    
    func string(stack: [Variant]) -> String {
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
            return stack[index].string(stack: stack)
        }
    }
    
    func integer(stack: [Variant]) -> Int {
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
            return stack[index].integer(stack: stack)
        }
    }
    
    func double(stack: [Variant]) -> Double {
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
            return stack[index].double(stack: stack)
        }
    }
    
    func referenceIndex(stack: [Variant]) -> Int? {
        if case let .reference(index) = value {
            return stack[index].referenceIndex(stack: stack)
        }
        return nil
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
}
