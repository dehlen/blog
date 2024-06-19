import Foundation
import HTML

struct Archive: Page {
    var posts: [Post]
    let title = "Archive"
    let pathComponents = [ "archive" ]

    func content() -> Node {
        let nodes: [Node] = posts.sliced(by: [.year], for: \.date).map { (key: Date, value: [Post]) -> Node in
            [
                h2 { "\(key.formatted(.dateTime.year()))" },
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
            ]
        }
        
        return .fragment(nodes.map { $0.asNode() })
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
