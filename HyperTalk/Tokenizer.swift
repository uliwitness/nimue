import Foundation

public enum ParseError: Error {
    case expectedFunctionName(token: Token?)
    case expectedEndOfLine(token: Token?)
    case expectedIdentifier(string: String, token: Token?)
    case expectedOperator(string: String, token: Token?)
    case expectedOperandAfterOperator(string: String, token: Token?)
    case expectedInteger(token: Token?)
    case expectedNumber(token: Token?)
    case expectedString(token: Token?)
    case expectedValue(token: Token?)
    case expectedExpression(token: Token?)
    case resultMissing
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index < count && count >= 0 else { return nil }
        return self[index]
    }
}


fileprivate let identifierCS = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
fileprivate let operatorCS = CharacterSet.punctuationCharacters.union(CharacterSet.symbols).subtracting(CharacterSet(charactersIn: "\""))
fileprivate let oneLineCommentStartCS = CharacterSet(charactersIn: "-")
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
    let filePath: String
}

public class Tokenizer: CustomDebugStringConvertible {
    public private(set) var tokens = [Token]()
    public var currentIndex = 0
    
    public var isAtEnd: Bool {
        return currentIndex >= tokens.count
    }
    
    public var currentToken: Token? {
        return tokens[safe: currentIndex]
    }
    
    public static var multiCharOperators = ["&&", "<=", ">="]
    
    public init() {
        
    }
    
    private func addOperatorTokens(from string: String, offset: String.Index, filePath: String) throws {
        var slice = Substring(string)
        while !slice.isEmpty {
            var found = false
            for mco in Tokenizer.multiCharOperators {
                if slice.hasPrefix(mco) {
                    tokens.append(Token(kind: .symbol(mco), offset: offset, filePath: filePath))
                    slice = slice[mco.endIndex ..< slice.endIndex]
                    found = true
                    break
                }
            }
            if !found {
                let singleCharOp = slice.first.map { String($0) } ?? ""
                tokens.append(Token(kind: .symbol(String(singleCharOp)), offset: offset, filePath: filePath))
                slice = slice.dropFirst()
            }
        }
    }
    
    public func addTokens(for text: String, filePath: String) throws {
        let scanner = Scanner(string: text)
        scanner.caseSensitive = false
        scanner.charactersToBeSkipped = whitespaceCS
        
        while !scanner.isAtEnd {
            _ = scanner.scanCharacters(from: whitespaceCS)
            let offset = scanner.currentIndex
            if scanner.scanString("\"") != nil {
                scanner.charactersToBeSkipped = nil
                defer { scanner.charactersToBeSkipped = whitespaceCS }
                guard let str = scanner.scanUpToString("\"") else { throw ParseError.expectedOperator(string: "\"", token: tokens[safe: currentIndex]) }
                tokens.append(Token(kind: .quotedString(str), offset: offset, filePath: filePath))
                scanner.charactersToBeSkipped = CharacterSet.whitespaces
                _ = scanner.scanString("\"")
            } else if let string = scanner.scanCharacters(from: oneLineCommentStartCS) {
                if string.hasPrefix("--") {
                    let comment = scanner.scanUpToCharacters(from: newlineCS)
                    print("Skipping comment: \(comment ?? "")")
                } else {
                    try addOperatorTokens(from: string, offset: offset, filePath: filePath)
                }
            } else if let string = scanner.scanCharacters(from: operatorCS) {
                try addOperatorTokens(from: string, offset: offset, filePath: filePath)
            } else if let numStr = scanner.scanCharacters(from: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))) {
                if numStr.contains(".") {
                    tokens.append(Token(kind: .double(Double(numStr) ?? 0.0), offset: offset, filePath: filePath))
                } else {
                    tokens.append(Token(kind: .integer(Int(numStr) ?? 0), offset: offset, filePath: filePath))
                }
            } else if let string = scanner.scanCharacters(from: identifierCS) {
                tokens.append(Token(kind: .unquotedString(string), offset: offset, filePath: filePath))
            } else if scanner.scanCharacters(from: newlineCS) != nil {
                tokens.append(Token(kind: .symbol(String("\n")), offset: offset, filePath: filePath))
            }
        }
    }
    
    @discardableResult
    func expectIdentifier(_ expectedIdentifier: String? = nil) throws -> String {
        if isAtEnd {
            throw ParseError.expectedIdentifier(string: expectedIdentifier ?? "", token: tokens[safe: currentIndex])
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
        
        throw ParseError.expectedIdentifier(string: expectedIdentifier ?? "", token: tokens[safe: currentIndex])
    }

    func expectIdentifiers(_ expectedIdentifiers: String...) throws {
        try expectIdentifiers(expectedIdentifiers)
    }
    
    func expectIdentifiers(_ expectedIdentifiers: [String]) throws {
        var expectedIndex = 0
        var searchIndex = currentIndex
        while expectedIndex < expectedIdentifiers.count {
            let expectedIdentifier = expectedIdentifiers[expectedIndex]
            if isAtEnd { throw ParseError.expectedIdentifier(string: expectedIdentifier, token: tokens[safe: currentIndex]) }
            guard case let .unquotedString(string) = tokens[searchIndex].kind else {
                throw ParseError.expectedIdentifier(string: expectedIdentifier, token: tokens[safe: currentIndex])
            }
            if expectedIdentifier != string {
                throw ParseError.expectedIdentifier(string: expectedIdentifier, token: tokens[safe: currentIndex])
            }
            searchIndex += 1
            expectedIndex += 1
        }
        
        currentIndex = searchIndex
    }

    func hasIdentifier(_ expectedIdentifier: String? = nil, updateCurrentIndexOnMatch: Bool = false) -> String? {
        if isAtEnd { return nil }
        if case let .unquotedString(string) = tokens[currentIndex].kind {
            if expectedIdentifier == nil {
                if updateCurrentIndexOnMatch { currentIndex += 1 }
                return string
            } else if let expectedIdentifier = expectedIdentifier, expectedIdentifier == string {
                if updateCurrentIndexOnMatch { currentIndex += 1 }
                return string
            }
        }
        
        return nil
    }

    func hasIdentifiers(_ expectedIdentifiers: String..., updateCurrentIndexOnMatch: Bool = false) -> Bool {
        return hasIdentifiers(expectedIdentifiers)
    }
    
    func hasIdentifiers(_ expectedIdentifiers: [String], updateCurrentIndexOnMatch: Bool = false) -> Bool {
        var expectedIndex = 0
        var searchIndex = currentIndex
        while expectedIndex < expectedIdentifiers.count {
            if isAtEnd { return false }
            guard case let .unquotedString(string) = tokens[searchIndex].kind else { return false }
            if expectedIdentifiers[expectedIndex] != string {
                return false
            }
            searchIndex += 1
            expectedIndex += 1
        }
        
        if updateCurrentIndexOnMatch {
            currentIndex = searchIndex
        }
        
        return true
    }

    @discardableResult
    func expectString(allowUnquoted: Bool = false) throws -> String {
        if isAtEnd {
            throw ParseError.expectedString(token: tokens[safe: currentIndex])
        }
        if case let .quotedString(string) = tokens[currentIndex].kind {
            currentIndex += 1
            return string
        } else if allowUnquoted, case let .unquotedString(string) = tokens[currentIndex].kind {
            currentIndex += 1
            return string
        }
        
        throw ParseError.expectedString(token: tokens[safe: currentIndex])
    }
    
    func hasString(allowUnquoted: Bool = false, updateCurrentIndexOnMatch: Bool = false) -> String? {
        if isAtEnd { return nil }
        if case let .quotedString(string) = tokens[currentIndex].kind {
            if updateCurrentIndexOnMatch { currentIndex += 1 }
            return string
        } else if allowUnquoted, case let .unquotedString(string) = tokens[currentIndex].kind {
            if updateCurrentIndexOnMatch { currentIndex += 1 }
            return string
        }
        
        return nil
    }

    func expectInteger() throws -> Int {
        if isAtEnd {
            throw ParseError.expectedInteger(token: tokens[safe: currentIndex])
        }
        if case let .integer(num) = tokens[currentIndex].kind {
            currentIndex += 1
            return num
        }
        
        throw ParseError.expectedInteger(token: tokens[safe: currentIndex])
    }
    
    func hasInteger(updateCurrentIndexOnMatch: Bool = false) -> Int? {
        if isAtEnd { return nil }
        if case let .integer(integer) = tokens[currentIndex].kind {
            if updateCurrentIndexOnMatch { currentIndex += 1 }
            return integer
        }
        
        return nil
    }

    func expectNumber() throws -> Double {
        if isAtEnd {
            throw ParseError.expectedNumber(token: tokens[safe: currentIndex])
        }
        if case let .integer(num) = tokens[currentIndex].kind {
            currentIndex += 1
            return Double(num)
        } else if case let .double(num) = tokens[currentIndex].kind {
            currentIndex += 1
            return num
        }
        
        throw ParseError.expectedNumber(token: tokens[safe: currentIndex])
    }
    
    func hasNumber(updateCurrentIndexOnMatch: Bool = false) -> Double? {
        if isAtEnd { return nil }
        if case let .integer(integer) = tokens[currentIndex].kind {
            if updateCurrentIndexOnMatch { currentIndex += 1 }
            return Double(integer)
        } else if case let .double(double) = tokens[currentIndex].kind {
            if updateCurrentIndexOnMatch { currentIndex += 1 }
            return double
        }
        
        return nil
    }

    @discardableResult
    func expectSymbol(_ expectedSymbol: String? = nil) throws -> String {
        if isAtEnd {
            throw ParseError.expectedOperator(string: expectedSymbol ?? "", token: tokens[safe: currentIndex])
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
        
        throw ParseError.expectedOperator(string: expectedSymbol ?? "", token: tokens[safe: currentIndex])
    }
    
    func hasSymbol(_ expectedSymbol: String? = nil, updateCurrentIndexOnMatch: Bool = false) -> String? {
        if isAtEnd { return nil }
        if case let .symbol(string) = tokens[currentIndex].kind {
            if expectedSymbol == nil {
                if updateCurrentIndexOnMatch { currentIndex += 1 }
                return string
            } else if let expectedSymbol = expectedSymbol, expectedSymbol == string {
                if updateCurrentIndexOnMatch { currentIndex += 1 }
                return string
            }
        }
        
        return nil
    }
    
    func expectNewline() throws {
        try expectSymbol("\n")
    }
    
    func hasNewline() -> Bool {
        return hasSymbol("\n") != nil
    }
    
    func skipNewlines() {
        if isAtEnd { return }
        while case let .symbol(string) = tokens[currentIndex].kind {
            guard string == "\n" else { break }
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
