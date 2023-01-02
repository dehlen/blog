import Foundation

public struct Site {
    public let baseURL: URL

    public var outputDirectory: URL {
        baseURL / "Site"
    }

    public init(baseDirectory: URL) throws {
        baseURL = baseDirectory
    }

    public func generate() throws -> Set<Resource> {
        let posts = try Post.jekyllPosts(in: baseURL / "Posts")

        let highlight = posts
            .max(by: \.date)!

        let indexedPages: [Page] = [
            posts,
            posts.categoryIndices,
            [
                About(),
                Archive(posts: posts),
                AtomFeed(baseURL: URL(string: "https://davidvonk.dev")!, posts: posts.suffix(10)),
                FrontPage(highlight: highlight)
            ]
        ].flatMap { $0 }

        let allPages = indexedPages + [
            Sitemap(baseURL: URL(string: "https://davidvonk.dev")!, pages: indexedPages)
        ]

        let filters: [Filter] = [
            InlineFilter(baseURL: baseURL / "Resources"),
            MarkdownFilter(),
            PrismFilter(),
            DependencyFilter(),
            ResourceGatheringFilter(baseURL: baseURL / "Resources"),
            XMLEncodingFilter(),
        ]

        let renderedPages = allPages.concurrentMap { $0.render(filters: filters) }

        return renderedPages.reduce([]) { $0.union($1) }
    }
}
