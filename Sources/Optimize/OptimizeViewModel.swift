import Foundation
import SwiftUI

// MARK: - ViewModel

@MainActor
final class OptimizeViewModel: ObservableObject {

    @Published var state: OptimizeState = .idle
    @Published var errorMessage: String?

    // MARK: - Private

    private var process: Process?
    private var parser: OptimizeOutputParser?
    private let outputBuffer = LineBuffer()
    private var timer: Timer?
    private var startTime: Date?
    private var isDryRun = false

    // MARK: - Actions

    /// Start a dry-run preview (no admin needed)
    func startPreview() {
        startProcess(args: ["optimize", "--dry-run"], isDryRun: true)
    }

    /// Start a real optimization run (may request admin via system dialog)
    func startOptimize() {
        startProcess(args: ["optimize"], isDryRun: false)
    }

    /// Cancel the running operation
    func cancel() {
        process?.terminate()
        process = nil
        timer?.invalidate()
        timer = nil
        state = .idle
        errorMessage = nil
    }

    /// Reset to idle after done state
    func reset() {
        state = .idle
        errorMessage = nil
    }

    // MARK: - Private: Process Management

    private func startProcess(args: [String], isDryRun: Bool) {
        cancel() // ensure any existing process is terminated

        self.isDryRun = isDryRun
        let parser = OptimizeOutputParser()
        self.parser = parser

        // Elapsed timer
        startTime = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickElapsed()
        }

        // Initial progress state
        state = .running(progress: OptimizeProgress(
            categories: [],
            currentCategory: "",
            currentTask: "",
            completedCategories: 0,
            totalCategories: 0,
            isDryRun: isDryRun,
            elapsedSeconds: 0,
            diagnosisItems: []
        ))

        // Line splitting happens here; the parser turns lines into events.
        let buffer = outputBuffer
        buffer.reset()

        do {
            let stream = try MoleCLI.stream(
                args: args,
                onStdout: { [weak self] chunk in
                    let lines = buffer.append(chunk).newLines
                    guard !lines.isEmpty else { return }
                    let events = lines.map { parser.ingest(line: $0) }
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        events.forEach { self.handle(event: $0) }
                    }
                },
                onExit: { [weak self] result, process in
                    var events: [ParsedEvent] = []
                    if let line = buffer.flushPartial() {
                        events.append(parser.ingest(line: line))
                    }
                    let errorText = result.stderr

                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        // Ignore output from a superseded or cancelled run.
                        guard case .running = self.state, self.process === process else { return }
                        events.forEach { self.handle(event: $0) }
                        guard case .running = self.state else { return }

                        if result.exitCode == 0 {
                            self.finish()
                        } else {
                            var detail = ""
                            if result.terminationReason == .uncaughtSignal {
                                detail = "terminated (signal \(result.exitCode))"
                            } else {
                                detail = "exit code \(result.exitCode)"
                            }
                            if !errorText.isEmpty {
                                detail += ": " + errorText.prefix(200)
                            }
                            self.state = .error(detail)
                            self.errorMessage = detail
                        }
                    }
                }
            )
            process = stream.process
            try stream.start()
        } catch {
            timer?.invalidate()
            timer = nil
            state = .idle
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private: Event Handling

    private func handle(event: ParsedEvent) {
        guard case .running(var progress) = state else { return }

        switch event {
        case .categoryStarted(let name):
            progress.currentCategory = name
            progress.currentTask = ""
        case .taskItem(let description, _):
            progress.currentTask = description
        case .warningItem(let description):
            progress.currentTask = description
        case .diagnosisItem(let description):
            progress.diagnosisItems.append(description)
        case .totalOptimizations, .outcomes, .runComplete, .unknown:
            break
        }

        if let p = parser {
            progress.categories = p.categories
            progress.totalCategories = max(p.categories.count, p.totalOptimizations)
        }

        state = .running(progress: progress)
    }

    private func tickElapsed() {
        guard case .running(var progress) = state else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime ?? Date()))
        progress.elapsedSeconds = elapsed
        state = .running(progress: progress)
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        process = nil

        guard let p = parser else {
            state = .done(result: OptimizeResult(
                categories: [],
                totalOptimizations: 0,
                isDryRun: isDryRun,
                durationSeconds: Int(Date().timeIntervalSince(startTime ?? Date())),
                timestamp: Date()
            ))
            return
        }

        let result = OptimizeResult(
            categories: p.categories,
            totalOptimizations: p.totalOptimizations,
            isDryRun: isDryRun,
            durationSeconds: Int(Date().timeIntervalSince(startTime ?? Date())),
            timestamp: Date(),
            outcomes: p.outcomeCounts
        )

        // Record to store (only for real runs)
        if !isDryRun {
            Store.shared.recordOptimize(optimizationsApplied: p.totalOptimizations)
        }

        Analytics.track(.optimizeCompleted, [
            "optimizations": p.totalOptimizations,
            "dry_run": isDryRun,
        ])

        state = .done(result: result)
    }
}
