import ArgumentParser
import blog_swift

struct Build: ParsableCommand {
    func run() throws {
        let generator = WebsiteGenerator()
        try generator.run()
    }
}
