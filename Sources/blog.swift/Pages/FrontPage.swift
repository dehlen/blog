import Foundation
import HTML
import Swim

fileprivate func token(summary: String, @NodeBuilder children: () -> NodeConvertible = { Node.fragment([]) }) -> Node {
    span(class: "token", customAttributes: ["data-summary": summary]) {
        children()
    }
}

struct FrontPage: Page {
    static let defaultLayout: Layout = .basic

    let title = "David v.Knobelsdorff"

    let pathComponents = [] as [String]

    var highlight: Page

    func content() -> Node {
        header(id: "header") {
            style {
                InlineFilter.inline(file: "css/intro.css")
            }

            section(id: "intro") {
                p {
                    em { "Hi" } %% ", my name is"
                    token(summary: "David") {
                        "David v.Knobelsdorff"
                    } %% "."
                }

                p {
                    "Iʼm working at "
                    a(href: "https://dmtech.de") {
                        "dmTECH"
                    } %% "."
                }

                p {
                    .raw("I&nbsp;")
                    %%
                        token(summary: "live in Landau") {
                        "live in Landau, Germany with my wife and my two sons"
                    }
                    %%
                    .raw(".&nbsp;")
                    %%
                    span(class: "shake") {
                       "👋🏻"
                    }
                }
            }

            p {
                "You can read about my latest project:"
                a(href: highlight.path) { highlight.title }
                "or browse through the"
                a(href: "/archive") {
                    "archive"
                } %% "."
                
                "You can also"
                a(href: "/about") {
                    "learn more about me"
                }
                "or follow me on"
                a(href: "https://github.com/dehlen") {
                    "GitHub"
                }
                "and"
                a(href: "https://chaos.social/@dvk") {
                    "Mastodon"
                } %% "."
                
                "To never miss a post you can also subscribe to my"
                a(href: "/atom.xml") {
                    "RSS Feed"
                } %% "."
            }

            script(type: "text/javascript") {
                InlineFilter.inline(file: "js/intro.js")
            }
        }
    }
}
