import SwiftUI
import AppKit

/// @main entry point for the Moler app.
/// Forks between GUI mode (default) and CLI modes (future: MCP server).
@main
enum MolerMain {
    static func main() {
        let args = CommandLine.arguments

        // Future: fork --mcp mode for AI agent integration
        if args.contains("--mcp") || args.contains("mcp") {
            // MCP server mode (to be implemented)
            fputs("MCP server mode not yet implemented\n", stderr)
            exit(0)
        }

        // Default: GUI mode
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
