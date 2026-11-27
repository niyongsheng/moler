import Foundation

/// Thread-safe line accumulator for streaming process output.
///
/// Keeps the raw text (for parsers), the completed non-empty lines (for live
/// logs and progress counters), and a timeout flag shared between the killer
/// and the exit handler. The view models use it from pipe callbacks, so every
/// mutation is locked.
final class LineBuffer: @unchecked Sendable {
    struct Snapshot {
        let output: String
        let lines: [String]
        let timedOut: Bool
    }

    struct Batch {
        /// Lines completed by this chunk, whitespace-trimmed and non-empty.
        let newLines: [String]
        let snapshot: Snapshot
    }

    private let lock = NSLock()
    private var output = ""
    private var partialLine = ""
    private var lines: [String] = []
    private var timedOut = false

    func reset() {
        lock.lock(); defer { lock.unlock() }
        output = ""
        partialLine = ""
        lines = []
        timedOut = false
    }

    /// Append a chunk and return the lines it completed plus a full snapshot.
    func append(_ chunk: String) -> Batch {
        lock.lock(); defer { lock.unlock() }

        output += chunk
        partialLine += chunk

        var newLines: [String] = []
        var parts = partialLine.components(separatedBy: "\n")
        if parts.count > 1 {
            partialLine = parts.removeLast()
            for line in parts {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                lines.append(trimmed)
                newLines.append(trimmed)
            }
        }

        return Batch(
            newLines: newLines,
            snapshot: Snapshot(output: output, lines: lines, timedOut: timedOut)
        )
    }

    /// Emit a trailing line that never got its newline (typically at EOF).
    func flushPartial() -> String? {
        lock.lock(); defer { lock.unlock() }
        let trimmed = partialLine.trimmingCharacters(in: .whitespaces)
        partialLine = ""
        guard !trimmed.isEmpty else { return nil }
        lines.append(trimmed)
        return trimmed
    }

    func markTimedOut() {
        lock.lock(); defer { lock.unlock() }
        timedOut = true
    }

    func snapshot() -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        return Snapshot(output: output, lines: lines, timedOut: timedOut)
    }
}
