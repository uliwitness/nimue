do {
    let text = try String(contentsOfFile: CommandLine.arguments[1])
    let parser = Parser()
    try parser.parse(text)
    
    print("\(parser.script)")
    
    var context = RunContext(script: parser.script)
    try! context.run("main")
} catch {
    print("Error: \(error)")
}
