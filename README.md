# davidvonk.dev

My personal website, written in Swift.

This site uses [Swim](http://github.com/dehlen/Swim/), a Swift DSL for markup.

## Usage

### Build the website
`swift build -c release && ./.build/release/main build` or just `swift run`

### Run a local web server to test changes
`swift build -c release && ./.build/release/main run --port 3000`
