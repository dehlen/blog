import Foundation
import HTML

struct Layout {
    var template: (Page, () -> Node) -> Node

    init(template: @escaping (Page, () -> Node) -> Node) {
        self.template = template
    }

    func render(page: Page, @NodeBuilder content: () -> Node) -> Node {
        template(page, content)
    }
}

extension Layout {
    private static let navigation = nav(id: "navigation") {
        ul {
            li {
                a(href: "/") { "/" }
            }
            li {
                a(href: "/archive") { "/archive" }
            }
            li {
                a(href: "/about") { "/about" }
            }
            li {
                a(href: "/atom.xml") { "/rss" }
            }
        }
    }

    static let basic = Layout { page, content in
        [
            Node.documentType("html"),
            html(lang: "en-US") {
                head {
                    meta(charset: "utf-8")
                    meta(content: "en-US", httpEquiv: "content-language")

                    meta(content: "David v.Knobelsdorff", name: "author")
                    meta(content: "David v.Knobelsdorff", name: "publisher")
                    meta(content: "David v.Knobelsdorff", name: "copyright")

                    meta(content: "width=device-width, initial-scale=1.0", name: "viewport")

                    meta(content: "interest-cohort=()", httpEquiv: "Permissions-Policy")
                    
                    link(href: "/atom.xml", rel: "alternate", title: "RSS Feed for davidvonk.dev", type: "application/atom+xml")
                    link(href: "https://chaos.social/@dvk", rel: "me")

                    title {
                        page.title; "– davidvonk.dev"
                    }

                    style {
                        InlineFilter.inline(file: "css/base.css")
                    }
                }
                body {
                    content()
                }
            }
        ]
    }

    static let empty = Layout { _, content in content() }

    static let page = Layout { page, content in
        basic.render(page: page) {
            div(class: "layout") {
                header(id: "header") {
                    navigation
                }
                
                main {
                    section(id: "content") {
                        content()
                    }
                }
                
                footer {
                    "follow me on "
                    a(href: "https://chaos.social/@dvk") {
                        "mastodon"
                    }
                }
            }
        }
    }
}
