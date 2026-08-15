import Foundation
import Observation

/// Offline-first Supabase sync. The app stays fully functional with no
/// account; once signed in, Sync pushes every local record (idempotent
/// upserts keyed on the device-generated UUID) and pulls teammates' rows.
///
/// Talks straight to Supabase's REST + auth endpoints — no SDK dependency.
/// Config + tokens persist to a JSON file next to the store. (Keychain is a
/// worthwhile hardening pass later.)
@Observable
final class CloudSync {
    var config = SyncConfig() { didSet { saveConfig() } }
    var isSyncing = false
    var lastSyncAt: Date?
    var lastError: String?

    var isConfigured: Bool {
        !config.urlString.isEmpty && !config.anonKey.isEmpty
    }
    var isSignedIn: Bool { config.accessToken != nil && config.userID != nil }

    /// The AQE Office Hub backend, pre-filled so there's nothing to paste.
    /// Publishable keys are designed to ship in clients — row-level security,
    /// not key secrecy, is what protects the data. (Editable in Settings if
    /// the project ever moves.)
    enum Backend {
        static let url = "https://pxlbrqeqkpjimxwvfypg.supabase.co"
        static let publishableKey = "sb_publishable_Dz0z-NYVGJJzP9Q9oSDzRQ_Jl6_1wY4"
    }

    struct SyncConfig: Codable {
        var urlString = Backend.url
        var anonKey = Backend.publishableKey
        var email = ""
        var accessToken: String?
        var refreshToken: String?
        var userID: String?
    }

    private let configURL: URL

    init() {
        configURL = AppStore.storeFileURL().deletingLastPathComponent()
            .appendingPathComponent("sync.json")
        if let data = try? Data(contentsOf: configURL),
           let saved = try? JSONDecoder().decode(SyncConfig.self, from: data) {
            config = saved
            // Configs saved before the backend shipped have blank fields.
            if config.urlString.isEmpty { config.urlString = Backend.url }
            if config.anonKey.isEmpty { config.anonKey = Backend.publishableKey }
        }
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configURL, options: .atomic)
        }
    }

    // MARK: - Auth

    func signUp(email: String, password: String) async {
        await authenticate(path: "auth/v1/signup", email: email, password: password)
    }

    func signIn(email: String, password: String) async {
        await authenticate(path: "auth/v1/token?grant_type=password",
                           email: email, password: password)
    }

    func signOut() {
        config.accessToken = nil
        config.refreshToken = nil
        config.userID = nil
    }

    private struct AuthResponse: Decodable {
        struct User: Decodable { let id: String }
        let access_token: String?
        let refresh_token: String?
        let user: User?
    }

    private func authenticate(path: String, email: String, password: String) async {
        lastError = nil
        guard let url = URL(string: config.urlString)?.appendingPathComponent(path) else {
            lastError = "Invalid project URL"
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["email": email, "password": password])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
            if let token = auth.access_token, let user = auth.user {
                config.email = email
                config.accessToken = token
                config.refreshToken = auth.refresh_token
                config.userID = user.id
            } else if (response as? HTTPURLResponse)?.statusCode == 200 {
                lastError = "Check your email to confirm the account, then sign in."
            } else {
                lastError = "Sign-in failed — check email/password."
            }
        } catch {
            lastError = "Network error: \(error.localizedDescription)"
        }
    }

    private func refreshSession() async -> Bool {
        guard let refreshToken = config.refreshToken,
              let url = URL(string: config.urlString)?
                .appendingPathComponent("auth/v1/token?grant_type=refresh_token") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["refresh_token": refreshToken])
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let auth = try? JSONDecoder().decode(AuthResponse.self, from: data),
              let token = auth.access_token else { return false }
        config.accessToken = token
        config.refreshToken = auth.refresh_token ?? refreshToken
        return true
    }

    // MARK: - REST plumbing

    private func restRequest(table: String, method: String,
                             query: String = "", body: Data? = nil) -> URLRequest? {
        guard var components = URLComponents(string: config.urlString) else { return nil }
        components.path = "/rest/v1/\(table)"
        components.percentEncodedQuery = query.isEmpty ? nil : query
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let token = config.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if method == "POST" {
            request.setValue("resolution=merge-duplicates,return=minimal",
                             forHTTPHeaderField: "Prefer")
        }
        request.httpBody = body
        return request
    }

    /// Runs a request; on 401 refreshes the session once and retries.
    private func run(_ request: URLRequest?) async throws -> Data {
        guard var request else { throw URLError(.badURL) }
        var (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 401, await refreshSession() {
            if let token = config.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            (data, response) = try await URLSession.shared.data(for: request)
        }
        if let status = (response as? HTTPURLResponse)?.statusCode, status >= 400 {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CloudSync", code: status,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(status): \(message.prefix(200))"])
        }
        return data
    }

    // MARK: - Sync

    /// Push everything local, then pull everything remote and merge new rows.
    @MainActor
    func syncNow(store: AppStore) async {
        guard isSignedIn, let userID = config.userID else { return }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }
        do {
            let encoder = JSONEncoder()

            // Rep profile (id = auth user id).
            let profile = store.profile
            let rep = RepRow(id: userID, created_by: userID, name: profile.name,
                             title: profile.title, company: profile.company,
                             phone: profile.phone, email: profile.email)
            _ = try await run(restRequest(table: "reps", method: "POST",
                                          body: encoder.encode([rep])))

            // Push local rows (idempotent upserts on the device UUIDs).
            let eventRows = store.events.map { EventRow(event: $0, userID: userID) }
            if !eventRows.isEmpty {
                _ = try await run(restRequest(table: "knock_events", method: "POST",
                                              body: encoder.encode(eventRows)))
            }
            let leadRows = store.leads.map { LeadRow(lead: $0, userID: userID) }
            if !leadRows.isEmpty {
                _ = try await run(restRequest(table: "leads", method: "POST",
                                              body: encoder.encode(leadRows)))
            }
            let intelRows = store.intel.map { IntelRow(record: $0, userID: userID) }
            if !intelRows.isEmpty {
                _ = try await run(restRequest(table: "property_intel", method: "POST",
                                              body: encoder.encode(intelRows)))
            }
            let stormRows = store.storms.map { StormRow(storm: $0, userID: userID) }
            if !stormRows.isEmpty {
                _ = try await run(restRequest(table: "storms", method: "POST",
                                              body: encoder.encode(stormRows)))
            }

            // Pull back OWN rows only (restores data onto a new phone).
            // Teammates' rows stay server-side for the leaderboard — merging
            // them here would pollute personal stats.
            let decoder = JSONDecoder()
            let ownFilter = "select=*&created_by=eq.\(userID)"
            let remoteEvents = try decoder.decode(
                [EventRow].self,
                from: await run(restRequest(table: "knock_events", method: "GET", query: ownFilter)))
            let knownEvents = Set(store.events.map { $0.id.uuidString.lowercased() })
            let newEvents = remoteEvents.filter { !knownEvents.contains($0.id.lowercased()) }
                .compactMap { $0.knockEvent }
            if !newEvents.isEmpty { store.events.append(contentsOf: newEvents) }

            let remoteLeads = try decoder.decode(
                [LeadRow].self,
                from: await run(restRequest(table: "leads", method: "GET", query: ownFilter)))
            let knownLeads = Set(store.leads.map { $0.id.uuidString.lowercased() })
            let newLeads = remoteLeads.filter { !knownLeads.contains($0.id.lowercased()) }
                .compactMap { $0.lead }
            if !newLeads.isEmpty { store.leads.append(contentsOf: newLeads) }

            lastSyncAt = Date()
        } catch {
            lastError = error.localizedDescription
        }
    }
}

// MARK: - Team leaderboard

extension CloudSync {
    struct TeamMemberStats: Identifiable {
        let id: String
        let name: String
        var knocks = 0
        var leads = 0
        var signed = 0
    }

    /// Today's knocks/leads/signed for every rep on the project.
    func fetchTeamToday() async -> [TeamMemberStats] {
        guard isSignedIn else { return [] }
        do {
            let decoder = JSONDecoder()
            struct RepName: Decodable { let id: String; let name: String? }
            let reps = try decoder.decode(
                [RepName].self,
                from: await run(restRequest(table: "reps", method: "GET", query: "select=id,name")))

            struct EventSlim: Decodable { let rep_id: String?; let outcome: String }
            let startOfDay = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
            let query = "select=rep_id,outcome&timestamp=gte.\(startOfDay)"
            let events = try decoder.decode(
                [EventSlim].self,
                from: await run(restRequest(table: "knock_events", method: "GET", query: query)))

            var statsByRep: [String: TeamMemberStats] = [:]
            for rep in reps {
                statsByRep[rep.id] = TeamMemberStats(id: rep.id, name: rep.name ?? "Rep")
            }
            for event in events {
                guard let repID = event.rep_id else { continue }
                var stats = statsByRep[repID] ?? TeamMemberStats(id: repID, name: "Rep")
                stats.knocks += 1
                if event.outcome == "lead" { stats.leads += 1 }
                if event.outcome == "contractSigned" { stats.signed += 1 }
                statsByRep[repID] = stats
            }
            return statsByRep.values.sorted { ($0.knocks, $0.leads) > ($1.knocks, $1.leads) }
        } catch {
            return []
        }
    }
}

// MARK: - Row payloads (column names match the Supabase schema)

private struct RepRow: Codable {
    let id, created_by, name, title, company, phone, email: String
}

private struct EventRow: Codable {
    let id: String
    let created_by: String?
    let rep_id: String?
    let outcome: String
    let timestamp: String
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let note: String?

    init(event: KnockEvent, userID: String) {
        id = event.id.uuidString.lowercased()
        created_by = userID
        rep_id = userID
        outcome = event.outcome.code
        timestamp = ISO8601DateFormatter.sync.string(from: event.timestamp)
        latitude = event.latitude
        longitude = event.longitude
        address = event.address
        note = event.note
    }

    var knockEvent: KnockEvent? {
        guard let uuid = UUID(uuidString: id),
              let outcome = KnockOutcome(code: outcome),
              let date = ISO8601DateFormatter.sync.date(from: timestamp)
                ?? ISO8601DateFormatter.plain.date(from: timestamp) else { return nil }
        var event = KnockEvent(outcome: outcome, latitude: latitude, longitude: longitude,
                               address: address, note: note)
        event.id = uuid
        event.timestamp = date
        return event
    }
}

private struct LeadRow: Codable {
    let id: String
    let created_by: String?
    let rep_id: String?
    let name, address, phone, note: String?
    let latitude, longitude: Double?
    let weather, storm_event, follow_up_date: String?

    init(lead: Lead, userID: String) {
        id = lead.id.uuidString.lowercased()
        created_by = userID
        rep_id = userID
        name = lead.name
        address = lead.address
        phone = lead.phone
        note = lead.note
        latitude = lead.latitude
        longitude = lead.longitude
        weather = lead.weatherAtCreation
        storm_event = lead.stormEvent
        follow_up_date = lead.followUpDate.map { ISO8601DateFormatter.sync.string(from: $0) }
    }

    var lead: Lead? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var lead = Lead()
        lead.id = uuid
        lead.name = name ?? ""
        lead.address = address ?? ""
        lead.phone = phone ?? ""
        lead.note = note ?? ""
        lead.latitude = latitude
        lead.longitude = longitude
        lead.weatherAtCreation = weather
        lead.stormEvent = storm_event
        lead.followUpDate = follow_up_date.flatMap {
            ISO8601DateFormatter.sync.date(from: $0) ?? ISO8601DateFormatter.plain.date(from: $0)
        }
        return lead
    }
}

private struct IntelRow: Codable {
    let id: String
    let created_by: String?
    let address: String
    let latitude, longitude: Double?
    let homeowner_name: String?
    let value_estimate: Double?
    let roof_age_years: Int?
    let last_hail_date: String?
    let permit_notes, insurance_notes: String?

    init(record: PropertyIntel, userID: String) {
        id = record.id.uuidString.lowercased()
        created_by = userID
        address = record.address
        latitude = record.latitude
        longitude = record.longitude
        homeowner_name = record.homeownerName
        value_estimate = record.valueEstimate
        roof_age_years = record.roofAgeYears
        last_hail_date = record.lastHailDate.map { DateOnly.string(from: $0) }
        permit_notes = record.permitNotes
        insurance_notes = record.insuranceNotes
    }
}

private struct StormRow: Codable {
    let id: String
    let created_by: String?
    let date: String
    let name: String?
    let hail_size_inches: Double?
    let wind_mph: Int?
    let latitude, longitude, radius_miles: Double?

    init(storm: StormEvent, userID: String) {
        id = storm.id.uuidString.lowercased()
        created_by = userID
        date = DateOnly.string(from: storm.date)
        name = storm.name
        hail_size_inches = storm.hailSizeInches
        wind_mph = storm.windMph
        latitude = storm.latitude
        longitude = storm.longitude
        radius_miles = storm.radiusMiles
    }
}

// MARK: - Helpers

private extension ISO8601DateFormatter {
    static let sync: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    /// Fallback for timestamps without fractional seconds.
    static let plain = ISO8601DateFormatter()
}

private enum DateOnly {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}
