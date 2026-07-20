import Foundation
import CoreLocation
import Observation

/// Offline-first store. Everything is kept in memory and persisted to JSON on
/// every change, so the app works with zero service and never shows a spinner.
/// (Supabase sync hooks in behind this same API in a later phase.)
@Observable
final class AppStore {
    var events: [KnockEvent] = [] { didSet { save() } }
    var leads: [Lead] = [] { didSet { save() } }
    var goals = DailyGoals() { didSet { save() } }
    var intel: [PropertyIntel] = [] { didSet { save() } }
    var storms: [StormEvent] = [] { didSet { save() } }
    var trail: [TrailPoint] = [] { didSet { save() } }

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

    // MARK: - Property intel

    /// Normalized key so "123 Main St" and "123 main st " match.
    static func addressKey(_ address: String) -> String {
        address.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func intel(forAddress address: String) -> PropertyIntel? {
        let key = Self.addressKey(address)
        return intel.first { Self.addressKey($0.address) == key }
    }

    func upsertIntel(_ record: PropertyIntel) {
        if let index = intel.firstIndex(where: { $0.id == record.id }) {
            intel[index] = record
        } else {
            intel.append(record)
        }
    }

    /// One card per known address: every knocked or intel'd house, rolled up.
    var houses: [HouseSummary] {
        var byKey: [String: (address: String, events: [KnockEvent])] = [:]
        for event in events {
            guard let address = event.address, !address.isEmpty else { continue }
            let key = Self.addressKey(address)
            byKey[key, default: (address, [])].events.append(event)
        }
        for record in intel {
            let key = Self.addressKey(record.address)
            if byKey[key] == nil { byKey[key] = (record.address, []) }
        }
        return byKey.map { key, value in
            let sorted = value.events.sorted { $0.timestamp < $1.timestamp }
            let last = sorted.last
            let record = intel.first { Self.addressKey($0.address) == key }
            return HouseSummary(id: key,
                                address: value.address,
                                coordinate: last?.coordinate ?? record?.coordinate,
                                lastOutcome: last?.outcome,
                                lastVisit: last?.timestamp,
                                knockCount: sorted.count,
                                intel: record)
        }
        .sorted { $0.address.localizedStandardCompare($1.address) == .orderedAscending }
    }

    // MARK: - Storms

    var latestStorm: StormEvent? {
        storms.max { $0.date < $1.date }
    }

    // MARK: - Breadcrumb trail

    var todayTrail: [TrailPoint] {
        trail.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    func recordTrailPoint(_ coordinate: CLLocationCoordinate2D) {
        // Only record a new crumb after ~15 m of movement to keep the file small.
        if let last = trail.last, Calendar.current.isDateInToday(last.timestamp) {
            let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let next = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            guard next.distance(from: lastLocation) > 15 else { return }
        }
        trail.append(TrailPoint(timestamp: Date(),
                                latitude: coordinate.latitude,
                                longitude: coordinate.longitude))
    }

    // MARK: - Persistence

    /// New fields are optional so Phase 1/2 store files keep decoding.
    private struct Snapshot: Codable {
        var events: [KnockEvent]
        var leads: [Lead]
        var goals: DailyGoals
        var intel: [PropertyIntel]?
        var storms: [StormEvent]?
        var trail: [TrailPoint]?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        events = snapshot.events
        leads = snapshot.leads
        goals = snapshot.goals
        intel = snapshot.intel ?? []
        storms = snapshot.storms ?? []
        trail = snapshot.trail ?? []
    }

    private func save() {
        let snapshot = Snapshot(events: events, leads: leads, goals: goals,
                                intel: intel, storms: storms, trail: trail)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
