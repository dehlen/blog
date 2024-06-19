import Foundation
import blog_swift

struct WebsiteGenerator {
    @discardableResult func run() throws -> URL {
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
        print("Successfully built the site.")
        return site.outputDirectory
    }
}
