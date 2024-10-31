---
color: C07309
date: 2024-10-31T14:52:00Z
description: A blog post series detailing my journey of developing a chess app for iOS and macOS
project: true
title: Writing a chess app (6/9): Spaced repetition repertoire training
category: swift
slug: writing-a-chess-app-6-9-spaced-repetition-repertoire-training
---

You probably already heard about the term [Spaced repetition](https://en.wikipedia.org/wiki/Spaced_repetition). Maybe you even used spaced repetition training when learning for an exam or something like this. The most popular online platform to deal with spaced repetition is [Anki](https://apps.ankiweb.net/) flashcards. In chess spaced repetition also I widely known as one of the best techniques to memorize a repertoire and to learn the various moves. Online platforms like [Chessable](https://chessable.com) make use of this learning technique to provide valuable tools to chess players.
One of the more recent developments in this area is the FSRS(Free Spaced Repetition Scheduler) algorithm which I am currently using to develop this feature for my app.

##  FSRS algorithm

I probably won't describe this algorithm better than its developer Jarrett Ye. So without further explanation I highly recommend you to read up on this algorithm through these links:

- [Overview](https://github.com/open-spaced-repetition/fsrs4anki/wiki/ABC-of-FSRS)
- [Reference](https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm)

Furthermore a pretty solid implementation for Swift already exists online on GitHub which is why I didn't look into building my own package and instead decided to build upon this existing one: [swift-fsrs](https://github.com/4rays/swift-fsrs).

Instead I'd like to focus more on the parts I did implement on my own which is the actual repertoire training and how to chose which move to learn and schedule next.

## Tree data structure

A chess repertoire can be represented as a tree, where each node corresponds to a position in a game, and the edges represent possible moves. The root of the tree is the starting position, and the leaves represent the end of a line or a position that has been thoroughly studied. When using a tree data structure we want to look at two main traversing algorithms:

### 1. Depth-First Traversal

Depth-first traversal (DFT) explores as far down a branch of the tree as possible before backtracking. This method can be particularly useful for in-depth study of a specific line in a repertoire.

```swift
func depthFirstTraversal(node: ChessNode) {
    // Mark the node as visited
    visit(node)
    
    // Recursively visit each child node
    for child in node.children {
        depthFirstTraversal(child)
    }
}
```

### 2. Breadth-First Traversal

Breadth-first traversal (BFT), on the other hand, explores all nodes at the present depth level before moving on to nodes at the next depth level. This approach is beneficial for ensuring a well-rounded understanding of the repertoire.

```swift
func breadthFirstTraversal(root: ChessNode) {
    var queue: [ChessNode] = [root]
    
    while !queue.isEmpty {
        let node = queue.removeFirst()
        visit(node)
        
        // Add all child nodes to the queue
        queue.append(contentsOf: node.children)
    }
}
```

To effectively schedule the next move in a chess repertoire using spaced repetition, you can combine the traversal algorithms with a spaced repetition algorithm. Here’s how you might integrate them:

If there are any moves markes as "due for review" present them to the user. If all due moves are reviewed, choose the first move which isn't reviewed yet based on the chosen tree traversal algorithm. Once the user reviewed this move calculate the next interval at which the move should be reviewed again.

For completeness sake I will provide you with my current implementation of a chess game tree which I use to implement the presented algorithms:


```swift
@Observable
public final class Game: CustomStringConvertible, Identifiable, Hashable, Equatable {
    public private(set) var current: GameNode
    public private(set) var root: GameNode
    public private(set) var tags: [String: String]

    init(root: GameNode, tags: [String: String]) {
        self.root = root
        self.current = root
        self.tags = tags
    }
    
    public convenience init(tags: [String: String]) throws {
        if let fen = tags["FEN"] {
            let position = try Position(fen: fen)
            let node = GameNode(position: position)
            self.init(root: node, tags: tags)
        } else {
            self.init(root: GameNode(), tags: tags)
        }
    }
    
    public convenience init() {
        self.init(root: GameNode(), tags: [:])
    }

    public static func == (lhs: Game, rhs: Game) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var id: UUID {
        root.nodeId
    }

    public var ply: Int { current.ply }
    
    public var isAtBeginning: Bool {
        current.isTopNode
    }
    
    public var isAtEnd: Bool {
        current.variations.isEmpty
    }
    
    public func goForward() {
        guard let next = current.variations.first else { return }
        self.current = next
    }
    
    public func goBackward() {
        guard let parent = current.parent else { return }
        self.current = parent
    }
    
    public func goToBeginning() {
        go(to: root)
    }
    
    public func goToEnd() {
        while !isAtEnd {
            goForward()
        }
    }
    
    public func go(to node: GameNode) {
        self.current = node
    }
    
    public func go(to id: UUID) {
        guard let match = root.search(for: id) else { return }
        go(to: match)
    }
    
    public func play(move: Move) throws {
        let newPosition = try current.position.play(move: move)
        let newNode = GameNode(position: newPosition, move: move, parent: current)
        
        let existingNode = current.variations.first { $0.move == move }
        
        if let existingNode {
            go(to: existingNode)
        } else {
            add(node: newNode)
        }
    }
    
    public func add(node: GameNode) {
        current.variations.append(node)
        go(to: node)
    }
    
    public func addMainline(node: GameNode) {
        current.variations.insert(node, at: 0)
        go(to: node)
    }
    
    public func remove(node: GameNode) {
        node.parent?.variations.removeAll(where: {
            $0.nodeId == node.nodeId
        })
    }
    
    public func remove(id: UUID) {
        guard let match = root.search(for: id) else { return }
        remove(node: match)
    }
    
    public func promote(node: GameNode) {
        let variationStart = node.variationStart
        guard let parent = variationStart.parent else { return }
        guard let index = parent.variations.firstIndex(where: {
            $0.nodeId == variationStart.nodeId
        }) else { return }
        if index > 0 {
            parent.variations.swapAt(index, index - 1)
        }
    }
    
    public func promoteToMainline(node: GameNode) {
        let variationStart = node.variationStart
        guard let parent = variationStart.parent else { return }
        guard let index = parent.variations.firstIndex(where: {
            $0.nodeId == variationStart.nodeId
        }), index != 0 else { return }
        
        parent.variations.removeAll(where: {
            $0.nodeId == variationStart.nodeId
        })
        parent.variations.insert(variationStart, at: 0)
    }
    
    public func demote(node: GameNode) {
        let variationStart = node.variationStart
        guard let parent = variationStart.parent else { return }
        guard let index = parent.variations.firstIndex(where: {
            $0.nodeId == variationStart.nodeId
        }) else { return }
        if index < parent.variations.count - 1 {
            parent.variations.swapAt(index, index + 1)
        }
    }
    
    public func traverse(from node: GameNode, visit: (GameNode) -> Void) {
        visit(node)
        for variation in node.variations {
            traverse(from: variation, visit: visit)
        }
    }
    
    public func traverseMainline(from node: GameNode, visit: (GameNode) -> Void) {
        visit(node)
        if let next = node.variations.first {
            traverseMainline(from: next, visit: visit)
        }
    }
    
    public var uciPath: [String] {
        current.reconstructMovesFromBeginning().map(\.uci)
    }
}
```


## Bonus: Finding deviations of your repertoire in your online games

One last bonus before we finish up this part of the blog post series. One main motivation for building my own chess training application was to learn my new repertoire. This meant of course building the spaced repetition feature for training the repertoire. 

One feature I could not find on any of the available platforms though was to analyze my online games in the context of my repertoire. On my MacBook this is fairly simple to do since I can open multiple windows to open my repertoire in some chess database software next to my online game. On iOS this is rather tricky and the user experience left me frustrated. 

Since my application stores my repertoire already I decided to integrate with the lichess and chess.com APIs to download my online games. With the game information available I was able to build a feature where each move of my online games is compared to my repertoire database. If my opponent or I deviate from my repertoire I mark this in the move notation view and provide a link to the respective position in the repertoire. With this little change I now quickly can see where my repertoire needs to be expanded as well as which parts of my repertoire I have trouble with recalling.

```swift
 func checkForDeviation() {
    for move in moves {
        let fen = position.make(move: move).fen
        if await !database.findMoveInRepertoire(for: playerSide, fen: fen) {
            // did not find position in repertoire
        }
    }
}

func findMoveInRepertoire(for side: Repertoire.Side, fen: String) async -> Bool {
    do {
        return try await reader.read { db in
            if try Repertoire
            .filter(Repertoire.Columns.side == playerSide)
            .joining(required: Repertoire.positions.filter(RepertoirePosition.Columns.fen == fen))
            .fetchOne(db) == nil {
                return false
                } else {
                    return true
                }
            }
    } catch {
        return false
    }
}
```