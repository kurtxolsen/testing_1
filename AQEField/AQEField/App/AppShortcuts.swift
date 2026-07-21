import Foundation
import AppIntents

/// Knock outcomes exposed to Siri / Shortcuts / the Action Button.
enum OutcomeChoice: String, AppEnum {
    case noAnswer, conversation, notInterested, renter, followUp, lead,
         inspectionSet, inspectionCompleted, contractSigned

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Knock Outcome")
    static let caseDisplayRepresentations: [OutcomeChoice: DisplayRepresentation] = [
        .noAnswer: "No Answer", .conversation: "Conversation",
        .notInterested: "Not Interested", .renter: "Renter",
        .followUp: "Follow Up", .lead: "Lead",
        .inspectionSet: "Inspection Set", .inspectionCompleted: "Inspection Completed",
        .contractSigned: "Contract Signed",
    ]

    var outcome: KnockOutcome {
        switch self {
        case .noAnswer: return .noAnswer
        case .conversation: return .conversation
        case .notInterested: return .notInterested
        case .renter: return .renter
        case .followUp: return .followUp
        case .lead: return .lead
        case .inspectionSet: return .inspectionSet
        case .inspectionCompleted: return .inspectionCompleted
        case .contractSigned: return .contractSigned
        }
    }
}

/// "Hey Siri, log a knock" — logs without opening the app, so it works from
/// the Action Button mid-walk. GPS comes along when the intent runs in-app.
struct LogKnockIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Knock"
    static let description = IntentDescription("Log a door outcome to AQE Field.")

    @Parameter(title: "Outcome", default: .noAnswer)
    var choice: OutcomeChoice

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // The intent runs in the app's process: use the shared store directly.
        let store = AppStore()
        store.logKnock(choice.outcome, latitude: nil, longitude: nil)
        ShiftActivityManager.sync(stats: store.todayStats, goals: store.goals)
        let total = store.todayStats.knocks
        return .result(dialog: "Logged. \(total) knocks today.")
    }
}

/// Today's numbers by voice, without pulling the phone out mid-street.
struct TodayStatsIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Stats"
    static let description = IntentDescription("Hear today's knocks, conversations, and leads.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = AppStore()
        let stats = store.todayStats
        return .result(dialog: """
        \(stats.knocks) knocks, \(stats.conversations) conversations, \
        \(stats.leads) leads, \(stats.contractsSigned) signed.
        """)
    }
}

struct AQEShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogKnockIntent(),
            phrases: [
                "Log a knock in \(.applicationName)",
                "Log a door in \(.applicationName)",
            ],
            shortTitle: "Log Knock",
            systemImageName: "hand.raised.fingers.spread.fill"
        )
        AppShortcut(
            intent: TodayStatsIntent(),
            phrases: [
                "How am I doing in \(.applicationName)",
                "Today's stats in \(.applicationName)",
            ],
            shortTitle: "Today's Stats",
            systemImageName: "chart.bar.fill"
        )
    }
}
