import Foundation
import blog_swift

struct WebsiteRunner {
    let folder: URL
    let port: Int
    
    func run() throws {
        let serverQueue = DispatchQueue(label: "Publish.WebServer")
        let serverProcess = Process()

        print("""
        🌍 Starting web server at http://localhost:\(port)

        Press ENTER to stop the server and exit
        """)

        serverQueue.async {
            do {
                _ = try shellOut(
                    to: "python3 -m http.server \(self.port)",
                    at: folder.path,
                    process: serverProcess
                )
            } catch let error as ShellOutError {
                self.outputServerErrorMessage(error.message)
            } catch {
                self.outputServerErrorMessage(error.localizedDescription)
            }

            serverProcess.terminate()
            exit(1)
        }

        _ = readLine()
        serverProcess.terminate()
    }
}

private extension WebsiteRunner {
    func outputServerErrorMessage(_ message: String) {
        var message = message

        if message.hasPrefix("Traceback"),
           message.contains("Address already in use") {
            message = """
            A localhost server is already running on port number \(port).
            - Perhaps another 'publish run' session is running?
            - Publish uses Python's simple HTTP server, so to find any
              running processes, you can use either Activity Monitor
              or the 'ps' command and search for 'python'. You can then
              terminate any previous process in order to start a new one.
            """
        }

        fputs("\n❌ Failed to start local web server:\n\(message)\n", stderr)
    }
}
