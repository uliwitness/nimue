/// Swift errors thrown by the variant class.
public enum VariantError: Error {
    /// Expected a normal user-serviceable value, but found a stack pointer on the stack. Internal/security error.
    case attemptToAccessSavedBackPointer
    /// Expected a normal user-serviceable value, but found an instruction pointer on the stack. Internal/security error.
    case attemptToAccessSavedProgramCounter
    /// Expected a normal user-serviceable value, but found the parameter count on the stack. Internal/security error.
    case attemptToAccessParameterCount
    /// Expected a normal user-serviceable value, but found a native object on the stack. Internal/security error.
    case attemptToAccessNativeObject
    /// Expected a stack pointer on the stack, but found a value of a different type. Internal/security error.
    case expectedSavedBackPointer
    /// Expected an instruction pointer on the stack, but found a value of a different type. Internal/security error.
    case expectedSavedProgramCounter
    /// Expected an instruction pointer on the stack, but found a value of a different type. Internal/security error.
    case expectedParameterCount
    /// Expected an integer, but found a value that can't be converted into an integral number, like a fractional number or some text.
    case expectedIntegerHere
    /// Expected a number, but found a value that can't be converted into a number, like some text.
    case expectedNumberHere
    /// Expected "true" or "false" here, but found some other text or a number.
    case expectedBooleanHere
    /// Expected a native object on the stack, but found a value of a different type. Internal/security error.
    case expectedNativeObject
}

/// Adapter to let us store weak references in the Value enum.
struct WeakHolder: Equatable {
    weak var object: HyperTalkObject?
}

/// The type as which Variant stores all its possible kinds of contents.
enum Value: Equatable {
    /// No value has been set yet. Can be treated like an empty string by scripters, but can be distinguished i.e. to find out whether an array item is missing or empty.
    case unset
    /// An empty string.
    case empty
    /// A string (possibly empty).
    case string(_ value: String)
    /// A non-fractional number.
    case integer(_ value: Int)
    /// A fractional number, or an integral number internally stored as a fractional number (e.g. because it is the result of adding two fractional numbers)
    case double(_ value: Double)
    /// A boolean truth value, either "true" or "false".
    case boolean(_ value: Bool)
    /// A reference to a value elsewhere on the stack.
    case reference(originalIndex: Int)
    /// The position of an instruction in the instructions array. This is used internally to store return addresses on the stack and should not be accessed by scripters. Doing so should result in a VariantError.attemptToAccessSavedProgramCounter.
    case instructionIndex(index: Int)
    /// The position of a value on the stack. This is used internally to store the base pointer on the stack and should not be accessed by scripters. Doing so should result in a VariantError.attemptToAccessSavedBackPointer.
    case stackIndex(index: Int)
    /// The parameter count of a handler call on the stack. This is used internally to allow variable parameter counts and should not be accessed by scripters except indirectly when asking for the parameter count or retrieving a parameter value. Violating this should result in a VariantError.attemptToAccessParameterCount.
    case parameterCount(_ : Int)
    /// A native Swift object. This is used internally to allow using native objects in the implementation. Violating this should result in a VariantError.attemptToAccessParameterCount.
    case nativeObject(_ : HyperTalkObject)
    /// Version of nativeObject that references the object weakly.
    case weakNativeObject(_ : WeakHolder)
}

/// A single data type that can hold all data types supported by the scripting language and will convert between types where appropriate to maintain our "everything is a string" illusion.
/// This type is used for the elements of the stack (as in, where variables and parameters go) and as such supports some additional internal types that the scripting language does not expose.
public struct Variant: Equatable {
    var value: Value
    
    /// Retrieve this value's contents as a text string.
    public func string(stack: [Variant]) throws -> String {
        switch value {
        case .unset:
            return ""
        case .empty:
            return ""
        case .string(let str):
            return str
        case .integer(let int):
            return "\(int)"
        case .double(let dbl):
            let int = Int(dbl)
            if Double(int) == dbl { return "\(int)" }
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
        case .nativeObject(_):
            throw VariantError.attemptToAccessNativeObject
        case .weakNativeObject(_):
            throw VariantError.attemptToAccessNativeObject
        }
    }
    
    /// Retrieve this value's contents as an integral number.
    public func integer(stack: [Variant]) throws -> Int {
        switch value {
        case .unset:
            throw VariantError.expectedIntegerHere
        case .empty:
            throw VariantError.expectedIntegerHere
        case .string(let str):
            return Int(str) ?? 0
        case .integer(let int):
            return int
        case .double(let dbl):
            let int = Int(dbl)
            if Double(int) == dbl { return int }
            throw VariantError.expectedIntegerHere
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
        case .nativeObject(_):
            throw VariantError.attemptToAccessNativeObject
        case .weakNativeObject(_):
            throw VariantError.attemptToAccessNativeObject
        }
    }
    
    /// Retrieve this value's contents as an floating point number.
    public func double(stack: [Variant]) throws -> Double {
        switch value {
        case .unset:
            throw VariantError.expectedNumberHere
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
        case .nativeObject(_):
            throw VariantError.attemptToAccessNativeObject
        case .weakNativeObject(_):
            throw VariantError.attemptToAccessNativeObject
        }
    }
    
    /// Retrieve this value's contents as a boolean truth value.
    /// Note that 0 and 1 are not valid booleans in HyperTalk, however the strings "true" and "false" are,
    /// as is to be expected with our "everything is a string" philosophy.
    public func boolean(stack: [Variant]) throws -> Bool {
        switch value {
        case .unset:
            throw VariantError.expectedBooleanHere
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
        case .nativeObject(_):
            throw VariantError.attemptToAccessNativeObject
        case .weakNativeObject(_):
            throw VariantError.attemptToAccessNativeObject
        }
    }
    
    /// Retrieve this value's contents as an integral number. If conversion is not possible, returns
    /// `nil` instead of throwing. Mainly intended to let mathematical operators fall back to integer
    /// operations when both arguments can be made into integers.
    /// - warning: trying to access an internal data type as an integer via this method will throw
    ///             and not return `nil`.
    public func integerIfPossible(stack: [Variant]) throws -> Int? {
        switch value {
        case .unset:
            return nil
        case .empty:
            return nil
        case .string(let str):
            return Int(str)
        case .integer(let int):
            return int
        case .double(let dbl):
            guard Double(Int(dbl)) == dbl else { return nil }
            return Int(dbl)
        case .boolean(_):
            return nil
        case .reference(let index):
            return try stack[index].integerIfPossible(stack: stack)
        case .instructionIndex(_):
            throw VariantError.attemptToAccessSavedProgramCounter
        case .stackIndex(_):
            throw VariantError.attemptToAccessSavedBackPointer
        case .parameterCount(_):
            throw VariantError.attemptToAccessParameterCount
        case .nativeObject(_):
            throw VariantError.attemptToAccessNativeObject
        case .weakNativeObject(_):
            throw VariantError.attemptToAccessNativeObject
        }
    }

    /// Retrieve the stack index this variant refers to, or NIL if this variant is not a reference but an immediate value.
    public func referenceIndex(stack: [Variant]) -> Int? {
        if case let .reference(index) = value {
            return stack[index].referenceIndex(stack: stack) ?? index
        }
        return nil
    }
    
    /// Retrieve the stack index in this variant, if this variant is a stack index (like the base pointer).
    /// If the value is any other type, this throws. Mainly intended for restoring the base pointer at the end of handler calls
    func stackIndex() throws -> Int {
        if case let .stackIndex(index) = value {
            return index
        }
        
        throw VariantError.expectedSavedBackPointer
    }
    
    /// Retrieve the instruction index in this variant, if this variant is a instruction index (like the return address).
    /// If the value is any other type, this throws. Mainly intended for returning to the call site at the end of handler calls
    func instructionIndex() throws -> Int {
        if case let .instructionIndex(index) = value {
            return index
        }
        
        throw VariantError.expectedSavedProgramCounter
    }
    
    /// Retrieve the parameter count stored in this variant, if this variant is a parameter count.
    /// If the value is any other type, this throws. Mainly intended for accessing parameters safely even if a handler is passed fewer parameters than it expects, and for allowing variable parameter counts.
    func parameterCount() throws -> Int {
        if case let .parameterCount(index) = value {
            return index
        }
        
        throw VariantError.expectedParameterCount
    }
    
    /// Retrieve the native object referenced in this variant, if this variant is a native object.
    /// If the value is any other type, or is a weak reference that has gone away, this throws.
    func nativeObject<T>() throws -> T {
        if case let .nativeObject(obj) = value,
            let object = obj as? T {
            return object
        } else if case let .weakNativeObject(obj) = value,
            let object = obj.object as? T {
            return object
        }
        
        throw VariantError.expectedNativeObject
    }

    /// Retrieve the native object referenced in this variant, if this variant is a native object.
    /// If the value is a weak native object, this may return NIL if the referenced object has gone away.
    /// If the value is any other type, this throws.
    func nativeObject<T: HyperTalkObject>() throws -> T? {
        if case let .nativeObject(obj) = value {
            if let object = obj as? T {
                return object
            }
            return nil
        } else if case let .weakNativeObject(obj) = value {
            if let object = obj.object as? T {
                return object
            }
            return nil
        }
        
        throw VariantError.expectedNativeObject
    }

    func hyperTalkPropertyValue(_ name: String, stack:  [Variant]) throws -> Variant {
        if case let .nativeObject(object) = value {
            return try object.hyperTalkPropertyValue(name)
        } else if case let .weakNativeObject(object) = value {
            guard let object = object.object else { throw RuntimeError.objectDoesNotExist }
            return try object.hyperTalkPropertyValue(name)
        } else if name == "length" {
            return try Variant(string(stack: stack).count)
        } else {
            throw RuntimeError.unknownProperty(name)
        }
    }
    
    func setHyperTalkProperty(_ name: String, to newValue: Variant, stack: inout [Variant]) throws {
        if case let .nativeObject(object) = value {
            return try object.setHyperTalkProperty(name, to: newValue)
        } else if name == "length" {
            throw RuntimeError.cantChangeReadOnlyProperty(name)
        } else {
            throw RuntimeError.unknownProperty(name)
        }
    }

    /// Create an unset value, an empty string that can be detected as never having been set to a value (sort-of equivalent to NIL in Objective-C).
    public init() {
        value = .unset
    }
    
    /// Create a value containing a string.
    public init(_ string: String) {
        if string.isEmpty {
            value = .empty
        } else {
            value = .string(string)
        }
    }
    
    /// Create a value containing an integral number.
    public init(_ integer: Int) {
        value = .integer(integer)
    }
    
    /// Create a value containing a floating point number.
    public init(_ double: Double) {
        value = .double(double)
    }
    
    /// Create a value containing a boolean truth value.
    public init(_ boolean: Bool) {
        value = .boolean(boolean)
    }
    
    /// Create a value referencing another value on the stack.
    public init(referenceIndex refIndex: Int) {
        value = .reference(originalIndex: refIndex)
    }
    
    /// Create a value saving a stack location (e.g. for restoring the base pointer after a handler call).
    /// This is an internal, "hard" type that shouldn't be converted or stored to disk.
    init(stackIndex refIndex: Int) {
        value = .stackIndex(index: refIndex)
    }
    
    /// Create a value saving a instruction location (e.g. for the return address after a handler call).
    /// This is an internal, "hard" type that shouldn't be converted or stored to disk.
    init(instructionIndex refIndex: Int) {
        value = .instructionIndex(index: refIndex)
    }
    
    /// Create a value saving a parameter count (used mainly by handlers that support a variable argument count and for sanity checking).
    /// This is an internal, "hard" type that shouldn't be converted or stored to disk.
    init(parameterCount: Int) {
        value = .parameterCount(parameterCount)
    }
    
    /// Create a value referencing a native object.
    /// This is an internal, "hard" type that shouldn't be converted or stored to disk.
    init(nativeObject object: HyperTalkObject) {
        value = .nativeObject(object)
    }
    
    /// Create a value referencing a native object, but only as a weak reference.
    /// This is an internal, "hard" type that shouldn't be converted or stored to disk.
    init(weakNativeObject object: HyperTalkObject) {
        value = .weakNativeObject(WeakHolder(object: object))
    }
}
