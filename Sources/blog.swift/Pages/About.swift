import Foundation
import HTML

struct About: Page {
    let title = "About"

    let pathComponents = [ "about" ]

    func content() -> Node {
        MarkdownFilter.markdown {
            InlineFilter.inline(file: "md/about.md")
        }
    }
}
