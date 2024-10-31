---
color: C07309
date: 2024-10-31T11:52:00Z
description: A blog post series detailing my journey of developing a chess app for iOS and macOS
project: true
title: Writing a chess app (3/9): Implementation of the actual chess logic
category: swift
slug: writing-a-chess-app-3-9-implementation-of-the-actual-chess-logic
---

Before starting with the various implementation details I would like to point you to the superb website at [chessprogramming.org](https://www.chessprogramming.org/). A lot of the algorithms and concepts I'll try to demonstrate in the following chapters are discussed there in great detail. 

## Bitboards

[Reference](https://www.chessprogramming.org/Bitboards)

When developing a chess application, one of the key components you'll need to handle is the representation of the chessboard and pieces. One efficient way to represent the board is through the use of **bitboards**.

A bitboard is a compact representation of a chessboard using a 64-bit integer. Each bit in the integer corresponds to a square on the chessboard. For example, in a standard 8x8 chessboard layout:

- The least significant bit (LSB) represents a1 (the bottom-left square).
- The most significant bit (MSB) represents h8 (the top-right square).

In a bitboard, each piece type (e.g., pawns, knights, bishops) can be represented as a separate 64-bit integer. With this representation, you can perform operations on the entire board or on individual pieces using bitwise operations.

**Advantages of Using Bitboards**

1. **Memory Efficiency**: A bitboard uses only 8 bytes (64 bits) to represent an entire chessboard, which is significantly more efficient than using a 2D array of objects.
    
2. **Speed**: Bitwise operations (AND, OR, NOT, XOR) are extremely fast and can be leveraged to quickly calculate moves, attacks, and other game states.
    
3. **Simplicity in Move Generation**: Bitboards simplify the implementation of move generation algorithms. For example, you can easily calculate possible moves for a knight by using precomputed masks and bitwise operations.
    
4. **Parallelism**: Bitboards can take advantage of modern CPU architectures by allowing operations on multiple bits simultaneously, which can lead to performance improvements.

To make this point more clear let's look at the following example: 
Assume we have a attack set of a queen, and like to know whether the queen attacks opponent pieces it may capture, we need to 'and' the queen-attacks with the set of opponent pieces.

```
queen attacks    &  opponent pieces  =  attacked pieces
. . . . . . . .     1 . . 1 1 . . 1     . . . . . . . .
. . . 1 . . 1 .     1 . 1 1 1 1 1 .     . . . 1 . . 1 .
. 1 . 1 . 1 . .     . 1 . . . . . 1     . 1 . . . . . .
. . 1 1 1 . . .     . . . . . . . .     . . . . . . . .
1 1 1 * 1 1 1 .  &  . . . * . . 1 .  =  . . . * . . 1 .
. . 1 1 1 . . .     . . . . . . . .     . . . . . . . .
. . . 1 . 1 . .     . . . . . . . .     . . . . . . . .
. . . 1 . . . .     . . . . . . . .     . . . . . . . .
```


Representing the demonstrated idea in Swift code is actually easier than one might think when confronted with the idea for the first time. Here is my solution for that problem:

```swift
// A set of squares represented by a 64 bit integer mask, using little endian
/// rank-file (LERF) mapping.
///
/// ```
///  8 | 56 57 58 59 60 61 62 63
///  7 | 48 49 50 51 52 53 54 55
///  6 | 40 41 42 43 44 45 46 47
///  5 | 32 33 34 35 36 37 38 39
///  4 | 24 25 26 27 28 29 30 31
///  3 | 16 17 18 19 20 21 22 23
///  2 | 8  9  10 11 12 13 14 15
///  1 | 0  1  2  3  4  5  6  7
///    -------------------------
///      a  b  c  d  e  f  g  h
/// ```
public struct SquareSet: Hashable, CustomStringConvertible, Sendable {
    /// 64 bit integer representing the square set.
    public let value: UInt64
    
    /// Creates a `SquareSet` with the provided 64bit integer value.
    public init(value: UInt64) {
        self.value = value
    }
    
    /// Creates a `SquareSet` with a single `Square`.
    public init(square: Square) {
        precondition(square >= 0 && square < 64)
        self.value = 1 << square
    }
    
    /// Creates a `SquareSet` from several `Square`s.
    public init(squares: Set<Square>) {
        self.value = squares.map {
            1 << $0
        }.reduce(0, |)
    }
    
    /// Create a `SquareSet` containing all squares of the given rank.
    public init(rank: Int) {
        precondition(rank >= 0 && rank < 8)
        self.value = 0xff << (8 * rank)
    }
    
    /// Create a `SquareSet` containing all squares of the given file.
    public init(file: Int) {
        precondition(file >= 0 && file < 8)
        self.value = 0x0101010101010101 << file
    }
    
    /// Create a `SquareSet` containing all squares of the given backrank `Side`.
    public init(backrankOf side: Side) {
        self.value = side == Side.white ? 0xff : 0xff00000000000000
    }
    
    public static let empty = SquareSet(value: 0)
    public static let full = SquareSet(value: 0xffffffffffffffff)
    public static let lightSquares = SquareSet(value: 0x55AA55AA55AA55AA)
    public static let darkSquares = SquareSet(value: 0xAA55AA55AA55AA55)
    public static let diagonal = SquareSet(value: 0x8040201008040201)
    public static let antidiagonal = SquareSet(value: 0x0102040810204080)
    public static let corners = SquareSet(value: 0x8100000000000081)
    public static let center = SquareSet(value: 0x0000001818000000)
    public static let backranks = SquareSet(value: 0xff000000000000ff)
   
    
    /// Bitwise right shift
    public func shr(shift: Int) -> SquareSet {
        if shift >= 64 {
            return SquareSet.empty
        }
        if shift > 0 {
            return SquareSet(value: value >> shift)
        }
        return self
    }
    
    /// Bitwise left shift
    public func shl(shift: Int) -> SquareSet {
        if shift >= 64 {
            return SquareSet.empty
        }
        if shift > 0 {
            return SquareSet(value: value << shift)
        }
        return self
    }
    
    public func xor(_ other: SquareSet) -> SquareSet {
        SquareSet(value: value ^ other.value)
    }
    
    public static func ^ (lhs: SquareSet, rhs: SquareSet) -> SquareSet {
        lhs.xor(rhs)
    }
    
    public func union(_ other: SquareSet) -> SquareSet {
        SquareSet(value: value | other.value)
    }
    
    public static func | (lhs: SquareSet, rhs: SquareSet) -> SquareSet {
        lhs.union(rhs)
    }
    
    public func intersect(_ other: SquareSet) -> SquareSet {
        SquareSet(value: value & other.value)
    }
    
    public static func & (lhs: SquareSet, rhs: SquareSet) -> SquareSet {
        lhs.intersect(rhs)
    }
    
    /// Wrapping subtract
    /// UInt64(100).wrappingSub(100) == 0
    /// UInt64(100).wrappingSub(UInt64.max) == 101
    public func minus(_ other: SquareSet) -> SquareSet {
        SquareSet(value: (value &- other.value) & UInt64.max)
    }
    
    public static func - (lhs: SquareSet, rhs: SquareSet) -> SquareSet {
        lhs.minus(rhs)
    }
    
    public func complement() -> SquareSet {
        SquareSet(value: ~value)
    }
    
    public func diff(_ other: SquareSet) -> SquareSet {
        SquareSet(value: value & ~other.value)
    }
    
    public func flipVertical() -> SquareSet {
        let x = 0x00FF00FF00FF00FF as UInt64
        let y = 0x0000FFFF0000FFFF as UInt64
        var n = self.value
        n = ((n >>  8) & x) | ((n & x) <<  8)
        n = ((n >> 16) & y) | ((n & y) << 16)
        n =  (n >> 32)      |       (n << 32)
        return SquareSet(value: n)
    }

    public func mirrorHorizontal() -> SquareSet {
        let x = 0x5555555555555555 as UInt64
        let y = 0x3333333333333333 as UInt64
        let z = 0x0F0F0F0F0F0F0F0F as UInt64
        var n = self.value
        n = ((n >> 1) & x) | ((n & x) << 1)
        n = ((n >> 2) & y) | ((n & y) << 2)
        n = ((n >> 4) & z) | ((n & z) << 4)
        return SquareSet(value: n)
    }
    
    public var size: Int {
        popcnt64(n: value)
    }
    
    public var isEmpty: Bool { value == 0 }
    public var isNotEmpty: Bool { value != 0 }
    
    public var first: Int? {
        firstSquare(bitboard: value)
    }
    
    public var last: Int? {
        lastSquare(bitboard: value)
    }
    
    public var squares: [Square] {
        var bitboard = value
        var squares = [Int]()
        while bitboard != 0 {
            if let square = firstSquare(bitboard: bitboard) {
                squares.append(square)
                bitboard ^= 1 << square
            }
        }
        return squares
    }
    
    public var reversedSquares: [Square] {
        var bitboard = value
        var squares = [Int]()
        while bitboard != 0 {
            if let square = lastSquare(bitboard: bitboard) {
                squares.append(square)
                bitboard ^= 1 << square
            }
        }
        return squares
    }
    
    public var moreThanOne: Bool {
        isNotEmpty && size > 1
    }
     
    /// Returns square if it is single, otherwise returns null.
    public var singleSquare: Int? {
        moreThanOne ? nil : last
    }
    
    public func has(square: Square) -> Bool {
        precondition(square >= 0 && square < 64)
        return value & (1 << square) != 0
    }
    
    public func isIntersected(with other: SquareSet) -> Bool {
        intersect(other).isNotEmpty
    }
    
    public func isDisjoint(with other: SquareSet) -> Bool {
        intersect(other).isEmpty
    }
    
    public func with(square: Square) -> SquareSet {
        precondition(square >= 0 && square < 64)
        let new = value | (1 << square)
        return SquareSet(value: new)
    }
    
    public func without(square: Square) -> SquareSet {
        precondition(square >= 0 && square < 64)
        return SquareSet(value: value & ~(1 << square))
      }
    
    public func toggle(square: Square) -> SquareSet {
        precondition(square >= 0 && square < 64)
        return SquareSet(value: value ^ (1 << square))
      }
    
    public func withoutFirst() -> SquareSet {
        if let first {
            without(square: first)
        } else {
            SquareSet.empty
        }
    }
    
    public var description: String {
        let buffer = (0...63).reversed().reduce(into: "") { result, square in
            result.append(has(square: square) ? "1" : "0")
        }
        guard let firstInt = Int(buffer.prefix(32), radix: 2),
              let secondInt = Int(buffer.suffix(32), radix: 2) else {
            return "SquareSet(?)"
        }
        let first = String(firstInt, radix: 16).uppercased().leftPad(upTo: 8, using: "0")
        let last = String(secondInt, radix: 16).uppercased().leftPad(upTo: 8, using: "0")
        let stringVal = "\(first)\(last)"
        if stringVal == "0000000000000000" {
            return "SquareSet(0)"
        }
        return "SquareSet(0x\(stringVal))"
    }
    
    /// Prints the square set as a human readable string format
    public var humanReadableSquareSet: String {
        var buffer = ""
        for y in (0..<8).reversed() {
            for x in 0..<8 {
                let square = x + y * 8
                buffer.append(has(square: square) ? "1" : ".")
                buffer.append(x < 7 ? " " : "\n")
            }
        }
        return buffer
    }
    
    private func firstSquare(bitboard: UInt64) -> Int? {
        let ntz = ntz64(x: bitboard)
        return ntz >= 0 && ntz < 64 ? ntz : nil
    }

    private func lastSquare(bitboard: UInt64) -> Int? {
        if bitboard == 0  {
            return nil
        }
        return 63 - nlz64(x: bitboard)
    }
    
    private func popcnt64(n: UInt64) -> Int {
        n.nonzeroBitCount
    }

    private func nlz64(x: UInt64) -> Int {
        x.leadingZeroBitCount
    }

    private func ntz64(x: UInt64) -> Int {
        return x.trailingZeroBitCount
    }
}
```

## FEN Parsing

[Reference](https://www.chessprogramming.org/Forsyth-Edwards_Notation#Shredder-FEN)

With bitboards implemented we have an extremely performant way to implement our chess logic like finding valid moves, or determining whether a check or checkmate is delivered on the board.

What we need to have a look at next is parsing a FEN encoded chess position as this is, as we learned, an integral part of encoding a given chess position.

Lets do a quick recap at what we are looking at. A FEN consists of 6 parts:
`rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1`

```
<FEN> ::=  <Piece Placement>
       ' ' <Side to move>
       ' ' <Castling ability>
       ' ' <En passant target square>
       ' ' <Halfmove clock>
       ' ' <Fullmove counter>
```

My FEN parser implementation is relaxed. Missing FEN fields will be accepted (except the board part) and will be filled with default values. Also FEN fields can either be separated by a space or by an underscore.

Various FEN extensions like [X-FEN](https://en.wikipedia.org/wiki/X-FEN) and [Shredder-FEN](https://www.chessprogramming.org/Forsyth-Edwards_Notation#Shredder-FEN) exist, as well as some differences in piece placement data notation for chess variants like Crazyhouse ([Promotion Status in FEN data](https://fairy-stockfish.github.io/chess-variant-standards/fen.html)). While my parser supports these I won't talk about that in detail as I think this is not really relevant for the problem at hand. 

First the FEN string is split into the various parts:

```swift
var parts = fen.split(whereSeparator: { $0.isWhitespace || $0 == "_" })
```

After each part is successfully parsed I remove it from the array. Before dealing with the most interesting part, the piece placement data, lets quickly have a look at the other parts of a FEN. Extracting the information which player's turn it is seems pretty straight forward:

```swift
let turn: Side
if parts.isEmpty {
	// relaxed parsing: default to white
    turn = .white
} else {
	// remove part from the array of yet to be parsed parts
    let turnPart = parts.removeFirst()
    if turnPart == "w" {
        turn = .white
    } else if turnPart == "b" {
        turn = .black
    } else {
        throw FenError.invalidTurn(String(turnPart))
    }
}
```

The other parts are similarly easy and I won't go into detail for everyone of them. 
Let's look at the more interesting part, the piece placement data.

We start with an empty board and with the last rank and first file as we learned in the first part of this series. Next we loop over every character in the string. If we encounter a `/` and are positioned at the last file of a rank we move on to the next rank. Otherwise we move on with our parsing logic. At this point we examine whether we are currently looking at a number or a character. If a number is found this means we are dealing with one or more empty squares so we can just skip those and move on. If a character is found we check whether the character is lowercased or uppercased to determine whether a white or a black piece is encoded. Ultimately we determine the actual piece information based on the predefined map and update our board representation.

```
<Piece Placement> ::= <rank8>'/'<rank7>'/'<rank6>'/'<rank5>'/'<rank4>'/'<rank3>'/'<rank2>'/'<rank1>
<ranki>       ::= [<digit17>]<piece> {[<digit17>]<piece>} [<digit17>] | '8'
<piece>       ::= <white Piece> | <black Piece>
<digit17>     ::= '1' | '2' | '3' | '4' | '5' | '6' | '7'
<white Piece> ::= 'P' | 'N' | 'B' | 'R' | 'Q' | 'K'
<black Piece> ::= 'p' | 'n' | 'b' | 'r' | 'q' | 'k'
```

```swift
init(fen: String) throws(FenError) {
    var board = Board.empty
    var rank = 7
    var file = 0
    
    for i in fen.indices {
        let character = fen[i]
        if character == "/" && file == 8 {
            file = 0
            rank -= 1
        } else {
            if character.isNumber, let number = Int(String(character)) {
                file += number
            } else {
                if file >= 8 || rank < 0 {
                    throw FenError.invalidBoardCoordinates(file, rank)
                }
                
                let square = file + rank * 8
                guard let piece = Piece(char: String(character)) else {
                    throw FenError.invalidPiece(String(character))
                }
                board = board.set(piece: piece, at: square)
                file += 1
            }
        }
    }
    
    if rank != 0 || file != 8 {
        throw FenError.invalidBoardCoordinates(file, rank)
    }
    
    self = board
}
```

And with that we are able to read any given FEN string and convert this into our custom board data structure.

## SAN Parsing

[Reference](https://www.chessprogramming.org/Algebraic_Chess_Notation#Standard_Algebraic_Notation_.28SAN.29)

As this post is already quite lengthy I will only briefly talk about some of the challenges parsing SANs:

1. Castling notation can either be represented with the letter `O` or the number `0` so your implementation should be able to handle both.
2. If two or more identical pieces can move to the same square the notation accounts for this with standardized disambiguation rules. The parser needs to be able to handle those cases.

Other than that it is pretty straight-forward to extract the source and destination square, as well as the promotion information from a given SAN into a move value type.
In my implementation I also check for move validity with the help of my bitboard implementation. To round things up lets look at an example on how to parse a castling notation like `O-O`.

```swift
if san == "O-O" {
    guard
        let king = board.king(of: turn),
        let rook = castles.rook(of: turn, castlingSide: .king)
    else {
        return nil
    }
    let move = Move(from: king, to: rook)
    if !isLegal(move: move) {
        return nil
    }
    return move
}

func king(of side: Side ) -> Square? {
    return by(piece: Piece(color: side, role: Role.king)).singleSquare
}

func by(piece: Piece) -> SquareSet {
    by(side: piece.color) & by(role: piece.role)
}

func by(side: Side) -> SquareSet {
    side == Side.white ? white : black
}

func by(role: Role) -> SquareSet {
    switch role {
    case Role.pawn:
        return pawns
    case Role.knight:
        return knights
    case Role.bishop:
        return bishops
    case Role.rook:
        return rooks
    case Role.queen:
        return queens
    case Role.king:
        return kings
    }
}

// These are the bitboards for a given position
// This is just an example for the initial standard chess board position
// In a given position your bitboards might look different due to the fact that the pieces are already
// captured or on a different square, a piece was promoted etc.
let white = SquareSet(value: 0xffff)
let black = SquareSet(value: 0xffff000000000000)
let pawns: SquareSet(value: 0x00ff00000000ff00),
let knights: SquareSet(value: 0x4200000000000042),
let bishops: SquareSet(value: 0x2400000000000024),
let rooks: SquareSet.corners,
let queens: SquareSet(value: 0x0800000000000008),
let kings: SquareSet(value: 0x1000000000000010)

// Again this is the initial standard position, your bitboards may vary...
let castles = Castles(
    castlingRights: SquareSet.corners,
    whiteRookQueenSide: Squares.a1,
    whiteRookKingSide: Squares.h1,
    blackRookQueenSide: Squares.a8,
    blackRookKingSide: Squares.h8,
    whitePathQueenSide: SquareSet(value: 0x000000000000000e),
    whitePathKingSide: SquareSet(value: 0x0000000000000060),
    blackPathQueenSide: SquareSet(value: 0x0e00000000000000),
    blackPathKingSide: SquareSet(value: 0x6000000000000000)
)

extension Castles {
    func rook(of side: Side, castlingSide: CastlingSide) -> Square? {
        return if castlingSide == CastlingSide.queen {
            if side == .white {
                whiteRookQueenSide
            } else {
                blackRookQueenSide
            }
        } else {
            if side == .white {
                whiteRookKingSide
            } else {
                blackRookKingSide
            }
        }
    }
}
```

What is actually happening here? Lets say it is whites turn to play. So a SAN like O-O would mean to castle the white king to safety on the kingside. But how do we find the square the white king is currently positioned at? There are several options to choose from but since we are using bitboards to represent the chessboard we have a very performant way to do so. To find the white kings position all we have to do is to take the bitboard of all white pieces and build the intersection of the bitboard encoding all king pieces. The result should be a bitboard containing only one `1` representing the white king piece. As we learned the bitboard ist a UInt64 with each bit representing a square so to convert this binary value to the actual square all we need to do is to solve this rather trivial equation: `square = 64 - 1 - leadingZeroBitCount`.

## Conclusion

This was quite a lot to cover and I tried my best to keep it concise where I could. Building a package to handle all the related chess logic is quite a big task as you can see. Fortunately some open source packages exist where you can draw inspiration from or which can help you if you are stuck with the problem at hand. I hope this little overview helped you understand what it takes to build a full-blown chess logic package. Next up I'd like to talk about representing the game of chess not only in data but also on screen with a handful of UI components.