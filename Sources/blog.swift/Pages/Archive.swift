import Foundation
import HTML

struct Archive: Page {
    var posts: [Post]

    let title = "Archive"

    let pathComponents = [ "archive" ]

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