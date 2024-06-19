import ArgumentParser
import blog_swift

struct Run: ParsableCommand {
    @Option(name: .shortAndLong, help: "The port of the web server.")
    var port: Int = 3000
    
    func run() throws {
        let generator = WebsiteGenerator()
        let folder = try generator.run()
        
        let runner = WebsiteRunner(folder: folder, port: port)
        try runner.run()
    }
}
