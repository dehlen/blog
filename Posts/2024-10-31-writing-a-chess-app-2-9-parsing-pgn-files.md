---
color: C07309
date: 2024-10-31T10:52:00Z
description: A blog post series detailing my journey of developing a chess app for iOS and macOS
project: true
title: Writing a chess app (2/9): Parsing pgn files
category: swift
slug: writing-a-chess-app-2-9-parsing-pgn-files
---

As learned in part 1 of this series a chess game can be represented via the Portable Game Notation. It is the de-facto standard to represent a chess game. So when building a chess application we need to deal with this file format and find a performant way to extract information out of it. One would think that there exists a ton of high-quality open-source packages to deal with this topic. Unfortunately I could find only a handful of really robust, performant solutions and none of them are built in Swift. I probably could have taken a Rust implementation or something similiar, compile a static library and write some shims around the API but this time I felt like it would be a fun challenge to come up with my own solution. 

The problem with a lot of the existing implementations is that they either make extensive use of regex which hurts the performance quite a bit or they do not implement the full PGN specification. For example I only found a few implementations which actually dealt with comments in PGN files. Comments however are a pretty big part of my repertoires since they help me not only memorizing moves but also to understand them better. I briefly tried some parser generators based on some PGN grammar I found online but at least the Swift generators were too slow for my needs which is why I ultimately decided to built a custom PGN parser from the ground up.

## PGN Specification

We already looked at PGN files on a high-level in part 1 of this blog post series. Now lets examine it a bit closer.

A PGN file typically consists of two main parts:

- **Tags**: These are metadata that provide information about the game.
- **Moves**: The actual moves made during the game.

### Tags

Tags are enclosed in square brackets and provide various details about the game. 

**Example:**

- `[Event "Event Name"]`: Name of the tournament or match.
- `[Site "Location"]`: Where the game took place.
- `[Date "YYYY.MM.DD"]`: Date of the game.
- `[Round "Round Number"]`: Round in the tournament.
- `[White "Player Name"]`: Name of the player with the white pieces.
- `[Black "Player Name"]`: Name of the player with the black pieces.
- `[Result "Result"]`: Outcome of the game (e.g., "1-0", "0-1", "1/2-1/2").

There is a list of common tag names but potentially you can add any tag you like. The seven tags above are standard for a valid PGN file and are called the Seven Tag Roaster.

### Moves

The moves of the game follow the tags and are recorded in standard algebraic notation. Each move is separated by a space, and turns are indicated by numbering:

- **Move Number**: Each full turn (White and Black) is numbered.
- **Move Notation**: Moves are represented using standard algebraic notation

**Example:**

```
1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. d3 d6 7. c3 O-O 8. Nbd2 Nb8 9. Re1 Nbd7 10. Nf1
```

### Results

At the end of the moves, the result is indicated using the Result tag. The possible results are:

- `"1-0"`: White wins
- `"0-1"`: Black wins
- `"1/2-1/2"`: Draw
- `"*"`: Unknown/Ongoing

### Comments

Comments are inserted by either a `;` (a comment that continues to the end of the line) or a `{` (which continues until a `}`). Comments do not nest.

**Example:**

```
1. e4 e5 2. Nf3 {This is a common opening.} Nc6 3. Bb5
```

### Variations

A variation is a sequence of movetext containing one or more alternative moves enclosed in parentheses. The alternate move sequence given by a variation is one that may be legally played by first unplaying the move that appears immediately prior to the parantheses. Because a variation is a recursive construct, it may be nested.

**Example:**

```
1. e4 e5 2. Nf3 Nc6 (2... d6) 3. Bb5
```

### Multiple Games

A PGN file can contain multiple games, separated by an empty line.

### Encoding

PGN files are typically encoded in UTF-8, which allows for the inclusion of special characters.

## Buffered reading

PGN files can get quite large, or at least large enough to consider parser performance and the overall memory footprint when dealing with these files. This lead me to a rabbit hole researching various buffered reading solutions available for the iOS and macOS platforms. This is one area where I found various options which probably all will work for the given task. The most promising solution I found is to use `BufferedReader` from swift-nio [API Documentation](https://swiftinit.org/docs/swift-nio/_niofilesystem/bufferedreader). However at the end I did not want to include such a big dependency like swift-nio in my package. Therefore I opted for implementing a simple RingBuffer data structure with the help of [TPCircularBuffer](https://github.com/michaeltyson/TPCircularBuffer) in combination with `FileHandle.read(upToCount:)` [API Documentation](https://developer.apple.com/documentation/foundation/filehandle/3516317-read) to solve the task at hand. In the following I'll present you a trimmed down version of my solution:

```swift
final class RingByteBuffer {
    let size: Int
    private var buffer: TPCircularBuffer
    
    init(size: Int) {
        self.size = size
        self.buffer = TPCircularBuffer()
        TPCircularBufferInit(&self.buffer, Int32(size))
    }
    
    deinit {
        TPCircularBufferCleanup(&self.buffer)
    }
    
    func enqueue(data: Data) -> Bool {
        return data.withUnsafeBytes { buffer -> Bool in
            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }
            return TPCircularBufferProduceBytes(&self.buffer, UnsafeRawPointer(bytes), Int32(data.count))
        }
    }
    
    func enqueue(_ bytes: UnsafeRawPointer, count: Int) -> Bool {
        return TPCircularBufferProduceBytes(&self.buffer, bytes, Int32(count))
    }
    
    func withMutableHeadBytes(_ f: (UnsafeMutableRawPointer, Int) -> Int) {
        var availableBytes: Int32 = 0
        let bytes = TPCircularBufferHead(&self.buffer, &availableBytes)
        let enqueuedBytes = f(bytes!, Int(availableBytes))
        TPCircularBufferProduce(&self.buffer, Int32(enqueuedBytes))
    }
    
    func space() -> (UnsafeMutableRawPointer, Int) {
        var availableBytes: Int32 = 0
        let bytes = TPCircularBufferHead(&self.buffer, &availableBytes)
        return (bytes!, Int(availableBytes))
    }
    
    func fill(_ count: Int) {
        TPCircularBufferProduce(&self.buffer, Int32(count))
    }
    
    func dequeue(_ bytes: UnsafeMutableRawPointer, count: Int) -> Int {
        var availableBytes: Int32 = 0
        let tail = TPCircularBufferTail(&self.buffer, &availableBytes)
        
        let copiedCount = min(count, Int(availableBytes))
        memcpy(bytes, tail, copiedCount)
        
        TPCircularBufferConsume(&self.buffer, Int32(copiedCount))
        
        return copiedCount
    }
    
    func dequeue(count: Int) -> Data {
        var availableBytes: Int32 = 0
        let tail = TPCircularBufferTail(&self.buffer, &availableBytes)
        
        let copiedCount = min(count, Int(availableBytes))
        let bytes = malloc(copiedCount)!
        memcpy(bytes, tail, copiedCount)
        
        TPCircularBufferConsume(&self.buffer, Int32(copiedCount))
        
        return Data(bytesNoCopy: bytes.assumingMemoryBound(to: UInt8.self), count: copiedCount, deallocator: .free)
    }
    
    func clear() {
        TPCircularBufferClear(&self.buffer)
    }
    
    var availableBytes: Int {
        var count: Int32 = 0
        TPCircularBufferTail(&self.buffer, &count)
        return Int(count)
    }
    
    var data: [UInt8] {
        var availableBytes: Int32 = 0
        guard let tail = TPCircularBufferTail(&self.buffer, &availableBytes) else { return [] }
        let pointer = tail.bindMemory(to: UInt8.self, capacity: Int(availableBytes))
        return Array(UnsafeBufferPointer(start: pointer, count: Int(availableBytes)))
    }
}

struct Buffer {
    let size: Int
    var inner: RingByteBuffer

    init(size: Int) {
        self.size = size
        self.inner = RingByteBuffer(size: size * 2)
    }
}

struct BufferedReader {
    var inner: any Read
    var buffer: Buffer
    
    init(url: URL, bufferSize: Int = 1024 * 8) throws {
        let fileHandle = try FileHandle(forReadingFrom: url)
        let fileHandleReader = FileHandleReader(fileHandle: fileHandle)
        let buffer = Buffer(size: bufferSize)
        self.inner = fileHandleReader
        self.buffer = buffer
    }

    mutating func fillBufferAndPeek() -> UInt8? {
        while buffer.inner.availableBytes < buffer.size {
            do {
                let (ptr, count) = buffer.inner.space()
                let remainder = UnsafeMutableRawBufferPointer(start: ptr, count: count)
                let size = try inner.read(into: remainder)
                if size == 0 { break }
                buffer.inner.fill(size)
            } catch {
                break
            }
        }

        return buffer.inner.data.first
    }

    func data() -> [UInt8] {
        return buffer.inner.data
    }

    mutating func consume(_ n: Int) {
        _ = buffer.inner.dequeue(count: n)
    }

    func peek() -> UInt8? {
        return buffer.inner.data.first
    }

    mutating func bump() -> UInt8? {
        let head = peek()
        if head != nil {
            consume(1)
        }
        return head
    }

    func remaining() -> Int {
        return buffer.inner.availableBytes
    }

    mutating func consumeAll() {
        let remaining = buffer.inner.availableBytes
        consume(remaining)
    }
}
```

With this in place we can assure that the reader itself does not allocate (besides a single fixed-size buffer) which keeps the memory footprint of our solution to a minimum.

## Visitor pattern

The Visitor Pattern is a design pattern that allows you to separate an algorithm from the object structure on which it operates. This is particularly useful in the context of a parser implementation, where you may want to perform various operations on a complex data structure without modifying the structure itself.

I chose this approach due to the following key points which I think are pretty valuable in terms of performance, flexibility and ease of use:

- The visitor can decide if and how to represent games in memory.
- The reader does not validate move legality. This allows implementing support for custom chess variants, or delaying move validation.

For reference here is the protocol I built to represent a visitor for the PGN parser implementation:

```swift
protocol Visitor {
    associatedtype VisitorResult

    func beginGame()
    
    func beginHeaders()
    func header(key: String, value: String)
    func endHeaders()
    
    func san(_ san: String)
    func nag(_ nag: Nag)
    func comment(_ comment: String)
    
    func beginVariation()
    func endVariation()
    
    func outcome(_ outcome: Outcome)
    
    func endGame() -> VisitorResult
}
```
 
## Implementing a parser

So now that we have a good understanding about the PGN file format, can read PGN files quite efficiently in terms of memory consumption and have a visitor interface in place to transform the parsed data all that is left is actually implementing the parsing logic to tell a concrete visitor instance about the parsed information.

```swift
mutating func readGame<V: Visitor>(visitor: V) throws -> V.VisitorResult? {
    reader.skipBom()
    reader.skipWhitespace()
    
    guard let _ = reader.fillBufferAndPeek() else {
        return nil
    }
    
    visitor.beginGame()
    visitor.beginHeaders()
    try self.readHeaders(visitor: visitor)
    visitor.endHeaders()
    try self.readMoveText(visitor: visitor)

    reader.skipWhitespace()
    return visitor.endGame()
}
```

## Benchmarks

One burning question remains unanswered though. How fast is it? To answer this question I ran some benchmarks on my implementation. 

The benchmark was run with a PGN file I downloaded from the [Lichess database](https://database.lichess.org/standard) (~ 1,000,000 games, ~ 1 GB uncompressed) on an Apple M1 MacBook Pro with 32 GB RAM.

My simple benchmark visitor counts up statistics on the PGN file (how many games are available in this file, etc.):

```swift
class Stats {
    var games: Int = 0
    var headers: Int = 0
    var sans: Int = 0
    var nags: Int = 0
    var comments: Int = 0
    var variations: Int = 0
    var outcomes: Int = 0
}

struct StatsVisitor: Visitor {
    typealias VisitorResult = Stats
    let stats = Stats()

    func beginGame() {}
    
    func beginHeaders() {}
    
    func header(key: String, value: String) {
        stats.headers += 1
    }
    
    func endHeaders() {}
    
    func san(_ san: String) {
        stats.sans += 1
    }
    
    func nag(_ nag: PGNKit.Nag) {
        stats.nags += 1
    }
    
    func comment(_ comment: String) {
        stats.comments += 1
    }
    
    func beginVariation() {}
    
    func endVariation() {
        stats.variations += 1
    }
    
    func outcome(_ outcome: PGNKit.Outcome) {
        stats.outcomes += 1
    }
    
    func endGame() -> Stats {
        stats.games += 1
        return stats
    }
}
```

I then used the [swift-benchmark](https://github.com/google/swift-benchmark) package to actually execute my test.

Here are the results:

- **Time**: 28,19s
- **Throughput**: 38,12 MB/s

To my eye it seems like there still is room for improvement comparing against highly optimized solutions build in different languages. However parsing 1 GB of chess games in about half a minute while being able to support the full specification is more than fine for my use case. My typical chess dataset is a couple of megabytes in size. At a later point I might want to revisit this implementation though and see if I can find the culprit slowing it down. For the moment I am more than happy with the results. What do you think?