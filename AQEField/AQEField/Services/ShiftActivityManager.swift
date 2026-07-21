import Foundation
import ActivityKit

/// Starts, updates, and ends the shift Live Activity (Dynamic Island timer +
/// Lock Screen card). Called from the store after every logged knock.
enum ShiftActivityManager {
    private static var current: Activity<ShiftActivityAttributes>? {
        Activity<ShiftActivityAttributes>.activities.first
    }

    /// Start on the first knock of the day, update on every one after.
    static func sync(stats: DayStats, goals: DailyGoals) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = ShiftActivityAttributes.ContentState(
            knocks: stats.knocks,
            conversations: stats.conversations,
            leads: stats.leads,
            knockGoal: goals.knocks
        )
        Task {
            if let activity = current {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            } else {
                let attributes = ShiftActivityAttributes(startedAt: stats.firstKnock ?? Date())
                _ = try? Activity.request(attributes: attributes,
                                          content: ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    /// "End Shift" in the More tab.
    static func end() {
        Task {
            for activity in Activity<ShiftActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
