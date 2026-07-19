import Foundation
import Observation

/// Offline-first store. Everything is kept in memory and persisted to JSON on
/// every change, so the app works with zero service and never shows a spinner.
/// (Supabase sync hooks in behind this same API in a later phase.)
@Observable
final class AppStore {
    var events: [KnockEvent] = [] { didSet { save() } }
    var leads: [Lead] = [] { didSet { save() } }
    var goals = DailyGoals() { didSet { save() } }

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AQEField", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("store.json")
        load()
    }

    // MARK: - Logging

    @discardableResult
    func logKnock(_ outcome: KnockOutcome, latitude: Double?, longitude: Double?,
                  address: String? = nil, note: String? = nil) -> KnockEvent {
        let event = KnockEvent(outcome: outcome, latitude: latitude, longitude: longitude,
                               address: address, note: note)
        events.append(event)
        return event
    }

    func addLead(_ lead: Lead) {
        leads.append(lead)
    }

    func deleteEvent(_ event: KnockEvent) {
        events.removeAll { $0.id == event.id }
    }

    // MARK: - Today

    var todayEvents: [KnockEvent] {
        events.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    var todayStats: DayStats {
        var stats = DayStats()
        for event in todayEvents {
            stats.knocks += 1
            if event.outcome.isConversation { stats.conversations += 1 }
            switch event.outcome {
            case .lead: stats.leads += 1
            case .inspectionSet: stats.inspectionsSet += 1
            case .inspectionCompleted: stats.inspectionsCompleted += 1
            case .contractSigned: stats.contractsSigned += 1
            default: break
            }
            if stats.firstKnock == nil || event.timestamp < stats.firstKnock! {
                stats.firstKnock = event.timestamp
            }
            if stats.lastKnock == nil || event.timestamp > stats.lastKnock! {
                stats.lastKnock = event.timestamp
            }
        }
        return stats
    }

    /// Consecutive days (ending today or yesterday) with at least one knock.
    var streakDays: Int {
        let calendar = Calendar.current
        let knockDays = Set(events.map { calendar.startOfDay(for: $0.timestamp) })
        guard !knockDays.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: Date())
        if !knockDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  knockDays.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while knockDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Money estimator: today's pipeline value from signed jobs + weighted inspections.
    var todayEstimatedValue: Double {
        let stats = todayStats
        let signed = Double(stats.contractsSigned) * goals.valuePerSignedJob
        let pipeline = Double(stats.inspectionsSet + stats.inspectionsCompleted) * goals.valuePerSignedJob * 0.35
        return signed + pipeline
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var events: [KnockEvent]
        var leads: [Lead]
        var goals: DailyGoals
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        events = snapshot.events
        leads = snapshot.leads
        goals = snapshot.goals
    }

    private func save() {
        let snapshot = Snapshot(events: events, leads: leads, goals: goals)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
