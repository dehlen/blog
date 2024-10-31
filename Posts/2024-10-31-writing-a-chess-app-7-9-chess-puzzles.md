---
color: C07309
date: 2024-10-31T15:52:00Z
description: A blog post series detailing my journey of developing a chess app for iOS and macOS
project: true
title: Writing a chess app (7/9): Chess puzzles
category: swift
slug: writing-a-chess-app-7-9-chess-puzzles
---

## What are chess puzzles?

Chess puzzles are specially crafted scenarios in which players are presented with a specific position on the chessboard. The objective is to find the best move or sequence of moves to achieve a particular goal, such as checkmating the opponent, winning material, or escaping from a difficult situation. These puzzles serve as a training tool for players of all skill levels, from beginners to grandmasters.

### Types of Chess Puzzles

1. **Checkmate Puzzles**: These puzzles require the player to deliver checkmate in a certain number of moves. They are often categorized by the number of moves needed to achieve checkmate, such as "mate in 1," "mate in 2," etc.
    
2. **Tactical Puzzles**: These focus on specific tactical themes, such as forks, pins, skewers, and discovered attacks. Solving these puzzles helps players recognize tactical opportunities during real games.
    
3. **Endgame Puzzles**: These involve positions that arise in the endgame phase of chess. They often test players' understanding of key endgame concepts and techniques.
    
4. **Defensive Puzzles**: In these scenarios, the player must find the best defensive move to avoid losing material or getting checkmated.

To conclude puzzles are of tremendous help in improving your overall chess skills especially in terms of pattern recognition. This is the reason why I wanted to incorporate puzzle training into my chess training app.

## Datasource for chess puzzles

Fortunately lichess offers a huge catalog of chess puzzles you can use in your application. At the time of writing the database consists of **4,211,138** puzzles which are also categorized. 

On their [website](https://database.lichess.org/#puzzles) they state:
> Lichess games and puzzles are released under the [Creative Commons CC0 license](https://tldrlegal.com/license/creative-commons-cc0-1.0-universal). Use them for research, commercial purpose, publication, anything you like. You can download, modify and redistribute them, without asking for permission.

And I think that is wonderful.

## Implementation

In the previous parts we already talked about SAN, FEN and PGN Parsing. We also have a catalog of UI components which can be used to display a chess board and play moves. GRDB.swift is integrated into project as well to help with reading from a sqlite database. Therefore everything is in place to build the puzzle feature in the application.

I downloaded a database dump and added it to my app project. Next I created some models to read from it via GRDB.swift. Creating a list of possible categories and adding some puzzle modes was trivial with the help of SwiftUI. I added two playing modes:

1. Puzzle Streak: Trying to solve as many puzzles as possible without a mistake, with each puzzle getting trickier.
2. Puzzle Storm: Trying to solve as many puzzles as possible in a limited amount of time.

This is something which existing online platforms like lichess solve pretty well already. However I wanted to add this functionality to my app as well to have a full featured application solving all my various needs in terms of training my chess skills.

In the upcoming part of this series we will examine chess engines and how we can leverage them in our project.