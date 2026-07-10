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
    private var timer: Timer?
    private var startTime: Date?
    private var isDryRun = false
    private var accumulatedCategories: [OptimizeCategory] = []
    private var completedCategories = 0
    private var currentCategoryName = ""
    private var currentTaskDescription = ""

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
        // Validate mo executable
        guard let mo = MoleCLI.findExecutable() else {
            errorMessage = L10n.errorMoNotFound
            return
        }

        cancel() // ensure any existing process is terminated

        // Setup
        self.isDryRun = isDryRun
        self.accumulatedCategories = []
        self.completedCategories = 0
        self.currentCategoryName = ""
        self.currentTaskDescription = ""

        let parser = OptimizeOutputParser()
        parser.reset()
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

        // Create and configure Process
        let task = Process()
        task.executableURL = URL(fileURLWithPath: mo)
        task.arguments = args

        // Set NO_COLOR to strip ANSI colour codes
        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        task.environment = env

        let outPipe = Pipe()
        task.standardOutput = outPipe
        let errPipe = Pipe()
        task.standardError = errPipe

        var partialLine = ""
        var errData = Data()

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let d = handle.availableData
            if !d.isEmpty { errData.append(d) }
        }

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }

            let raw = String(data: data, encoding: .utf8) ?? ""
            partialLine += raw

            // Split on newlines, keep partial line
            var lines = partialLine.components(separatedBy: "\n")
            if lines.count > 1 {
                partialLine = lines.removeLast()
                for line in lines {
                    let event = parser.ingest(line: line)
                    Task { @MainActor in
                        self.handle(event: event)
                    }
                }
            }
        }

        do {
            try task.run()
            self.process = task

            // Wait for exit on background thread
            Task.detached(priority: .userInitiated) { [weak self] in
                task.waitUntilExit()

                // Stop handlers first to prevent races
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil

                // Drain remaining pipe data after process exit
                let remainingOut = try? outPipe.fileHandleForReading.readToEnd()
                let remainingErr = try? errPipe.fileHandleForReading.readToEnd()

                // Append remaining data
                if let rem = remainingOut, let str = String(data: rem, encoding: .utf8), !str.isEmpty {
                    partialLine += str
                }
                if let rem = remainingErr, !rem.isEmpty { errData.append(rem) }

                // Flush any remaining partial line
                if !partialLine.isEmpty {
                    let event = parser.ingest(line: partialLine)
                    await MainActor.run { [weak self] in
                        // Only flush if we're still the current process
                        guard self?.process === task else { return }
                        self?.handle(event: event)
                    }
                }

                let status = task.terminationStatus
                let reason = task.terminationReason
                let errText = String(data: errData, encoding: .utf8) ?? ""

                await MainActor.run { [weak self] in
                    guard let self else { return }

                    // If we already transitioned (e.g. cancelled), don't override
                    guard case .running = self.state else { return }
                    // Also ensure we're still the current process (not superseded)
                    guard self.process === task else { return }

                    if status == 0 {
                        // Success - transition to done
                        self.finish()
                    } else {
                        // Build error detail string
                        var detail = ""
                        if reason == .uncaughtSignal {
                            detail = "terminated (signal \(status))"
                        } else {
                            detail = "exit code \(status)"
                        }
                        if !errText.isEmpty {
                            detail += ": " + errText.prefix(200)
                        }
                        self.state = .error(detail)
                        self.errorMessage = detail
                    }
                }
            }
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
            currentCategoryName = name
            currentTaskDescription = ""
            // A new category means the previous one is complete
            if !accumulatedCategories.isEmpty && !accumulatedCategories.last!.tasks.isEmpty {
                completedCategories += 1
            }
            progress.currentCategory = name
            progress.categories = accumulatedCategories

        case .taskItem(let description, let completed):
            currentTaskDescription = description
            progress.currentTask = description
            progress.categories = accumulatedCategories

            // Update total categories count from parser
            if let p = parser {
                progress.totalCategories = p.categories.count
            }

        case .diagnosisItem(let description):
            progress.diagnosisItems.append(description)
            progress.categories = accumulatedCategories

        case .totalOptimizations(let count):
            progress.totalCategories = count

        case .runComplete:
            // Finalize - the finish() will be called from the exit handler
            break

        case .unknown:
            break
        }

        // Sync accumulated categories from parser
        if let p = parser {
            accumulatedCategories = p.categories
            progress.categories = accumulatedCategories
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
                categories: accumulatedCategories,
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
            timestamp: Date()
        )

        // Record to store (only for real runs)
        if !isDryRun {
            Store.shared.recordOptimize(optimizationsApplied: p.totalOptimizations)
        }

        state = .done(result: result)
    }
}
