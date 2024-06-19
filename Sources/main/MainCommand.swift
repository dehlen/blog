import ArgumentParser
import Foundation
import blog_swift

struct Build: ParsableCommand {
    func run() throws {
        print("Building the site.")

        let site = try Site(baseDirectory: Main.path)
        let resources = try Array(site.generate())

        resources
            .forEach { resource in
                do {
                    try resource.write(relativeTo: site.outputDirectory)
                } catch {
                    print(resource.path, error)
                }
            }
    }
}


@main
struct Main: AsyncParsableCommand {
    static let path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static let configuration = CommandConfiguration(
        abstract: "A static site generator for https://davidvonk.dev",
        subcommands: [
            Build.self
        ],
        defaultSubcommand: Build.self)
}
