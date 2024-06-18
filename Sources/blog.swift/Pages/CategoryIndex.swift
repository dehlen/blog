import Foundation
import HTML

struct CategoryIndex: Page {
    var posts: [Post]

    var title: String

    var pathComponents: [String]

    init(category: String, posts: [Post]) {
        precondition(!category.contains("/"))

        self.posts = posts
        self.title = category.titlecased()
        self.pathComponents = [ category ]
    }

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

                        if post.description != nil {
                            br()
                            post.description!
                        }
                    }
            }
        }
    }
}