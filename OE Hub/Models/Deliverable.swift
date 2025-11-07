import Foundation
import SwiftData

@Model
final class Deliverable {
    /// Human-readable description of the task.
    var taskDescription: String

    /// When the task is due.
    var dueDate: Date

    /// Completion state & date.
    var isCompleted: Bool = false
    var completionDate: Date? = nil

    /// Owning job (inverse set on `Job.deliverables`).
    var job: Job?

    /// Stored color token (string). Kept for schema stability.
    var colorCode: String? = "blue"

    /// Stored reminder offsets as raw string codes (e.g., "2weeks", "1week").
    var reminderOffsets: [String]

    init(taskDescription: String, dueDate: Date) {
        self.taskDescription = taskDescription
        self.dueDate = dueDate
        self.reminderOffsets = []
    }
}

// MARK: - Type-safe wrappers (no schema change)
extension Deliverable {
    /// Mirrors your palette in a type-safe way, while still storing a String.
    enum ColorCode: String, CaseIterable {
        case gray, red, blue, green, purple, orange, yellow, teal, brown, black, white
    }

    /// Supported reminder offsets (kept in sync with your UI).
    enum ReminderOffset: String, CaseIterable {
        case twoWeeks = "2weeks"
        case oneWeek  = "1week"
        case twoDays  = "2days"
        case dayOf    = "dayof"
    }

    /// Non-breaking, type-safe access to `colorCode`.
    var color: ColorCode {
        get { ColorCode(rawValue: colorCode ?? "gray") ?? .gray }
        set { colorCode = newValue.rawValue }
    }

    /// Work in enums in your UI; persist strings under the hood.
    var reminderSet: Set<ReminderOffset> {
        get { Set(reminderOffsets.compactMap(ReminderOffset.init(rawValue:))) }
        set { reminderOffsets = newValue.map(\.rawValue).sorted() }
    }

    /// Useful transient state for badges & sorting.
    var isOverdue: Bool {
        !isCompleted && Date() > dueDate
    }
}
