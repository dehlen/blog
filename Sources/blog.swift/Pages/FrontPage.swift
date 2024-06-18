import Foundation
import HTML
import Swim

fileprivate func token(summary: String, @NodeBuilder children: () -> NodeConvertible = { Node.fragment([]) }) -> Node {
    span(class: "token", customAttributes: ["data-summary": summary]) {
        children()
    }
}

struct FrontPage: Page {
    static let defaultLayout: Layout = .page

    let title = "David v.Knobelsdorff"

    let pathComponents = [] as [String]

    var posts: [Post]

    func content() -> Node {
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
