---
color: C07309
date: 2024-10-31T16:52:00Z
description: A blog post series detailing my journey of developing a chess app for iOS and macOS
project: true
title: Writing a chess app (8/9): Using a chess engine locally
category: swift
slug: writing-a-chess-app-8-9-using-a-chess-engine-locally
---

## Available engines

When developing a chess application, you have several options for integrating a chess engine. The two most popular choices are: [Stockfish](https://stockfishchess.org) and [Leela Chess Zero](https://lczero.org). Both engines are open source, extremly powerful and support the UCI engine protocol. For my project I chose to use Stockfish as it used by my favorite chess platform lichess and besides that considered as the best chess engine currently existing in terms of playing strength.

## UCI Engine Protocol

[UCI protocol documentation](https://backscattering.de/chess/uci/2006-04.txt)

The Universal Chess Interface (UCI) is a protocol that allows communication between chess engines and GUIs. It standardizes the way commands are sent and received, making it easier for us to integrate different engines into our applications.

### UCI Command Structure

The UCI protocol consists of a series of text-based commands that the GUI sends to the engine, and responses that the engine sends back. Here’s a breakdown of some of the most common commands in the UCI protocol:

####  1. Initialization Commands

- **`uci`**: This command is sent by the GUI to initiate communication with the engine. The engine responds with its identity and capabilities.
    
    **Example**:
    
    ```
    > uci < id name Stockfish 15 < uciok
    ```
    
- **`isready`**: This command checks if the engine is ready to receive new commands. The engine responds with `readyok` when it is ready.
    
####  2. Position Setup Commands

- **`position`**: This command sets the position on the board. It can take two forms:
    
    - **`position startpos`**: Initializes the board to the standard starting position.
    - **`position fen <FEN>`**: Sets the board to a specific configuration defined by the FEN string.
    
    **Example**:
    
    ```
    > position startpos
    ```
    
- **`setposition`**: Similar to `position`, but used to set a position without the need to specify moves.
    
####  3. Move Calculation Commands

- **`go`**: This command instructs the engine to start calculating the best move. It can be accompanied by parameters such as:
    
    - **`depth <n>`**: Limits the search to a specific depth.
    - **`time <milliseconds>`**: Limits the time the engine can spend calculating.
    - **`movetime <milliseconds>`**: Specifies the exact time to think for the current move.
    
    **Example**:
    
    ```
    > go movetime 2000
    ```
    
- **`stop`**: This command tells the engine to stop its calculations immediately. The engine will return the best move it has found so far.
    
####  4. Engine Options Commands

- **`setoption name <name> value <value>`**: This command allows the GUI to set various options for the engine, such as adjusting its playing style or tuning specific parameters.
    
    **Example**:
    
    ```
    > setoption name Hash value 2048
    ```
    

####  5. Termination Commands

- **`quit`**: This command is used to terminate the engine process. The engine will respond with a message indicating it is shutting down.

### Example Interaction Flow

To illustrate how UCI works in practice, let’s walk through a typical interaction between a GUI and a chess engine:

1. **Initialization**:
    
```
> uci < id name Stockfish 15 < uciok
```
    
2. **Setting Up the Position**:
    
```
> position startpos
```
    
3. **Instructing the Engine to Calculate a Move**:
    
```
> go movetime 3000
```
    
4. **Receiving the Best Move**:
    
```
< bestmove e2e4 < info depth 20 seldepth 30 score cp 25
```
    
5. **Stopping the Engine (if needed)**:
    
```
> stop < bestmove e2e4
```
    
6. **Terminating the Engine**:
    
```
> quit
```

## Redirect STDOUT and STDIN

Now that we have chosen a chess engine and have an understanding how to communicate with it we should look at how to incorporate that into our iOS and macOS application. Since stockfish is written in C++ ([source code](https://github.com/official-stockfish/Stockfish)) the best option to make the engine available to our Swift application is by bridging it in a Objective-C++ framework. I created a new Swift package with one target containing the stockfish source code as well as some wrapper implementation. When using the stockfish engine the source code expects you to send commands on stdin and receive the response on stdout. To make this work with our iOS application we create a new pipe for reading and one for writing and redirect stdin and stdout to those pipes. Fortunately a function to do exactly this already exists in the C standard library ready for us to use it.

```objc
- (void)start {
    // set up read pipe
    _readPipe = [NSPipe pipe];
    _pipeReadHandle = [_readPipe fileHandleForReading];

    dup2([[_readPipe fileHandleForWriting] fileDescriptor], fileno(stdout));

    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(readStdout:)
     name:NSFileHandleReadCompletionNotification
     object:_pipeReadHandle
    ];

    [_pipeReadHandle readInBackgroundAndNotify];

    // set up write pipe
    _writePipe = [NSPipe pipe];
    _pipeWriteHandle = [_writePipe fileHandleForWriting];
    dup2([[_writePipe fileHandleForReading] fileDescriptor], fileno(stdin));

    _queue = dispatch_queue_create("ck-message-queue", DISPATCH_QUEUE_CONCURRENT);

    dispatch_async(_queue, ^{
        _engine->initialize();
    });
}

- (void)stop {
    [_pipeReadHandle closeFile];
    [_pipeWriteHandle closeFile];

    _readPipe = NULL;
    _pipeReadHandle = NULL;

    _writePipe = NULL;
    _pipeWriteHandle = NULL;

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)sendCommand: (NSString*) command {
    dispatch_sync(_queue, ^{
        const char *cmd = [[command stringByAppendingString:@"\n"] UTF8String];
        write([_pipeWriteHandle fileDescriptor], cmd, strlen(cmd));
    });
}

# pragma mark Private

- (void)readStdout: (NSNotification*) notification {
    [_pipeReadHandle readInBackgroundAndNotify];

    NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    NSArray<NSString *> *output = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"\n"];

    [output enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self responseHandler](obj);
    }];
}
```

With this wrapper in place we can start to implement the UCI protocol and interface with the chosen engine implementation.

## Using a chess engine

We need 4 core components:
1. A model to represent engine commands
2. A parser to parse engine responses
3. An interface to send commands to the engine and to receive responses from it (done)
4. An engine representation to bring all of this together

For reference I included parts of this implementation for you to get a better understanding how my integration works. Please note that while I changed the implementation quite a bit in my current project this code was initially taken from this open source package: [chesskit-engine](https://github.com/chesskit-app/chesskit-engine).

```swift
public enum EngineCommand: Equatable {
	case uci
	case isready
	case position(PositionString, moves: [String]? = nil)
	...
}

class EngineResponseParser {
    static func parse(response: String) -> EngineResponse? {
        let tokens = response.split { $0.isWhitespace || $0.isNewline } .map(String.init)
        var iterator = tokens.makeIterator()

        guard let command = iterator.next() else {
            return nil
        }

        switch command {
        case "id":          return parseID(&iterator)
        case "uciok":       return .uciok
        case "readyok":     return .readyok
        case "bestmove":    return parseBestMove(&iterator)
        case "info":        return parseInfo(&iterator)
        default:            return nil
        }
    }

    // ...
}

public class Engine {
    private let messenger: EngineMessenger
    public private(set) var isRunning = false
    private var startupLoop: EngineSetupLoop

    private let queue = DispatchQueue(
        label: "ck-engine-queue",
        qos: .userInteractive
    )

    deinit {
        stop()
    }

    public func start(
        coreCount: Int? = nil,
        multipv: Int = 1,
        completion: @escaping () -> Void = {}
    ) {
        startupLoop.startupDidComplete = {
            self.isRunning = true
            self.performInitialSetup(
                coreCount: coreCount ?? ProcessInfo.processInfo.processorCount,
                multipv: multipv
            )
            DispatchQueue.main.async {
                completion()
            }
        }

        messenger.responseHandler = { [weak self] response in
            guard let self else { return }

            guard let parsed = EngineResponse(rawValue: response) else {
                if !response.isEmpty {
                    self.log(response)
                }
                return
            }

            if !self.isRunning, let next = startupLoop.nextCommand(given: parsed) {
                self.send(command: next)
            }
            
            DispatchQueue.main.async {
                self.receiveResponse(parsed)
            }
        }

        messenger.start()
        send(command: .uci)
    }

    public func stop() {
        guard isRunning else { return }

        send(command: .stop)
        send(command: .quit)
        messenger.stop()

        isRunning = false
        initialSetupComplete = false
    }
	
	public func send(command: EngineCommand) {
        guard isRunning || [.uci, .isready].contains(command) else {
            return
        }

        queue.sync {
            messenger.sendCommand(command.rawValue)
        }
    }

    public var receiveResponse: (_ response: EngineResponse) -> Void = {
        _ in
    }

    private var initialSetupComplete = false

    private func performInitialSetup(coreCount: Int, multipv: Int) {
        guard !initialSetupComplete else { return }

        let fileOptions = [
                "EvalFile": "nn-1111cefa1111",
                "EvalFileSmall": "nn-37f18f62d772"
            ].compactMapValues {
                Bundle.main.url(forResource: $0, withExtension: "nnue")?.path()
            }
        fileOptions.map(EngineCommand.setoption).forEach(send)

        send(command: .setoption(
            id: "Threads",
            value: "\(max(coreCount - 1, 1))"
        ))
        send(command: .setoption(id: "MultiPV", value: "\(multipv)"))

        initialSetupComplete = true
    }
}
```

If you are wondering what those EvalFiles are about here is a quick rundown for you:
Both Stockfish and Leela Chess Zero require neural network files to be provided to the engine for computation. They can be downloaded on their respective website and will be added to the engine via the setoption command. You are free to chose your options on how to provide the engine with these files. You might want to consider downloading them at app launch or maybe you just bundle them with the application in the first place.

## Game Review

One thing popular chess platforms like lichess offer to their users is a detailed game review analysis. It boils down to categorizing moves as blunders, mistakes and inaccuracies with the help of a chess engine. This information can provide great value when analyzing your games to quickly spot interesting parts of the game and to identify fields of improvements for your chess training. 

Another useful metric is the average centipawn loss.
Centipawn loss refers to the difference in evaluation scores given by a chess engine before and after a move. This score is expressed in centipawns, which is one-hundredth of a pawn. A lower centipawn loss indicates better move quality, while a higher centipawn loss suggests a poorer decision. The average centipawn loss further describes the average of all centipawn losses throughout the game. The calculation of this metric is done with the following algorithm:

1. **Analyze Each Move**: After the game is completed, use a chess engine to analyze each move. For each move, record the evaluation score before and after the move.
    
2. **Calculate Centipawn Loss for Each Move**: `Centipawn Loss = Evaluation Before Move - Evaluation After Move`. This formula gives you the centipawn loss for each move. If the evaluation after the move is lower than before, the result will be a positive centipawn loss, indicating a drop in position quality.
    
3. **Sum the Centipawn Losses**: Add up all the individual centipawn losses for the moves made during the game.
    
4. **Count the Number of Moves**: Determine the total number of moves made in the game.
    
5. **Calculate Average Centipawn Loss**: `ACPL = Total Centipawn Loss / Number of Moves` This formula provides the average centipawn loss over the course of the game.

As of this writing I did not have any time to look into that more closely but it is one of the features I would like to tackle next. 

## Closing words

Thats all I have for this topic. In the last part I'd like to draw a conclusion as well as say a few words about unit tests.  