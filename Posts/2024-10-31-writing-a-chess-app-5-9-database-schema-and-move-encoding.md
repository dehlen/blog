---
color: C07309
date: 2024-10-31T13:52:00Z
description: A blog post series detailing my journey of developing a chess app for iOS and macOS
project: true
title: Writing a chess app (5/9): Database Schema and move encoding
category: swift
slug: writing-a-chess-app-5-9-database-schema-and-move-encoding
---

Hello and welcome to the next part of my ongoing blog post series of writing a chess app for iOS and macOS.
In this part I'd like to talk about my design decision regarding the database schema.
So lets dive in.

## Database Schema

For the database schema I heavily leaned on on the work of [ocgdb](https://github.com/nguyenpham/ocgdb). It is an open database format, is actually quite performant to store and search chess games and is the best excuse to use one of my favourite Swift packages ([GRDB.swift](https://github.com/groue/GRDB.swift)). Besides the obvious benefits the open source chess database software [En Croissant](https://encroissant.org) also uses the exact same database format and so my choice was being made. 

For reference here is the sqlite schema which I think is pretty self explanatory:

```sql
CREATE TABLE Info (
    Name TEXT UNIQUE NOT NULL,
    Value TEXT
);

CREATE TABLE Events (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Name TEXT UNIQUE
);

CREATE TABLE Sites (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Name TEXT UNIQUE
);

CREATE TABLE Players (
    ID INTEGER PRIMARY KEY,
    Name TEXT UNIQUE,
    Elo INTEGER
);

CREATE TABLE Games (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    EventID INTEGER,
    SiteID INTEGER,
    Date TEXT,
    Round INTEGER,
    WhiteID INTEGER,
    WhiteElo INTEGER,
    BlackID INTEGER,
    BlackElo INTEGER,
    Result INTEGER,
    TimeControl TEXT,
    ECO TEXT,
    PlyCount INTEGER,
    FEN TEXT,
    Moves BLOB,
    FOREIGN KEY(EventID) REFERENCES Events,
    FOREIGN KEY(SiteID) REFERENCES Sites,
    FOREIGN KEY(WhiteID) REFERENCES Players,
    FOREIGN KEY(BlackID) REFERENCES Players
);

CREATE INDEX IF NOT EXISTS games_date_idx ON Games(Date);
CREATE INDEX IF NOT EXISTS games_white_idx ON Games(WhiteID);
CREATE INDEX IF NOT EXISTS games_black_idx ON Games(BlackID);
CREATE INDEX IF NOT EXISTS games_result_idx ON Games(Result);
CREATE INDEX IF NOT EXISTS games_white_elo_idx ON Games(WhiteElo);
CREATE INDEX IF NOT EXISTS games_black_elo_idx ON Games(BlackElo);
CREATE INDEX IF NOT EXISTS games_plycount_idx ON Games(PlyCount);
```

If you had a closer look at the schema you might have noticed that the `Moves` column is specified as a `BLOB`. The idea behind that design decision is discussed in our next chapter.

## Move Encoding

When thinking about how to encode moves into the database several options come to mind. The obvious solution is to store the movetext just as a `TEXT` column and move on. I opted for encoding every chess move with only 2 bytes. This not only makes the actual data that is saved pretty small it also makes encoding and decoding moves trivial. Of course this could be optimized even further but weighting performance and ease of use against each other I ultimately found this solution to be the best fit for my needs.

As we learned at the beginning of this blog post series a chess board has 64 squares and a move can be represented by moving a piece from one square to another square. The piece does not have to be stored itself, since this information is typically retrieved from a FEN string which encodes a chess board quite efficiently. There is a special case when moving a pawn to the backrank of your opponent resulting in promoting your pawn to a queen, knight, bishop or rook. So we need to account for that. If we represent the various promotion options with an integer enum we end up with a single integer ranging from 0-4 to encode a promotion information:

```swift
enum Promotion: Int {
	case empty
	case queen
	case bishop
	case rook
	case knight
}
```

With this in place a move representation can look something like this:

```swift
typealias Square = Int

extension Square {
	var rank: Int {
	    value >> 3
	}
	
	var file: Int {
	    value & 0x7
	}
}

struct Move: Hashable, Equatable, Sendable {
    let from: Square
    let to: Square
    let promotion: Promotion
}
```

There is room for improvement though. You could represent a square with a struct conforming to `RawRepresentable` and `ExpressibleByIntegerLiteral` to actually not pollute the `Int` namespace with our extensions but this is something I haven't looked into yet. As a bonus I added some code to retrieve the file and rank of a given square.

Looking at the above representation of a move lets count how much bits we need to actually store this information.
We need 6 bits for each square (2^6 = 64) and 2 bits (2^2 = 4) to store the promotion information adding up to 14 bits in total which easily fits in an UInt16 or 2 bytes. For completeness sake here are the respective encoding and decoding functions:

```swift
init(encoded: UInt16) {
    let from = encoded & 63
    let to = encoded >> 6 & 63
    let promotion = (encoded >> 12) & 7
    let promotionRole = Promotion(rawValue: Int(promotion))
    self.init(from: Square(from), to: Int(to), promotion: promotionRole)
}

var encoded: UInt16 {
    UInt16(from) | UInt16(to) << 6 | (UInt16(promotion.rawValue)) << 12
}
```

And with that lets move on our next part which will look at spaced repetition training of repertoires.