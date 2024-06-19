import ArgumentParser
import Foundation
import blog_swift

@main
struct Main: AsyncParsableCommand {
    static let path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static let configuration = CommandConfiguration(
        abstract: "A static site generator for https://davidvonk.dev",
        subcommands: [
            Build.self,
            Run.self
        ],
        defaultSubcommand: Build.self
    )
}
