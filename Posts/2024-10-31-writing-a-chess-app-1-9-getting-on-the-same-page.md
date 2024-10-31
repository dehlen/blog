---
color: C07309
date: 2024-10-31T09:52:00Z
description: A blog post series detailing my journey of developing a chess app for iOS and macOS
project: true
title: Writing a chess app (1/9): Getting on the same page 
category: swift
slug: writing-a-chess-app-1-9-getting-on-the-same-page
---

## Motivation

At the beginning of the current month I started writing a chess iOS and macOS app... again. I started a handful of chess apps over the course of the last couple of years but never really finished one. My chess skills really improved since then which is why I wanted to learn a new opening repertoire this year. While researching my options for software assisting me in my intention I found the existing solutions to be lacking. I have two kids and therefore rarely find the time to boot up my MacBook and do actual chess training with some chess database software. Most of the time I am lucky to have a few spare minutes on my phone so the optimal solution would be an iOS app which I could use "on-the-go" for my specific use case while having a counterpart on my MacBook when dealing with the joy of having free time.


## Chess terminology

For the start of this series I want to get us all on the same page so you can follow the rest of the blog posts if you are interested in software development but not necessarily in chess. 
When building and discussing a chess app, you often come across certain technical terms that are essential for both understanding the game and how it’s represented in software. Here’s a quick rundown:

### Chessboard Files and Ranks

The chessboard is divided into files and ranks to identify square positions. Files are the vertical columns labeled a through h from left to right, while ranks are the horizontal rows labeled 1 through 8 from bottom to top. Together, they form a coordinate system for identifying squares (e.g., e4). 

Reference: [Chessboard](https://en.wikipedia.org/wiki/Chessboard)

### SAN (Standard Algebraic Notation)

SAN is the standard way of recording chess moves in text, specifying each move with just enough detail to understand what was played. SAN includes the piece moved, the destination square, and any captures or special moves. It is concise and universally understood in chess. If two or more identical pieces can move to the same square the notation accounts for this with standardized disambiguation rules.

Example of SAN moves:

- `e4`: Move pawn to e4
- `Bb5`: Move bishop to b5
- `O-O`: Kingside castling
- `O-O-O`: Queenside castling
- `exd4`: Move pawn to d4 with a capture
- `Qh4+`: Queen moves to h4 and gives a check
- `Qg7#`: Queen moves to g7 and delivers mate
- `e8=Q#`: Pawn moves to e8, is promoted to a queen and delivers checkmate

Reference: [Standard Algebraic Notation](https://en.wikipedia.org/wiki/Algebraic_notation_(chess))

### FEN (Forsyth-Edwards Notation)

FEN is a standard notation used to represent the current state of a chessboard. It includes information on piece placement, active color, castling rights, en passant target squares, and move counters totalling in six fields, each seperated by a space. FEN strings allow a game position to be saved or shared easily, making it essential for loading a specific position in a chess app.

Example FEN for the starting position:

`rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1`

A quick explanation of the specific fields in the given example FEN:
- `rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR`: This encodes the piece placement data. Each rank is described starting at rank 8 up to rank 1, separated by a `/`. Within a rank the contents of the squares are described from the a to h file. Empty squares are described with a digit ranging from 1 to 8 (for consecutive empty squares), while piece information is encoded in algebraic notation
- `w`: White is to move
- `KQkq`: White and black can still castle king or queenside
- `-`: There is no en passant target square
- `0`: The number of halfmoves since the last capture or pawn advance
- `1`: The number of full moves, starting at 1

We will explore this notation in more detail when talking about parsing a FEN to extract the encoded position from it.

Reference: [Forsyth–Edwards Notation](https://en.wikipedia.org/wiki/Forsyth–Edwards_Notation)

### Variations (or Lines)

A **line** or **variation** refers to any sequence of moves that can arise from a specific opening. We typically distinguish between the mainline and sidelines.

A **mainline** refers to the most popular and extensively studied sequence of moves within a particular opening. These moves are generally considered the best responses according to established theory. 

In contrast to this **sidelines** are alternative moves or sequences that diverge from the mainline. While they may not be as popular or theoretically sound as the mainline moves, sidelines can still be effective and surprise opponents who are less familiar with them.

### PGN (Portable Game Notation)

PGN is a notation format used to record entire chess games, move by move, along with additional information like players’ names, date, and location. PGN is popular for saving and sharing chess games, as it allows both humans and software to read and interpret the game data.

Example PGN:

```
[Event "IBM Kasparov vs. Deep Blue Rematch"]
[Site "New York, NY USA"]
[Date "1997.05.11"]
[Round "6"]
[White "Deep Blue"]
[Black "Kasparov, Garry"]
[Opening "Caro-Kann: 4...Nd7"]
[ECO "B17"]
[Result "1-0"]

1. e4 c6 2. d4 d5 3. Nc3 dxe4 4. Nxe4 Nd7 5. Ng5 Ngf6 6. Bd3 e6 7. N1f3 h6 8. Nxe6 Qe7 9. O-O fxe6 10. Bg6+ Kd8 {Kasparov is shaking his head} 11. Bf4 b5 12. a4 Bb7 13. Re1 Nd5 14. Bg3 Kc8 15. axb5 cxb5 16. Qd3 Bc6 17. Bf5 exf5 18. Rxe7 Bxe7 19. c4 1-0
```

Parsing a PGN will be our topic in the next part of this series. If you want to read up on it for more details here is a reference link for you to look at:
[Portable Game Notation](https://de.wikipedia.org/wiki/Portable_Game_Notation)

### NAG (Numeric Annotation Glyphs)

NAG are numeric codes added to moves to indicate specific annotations. Some commonly used NAGs are typically represented with a character sequence such as "!" (good move) or "??" (blunder) while other glyphs are encoded in the form of `$<number>`. NAGs provide a quick way to annotate moves without verbose commentary, which is helpful for both users and software to analyze moves made in a game.

Examples:

`1. e4! e5 2. Qg4?`

Reference: [Numeric Annotation Glyphs](https://en.wikipedia.org/wiki/Numeric_Annotation_Glyphs)

### Chess Engines

A chess engine is the software core that analyzes positions, evaluates moves, and calculates optimal strategies. Engines range from basic AI with minimal calculation depth to advanced, powerful programs like Stockfish that use deep evaluation techniques. Integrating a chess engine into an app allows users to play against a computer or analyze their games. The best engine in terms of playing strength currently is stockfish which happens to be open source. Over the course of this blog post series we will have a look on how to integrate this engine in our application to analyze games locally on device and provide valuable input to the user.

### Repertoire

A chess repertoire refers to a collection of openings, strategies, and plans that a player has prepared and is comfortable using in their games. Essentially, it is a personalized library of moves that a player has studied and practiced, designed to suit their playing style and preferences.

**Key points**:
- **Personalized**: Each player’s repertoire is unique, reflecting their strengths, weaknesses, and preferred strategies.
- **Openings and Responses**: It typically includes various openings and the corresponding responses to different opponent moves.
- **Preparation**: Players often invest time in preparing their repertoire to gain an advantage in the opening phase of the game.
- **Adaptability**: A good repertoire can evolve over time as players learn new strategies or adjust to different opponents.

## Conclusion

Understanding these terms is essential for both developers and chess enthusiasts to navigate and use chess apps effectively. As mentioned above we will look first at parsing PGN files in the next part of this series as it is a fundamental part of the project.