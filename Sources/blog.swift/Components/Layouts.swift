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
        style {
            InlineFilter.inline(file: "css/navigation.css")
        }
        h1 {
            a(href: "/") { "davidvonk.dev" }
        }
        ul {
            li {
                a(href: "/about") { "About Me" }
            }
            li {
                a(href: "/archive") { "Archive" }
            }
            li {
                a(href: "/atom.xml") { "RSS" }
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
                    
                    (page as? Post).map { post -> Node in
                        return .fragment([
                            meta(content: "summary", name: "twitter:card"),
                            meta(content: "@da_eh", name: "twitter:site"),
                            meta(content: post.title, name: "twitter:title"),
                            post.image.map {
                                meta(content: "https://davidvonk.dev" + $0, name: "twitter:image")
                            },
                            post.description.map {
                                meta(content: $0, name: "twitter:description")
                            }
                        ].compactMap { $0 })
                    } ?? []

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
            header(id: "header") {
                navigation
            }

            section(id: "content") {
                content()
            }
        }
    }
}
