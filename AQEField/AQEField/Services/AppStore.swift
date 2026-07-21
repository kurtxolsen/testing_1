import Foundation
import CoreLocation
import Observation
import WidgetKit

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
    var profile = RepProfile() { didSet { save() } }

    private let fileURL: URL

    /// Shared with the widget extension. Falls back to the app's own
    /// container if the App Group entitlement isn't provisioned.
    static let appGroupID = "group.com.aqe.field"

    static func storeFileURL() -> URL {
        let base: URL
        if let group = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            base = group
        } else {
            base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        }
        let dir = base.appendingPathComponent("AQEField", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.json")
    }

    init() {
        fileURL = Self.storeFileURL()
        // One-time migration from the pre-App-Group location.
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let legacy = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
                .appendingPathComponent("AQEField/store.json")
            if FileManager.default.fileExists(atPath: legacy.path) {
                try? FileManager.default.copyItem(at: legacy, to: fileURL)
            }
        }
        load()
    }

    // MARK: - Logging

    @discardableResult
    func logKnock(_ outcome: KnockOutcome, latitude: Double?, longitude: Double?,
                  address: String? = nil, note: String? = nil) -> KnockEvent {
        let event = KnockEvent(outcome: outcome, latitude: latitude, longitude: longitude,
                               address: address, note: note)
        events.append(event)
        ShiftActivityManager.sync(stats: todayStats, goals: goals)
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

    // MARK: - Analytics

    /// "123 Main St" → "Main St": strip the leading house number so knocks
    /// group by street.
    static func streetName(from address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ")
        guard parts.count > 1, parts[0].allSatisfy({ $0.isNumber || $0 == "-" }) else {
            return trimmed
        }
        return parts.dropFirst().joined(separator: " ")
    }

    struct FunnelStats {
        var knocks = 0, conversations = 0, leads = 0, inspections = 0, signed = 0

        var knocksPerLead: Double? {
            leads > 0 ? Double(knocks) / Double(leads) : nil
        }
        var conversationRate: Double {
            knocks > 0 ? Double(conversations) / Double(knocks) : 0
        }
        var closeRate: Double {
            conversations > 0 ? Double(signed) / Double(conversations) : 0
        }
    }

    var allTimeFunnel: FunnelStats {
        var stats = FunnelStats()
        for event in events {
            stats.knocks += 1
            if event.outcome.isConversation { stats.conversations += 1 }
            switch event.outcome {
            case .lead: stats.leads += 1
            case .inspectionSet, .inspectionCompleted: stats.inspections += 1
            case .contractSigned: stats.signed += 1
            default: break
            }
        }
        return stats
    }

    struct HourPerformance: Identifiable {
        let hour: Int          // 0-23
        let knocks: Int
        let conversations: Int
        var id: Int { hour }
        var rate: Double { knocks > 0 ? Double(conversations) / Double(knocks) : 0 }
        var label: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "ha"
            let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            return formatter.string(from: date).lowercased()
        }
    }

    /// Conversation rate by hour of day, for hours with enough sample.
    var hourlyPerformance: [HourPerformance] {
        var knocksByHour: [Int: Int] = [:]
        var convosByHour: [Int: Int] = [:]
        for event in events {
            let hour = Calendar.current.component(.hour, from: event.timestamp)
            knocksByHour[hour, default: 0] += 1
            if event.outcome.isConversation { convosByHour[hour, default: 0] += 1 }
        }
        return knocksByHour.keys.sorted().map {
            HourPerformance(hour: $0, knocks: knocksByHour[$0] ?? 0,
                            conversations: convosByHour[$0] ?? 0)
        }
    }

    struct StreetPerformance: Identifiable {
        let street: String
        let knocks: Int
        let leads: Int          // leads + inspections + signed
        var id: String { street }
        var rate: Double { knocks > 0 ? Double(leads) / Double(knocks) : 0 }
    }

    /// Streets ranked by lead conversion (min 3 knocks to rank).
    var bestStreets: [StreetPerformance] {
        var knocksByStreet: [String: Int] = [:]
        var leadsByStreet: [String: Int] = [:]
        for event in events {
            guard let address = event.address, !address.isEmpty else { continue }
            let street = Self.streetName(from: address)
            knocksByStreet[street, default: 0] += 1
            switch event.outcome {
            case .lead, .inspectionSet, .inspectionCompleted, .contractSigned:
                leadsByStreet[street, default: 0] += 1
            default: break
            }
        }
        return knocksByStreet
            .filter { $0.value >= 3 }
            .map { StreetPerformance(street: $0.key, knocks: $0.value,
                                     leads: leadsByStreet[$0.key] ?? 0) }
            .sorted { ($0.rate, $0.knocks) > ($1.rate, $1.knocks) }
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
        var profile: RepProfile?
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
        profile = snapshot.profile ?? RepProfile()
    }

    private func save() {
        let snapshot = Snapshot(events: events, leads: leads, goals: goals,
                                intel: intel, storms: storms, trail: trail,
                                profile: profile)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
