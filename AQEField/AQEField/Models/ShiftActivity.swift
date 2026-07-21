import Foundation
import ActivityKit

/// Live Activity payload for a knocking shift — shown on the Lock Screen and
/// in the Dynamic Island. Compiled into both the app and the widget extension.
struct ShiftActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var knocks: Int
        var conversations: Int
        var leads: Int
        var knockGoal: Int
    }

    /// When the shift (first knock of the day) started — drives the timer.
    var startedAt: Date
}
