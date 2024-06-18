import Foundation
import HTML
import Swim

struct FrontPage: Page {
    static let defaultLayout: Layout = .page

    let title = "David v.Knobelsdorff"

    let pathComponents = [] as [String]

    var posts: [Post]

    func content() -> Node {
        h2 { "Latest posts" }
        ul {
            posts
                .reversed()
                .map { post in
                    li {
                        "[ \(format(post.date)) ] "
                        a(href: post.path) {
                            post.title
                        }
                    }
                }
        }
    }
}
