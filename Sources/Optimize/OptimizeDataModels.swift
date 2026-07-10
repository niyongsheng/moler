import Foundation

// MARK: - State Machine

/// The state machine for Optimize operations.
/// Simpler than Clean/Purge — mo optimize directly produces streaming output,
/// no separate scan or review phases needed.
enum OptimizeState: Equatable {
    /// Initial state with Preview / Optimize buttons
    case idle

    /// Optimization or preview is running with live progress
    case running(progress: OptimizeProgress)

    /// Completed successfully
    case done(result: OptimizeResult)

    /// Fatal error (mo not found, parse failure, etc.)
    case error(String)
}

// MARK: - Live Progress

/// Streamed progress state, updated as the parser processes each line.
struct OptimizeProgress: Equatable {
    /// Categories discovered so far (with their tasks)
    var categories: [OptimizeCategory]

    /// Name of the category currently being processed
    var currentCategory: String

    /// Description of the current task
    var currentTask: String

    /// How many categories have all their tasks emitted
    var completedCategories: Int

    /// Total categories expected (updated as we discover them)
    var totalCategories: Int

    /// Whether this is a dry-run preview
    var isDryRun: Bool

    /// Elapsed seconds since start
    var elapsedSeconds: Int

    /// Diagnosis items from PERFORMANCE DIAGNOSIS section
    var diagnosisItems: [String]
}

// MARK: - Data Models

/// A category/section in the optimize output (e.g. "DNS & Spotlight Check").
struct OptimizeCategory: Identifiable, Equatable {
    let id: String
    let name: String
    var tasks: [OptimizeTask]

    init(name: String, tasks: [OptimizeTask] = []) {
        self.id = name
        self.name = name
        self.tasks = tasks
    }
}

/// A single optimization task item within a category.
struct OptimizeTask: Identifiable, Equatable {
    /// Stable identifier derived from description + categoryName
    let id: String
    let description: String
    let categoryName: String
    let isCompleted: Bool

    init(description: String, categoryName: String, isCompleted: Bool) {
        let raw = "\(description)::\(categoryName)"
        self.id = String(raw.hashValue)
        self.description = description
        self.categoryName = categoryName
        self.isCompleted = isCompleted
    }
}

// MARK: - Result

/// Final result after a preview or real optimization run completes.
struct OptimizeResult: Equatable {
    let categories: [OptimizeCategory]
    let totalOptimizations: Int
    let isDryRun: Bool
    let durationSeconds: Int
    let timestamp: Date
}

// MARK: - Parser Events

/// Events emitted by `OptimizeOutputParser` as it processes lines.
enum ParsedEvent: Equatable {
    case categoryStarted(name: String)
    case taskItem(description: String, completed: Bool)
    case diagnosisItem(description: String)
    case totalOptimizations(Int)
    case runComplete
    case unknown(String)
}
