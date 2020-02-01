import Foundation

public enum ParseError: Error {
    case expectedFunctionName
    case expectedEndOfLine
    case expectedIdentifier(string: String)
    case expectedOperator(string: String)
    case expectedInteger
    case expectedNumber
    case expectedString
    case expectedValue
}


fileprivate let identifierCS = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
fileprivate let operatorCS = CharacterSet.punctuationCharacters.union(CharacterSet.symbols)
fileprivate let whitespaceCS = CharacterSet.whitespaces
fileprivate let newlineCS = CharacterSet.newlines

public struct Token {
    enum Kind {
        case quotedString(_: String)
        case unquotedString(_: String)
        case double(_: Double)
        case integer(_: Int)
        case symbol(_: String)
    }
    
    let kind: Kind
    let offset: String.Index
}

public class Tokenizer: CustomDebugStringConvertible {
    public var tokens = [Token]()
    var currentIndex = 0
    
    var isAtEnd: Bool {
        return currentIndex >= tokens.count
    }
    
    public init() {
        
    }
    
    public func addTokens(for text: String) throws {
        let scanner = Scanner(string: text)
        scanner.caseSensitive = false
        scanner.charactersToBeSkipped = whitespaceCS
        
        while !scanner.isAtEnd {
            _ = scanner.scanCharacters(from: whitespaceCS)
            let offset = scanner.currentIndex
            if scanner.scanString("\"") != nil {
                scanner.charactersToBeSkipped = nil
                defer { scanner.charactersToBeSkipped = whitespaceCS }
                guard let str = scanner.scanUpToString("\"") else { throw ParseError.expectedOperator(string: "\"") }
                tokens.append(Token(kind: .quotedString(str), offset: offset))
                scanner.charactersToBeSkipped = CharacterSet.whitespaces
                _ = scanner.scanString("\"")
            } else if let string = scanner.scanCharacters(from: operatorCS) {
                string.forEach { tokens.append(Token(kind: .symbol(String($0)), offset: offset)) }
            } else if let numStr = scanner.scanCharacters(from: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))) {
                if numStr.contains(".") {
                    tokens.append(Token(kind: .double(Double(numStr) ?? 0.0), offset: offset))
                } else {
                    tokens.append(Token(kind: .integer(Int(numStr) ?? 0), offset: offset))
                }
            } else if let string = scanner.scanCharacters(from: identifierCS) {
                tokens.append(Token(kind: .unquotedString(string), offset: offset))
            } else if scanner.scanCharacters(from: newlineCS) != nil {
                tokens.append(Token(kind: .symbol(String("\n")), offset: offset))
            }
        }
    }
    
    @discardableResult
    func expectIdentifier(_ expectedIdentifier: String? = nil) throws -> String {
        if isAtEnd {
            throw ParseError.expectedIdentifier(string: expectedIdentifier ?? "")
        }
        if case let .unquotedString(string) = tokens[currentIndex].kind {
            if expectedIdentifier == nil {
                currentIndex += 1
                return string
            } else if let expectedIdentifier = expectedIdentifier, expectedIdentifier == string {
                currentIndex += 1
                return string
            }
        }
        
        throw ParseError.expectedIdentifier(string: expectedIdentifier ?? "")
    }

    func hasIdentifier(_ expectedIdentifier: String? = nil) -> Bool {
        if isAtEnd {
            return false
        }
        if case let .unquotedString(string) = tokens[currentIndex].kind {
            if expectedIdentifier == nil {
                return true
            } else if let expectedIdentifier = expectedIdentifier, expectedIdentifier == string {
                return true
            }
        }
        
        return false
    }

    @discardableResult
    func expectString(allowUnquoted: Bool = false) throws -> String {
        if isAtEnd {
            throw ParseError.expectedString
        }
        if case let .quotedString(string) = tokens[currentIndex].kind {
                currentIndex += 1
                return string
        } else if allowUnquoted, case let .unquotedString(string) = tokens[currentIndex].kind {
                currentIndex += 1
                return string
        }
        
        throw ParseError.expectedString
    }
    
    func hasString(allowUnquoted: Bool = false) -> Bool {
        if isAtEnd {
            return false
        }
        if case .quotedString(_) = tokens[currentIndex].kind {
            return true
        } else if allowUnquoted, case .unquotedString(_) = tokens[currentIndex].kind {
            return true
        }
        
        return false
    }

    func expectInteger() throws -> Int {
        if isAtEnd {
            throw ParseError.expectedInteger
        }
        if case let .integer(num) = tokens[currentIndex].kind {
            currentIndex += 1
            return num
        }
        
        throw ParseError.expectedInteger
    }
    
    func hasInteger() -> Bool {
        if isAtEnd {
            return false
        }
        if case .integer(_) = tokens[currentIndex].kind {
            return true
        }
        
        return false
    }

    func expectNumber() throws -> Double {
        if isAtEnd {
            throw ParseError.expectedNumber
        }
        if case let .integer(num) = tokens[currentIndex].kind {
            currentIndex += 1
            return Double(num)
        } else if case let .double(num) = tokens[currentIndex].kind {
            currentIndex += 1
            return num
        }
        
        throw ParseError.expectedNumber
    }
    
    func hasNumber() -> Bool {
        if isAtEnd {
            return false
        }
        if case .integer(_) = tokens[currentIndex].kind {
            return true
        } else if case .double(_) = tokens[currentIndex].kind {
            return true
        }
        
        return false
    }

    @discardableResult
    func expectSymbol(_ expectedSymbol: String? = nil) throws -> String {
        if isAtEnd {
            throw ParseError.expectedOperator(string: expectedSymbol ?? "")
        }
        if case let .symbol(string) = tokens[currentIndex].kind {
            if expectedSymbol == nil {
                currentIndex += 1
                return string
            } else if let expectedSymbol = expectedSymbol, expectedSymbol == string {
                currentIndex += 1
                return string
            }
        }
        
        throw ParseError.expectedOperator(string: expectedSymbol ?? "")
    }
    
    func hasSymbol(_ expectedSymbol: String? = nil) -> Bool {
        if isAtEnd {
            return false
        }
        if case let .symbol(string) = tokens[currentIndex].kind {
            if expectedSymbol == nil {
                return true
            } else if let expectedSymbol = expectedSymbol, expectedSymbol == string {
                return true
            }
        }
        
        return false
    }
    
    func expectNewline() throws {
        try expectSymbol("\n")
    }
    
    func hasNewline() -> Bool {
        return hasSymbol("\n")
    }
    
    func skipNewlines() {
        if isAtEnd { return }
        while case let .symbol(string) = tokens[currentIndex].kind {
            guard string != "\n" else { break }
            currentIndex += 1
            if isAtEnd { break }
        }
    }
    
    func skipLine() {
        while true {
            if isAtEnd { return }
            if case let .symbol(string) = tokens[currentIndex].kind, string == "\n" {
                currentIndex += 1
                break
            }
            currentIndex += 1
        }
    }

    public var debugDescription: String {
        var str = "Tokenizer {\n"
        
        var lastWasLineBreak = true
        for token in tokens {
            if lastWasLineBreak { str += "\t" }
            lastWasLineBreak = false
            switch token.kind {
            case .symbol(let string):
                if string == "\n" {
                    str += "⮐\n"
                    lastWasLineBreak = true
                } else {
                    str += "[\(string)], "
                }
            case .quotedString(let string):
                str += "\"\(string)\", "
            case .unquotedString(let string):
                str += "\(string), "
            case .integer(let num):
                str += "\(num)L, "
            case .double(let num):
                str += "\(num)F, "
            }
        }
        if !lastWasLineBreak { str += "\n" }
        str += "}"
        
        return str
    }
}
