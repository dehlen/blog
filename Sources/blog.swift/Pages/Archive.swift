import Foundation
import HTML

struct Archive: Page {
    var posts: [Post]

    let title = "Archive"

    let pathComponents = [ "archive" ]

    func content() -> Node {
        posts.sliced(by: [.year], for: \.date).map { (key: Date, value: [Post]) -> Node in
            .fragment(
                [
                    h2 { "\(key.formatted(.year()))" },
                    ul {
                        value
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
                ].asNode()
            )
        }.flatMap { $0 }
    }
}

private extension Array {
  func sliced(by dateComponents: Set<Calendar.Component>, for key: KeyPath<Element, Date>) -> [Date: [Element]] {
    let initial: [Date: [Element]] = [:]
    let groupedByDateComponents = reduce(into: initial) { acc, cur in
      let components = Calendar.current.dateComponents(dateComponents, from: cur[keyPath: key])
      let date = Calendar.current.date(from: components)!
      let existing = acc[date] ?? []
      acc[date] = existing + [cur]
    }

    return groupedByDateComponents
  }
}