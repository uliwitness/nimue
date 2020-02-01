import HyperTalk

do {
    let text = try String(contentsOfFile: CommandLine.arguments[1])
    
    let tokenizer = Tokenizer()
    try tokenizer.addTokens(for: text)
    print("\(tokenizer)")
    
    let parser = Parser()
    try parser.parse(tokenizer)

    print("\(parser.script)")

    var context = RunContext(script: parser.script)
    try! context.run("main")
} catch {
    print("Error: \(error)")
}
