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
    /// Mole marks advisory rows inside a category with `◎` — for example
    /// "Close these apps before database optimization: Safari" or
    /// "skipped (admin access required)". These are not tasks that ran.
    let isWarning: Bool

    init(description: String, categoryName: String, isCompleted: Bool, isWarning: Bool = false) {
        let raw = "\(description)::\(categoryName)::\(isWarning)"
        self.id = String(raw.hashValue)
        self.description = description
        self.categoryName = categoryName
        self.isCompleted = isCompleted
        self.isWarning = isWarning
    }
}

// MARK: - Outcome Counts

/// Footer counters printed by `mo optimize` since Mole 1.67, for example
/// `14 unchanged | 2 skipped | 1 unavailable`.
struct OptimizeOutcomeCounts: Equatable {
    var applied: Int = 0
    var unchanged: Int = 0
    var skipped: Int = 0
    var unavailable: Int = 0
    var attention: Int = 0
    var failed: Int = 0

    var isEmpty: Bool {
        applied == 0 && unchanged == 0 && skipped == 0
            && unavailable == 0 && attention == 0 && failed == 0
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
    var outcomes: OptimizeOutcomeCounts

    init(
        categories: [OptimizeCategory],
        totalOptimizations: Int,
        isDryRun: Bool,
        durationSeconds: Int,
        timestamp: Date,
        outcomes: OptimizeOutcomeCounts = OptimizeOutcomeCounts()
    ) {
        self.categories = categories
        self.totalOptimizations = totalOptimizations
        self.isDryRun = isDryRun
        self.durationSeconds = durationSeconds
        self.timestamp = timestamp
        self.outcomes = outcomes
    }
}

// MARK: - Parser Events

/// Events emitted by `OptimizeOutputParser` as it processes lines.
enum ParsedEvent: Equatable {
    case categoryStarted(name: String)
    case taskItem(description: String, completed: Bool)
    /// Advisory row inside a category (`◎`), not a task that ran.
    case warningItem(description: String)
    case diagnosisItem(description: String)
    case totalOptimizations(Int)
    case outcomes(OptimizeOutcomeCounts)
    case runComplete
    case unknown(String)
}
