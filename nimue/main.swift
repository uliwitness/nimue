import HyperTalk

do {
    let filePath = CommandLine.arguments[1]
    let text = try String(contentsOfFile: filePath)
    
    let tokenizer = Tokenizer()
    try tokenizer.addTokens(for: text, filePath: filePath)
    print("\(tokenizer)")
    
    let parser = Parser()
    try parser.parse(tokenizer)

    print("\(parser.script)")

    var context = RunContext(script: parser.script)
    try context.run("main", isCommand: true)
} catch {
    print("Error: \(error)")
}
