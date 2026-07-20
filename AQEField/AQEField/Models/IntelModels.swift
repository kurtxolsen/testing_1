import Foundation
import CoreLocation

// MARK: - Property intel

/// Per-house intelligence, keyed by street address. All fields are optional
/// and hand-entered today; each maps to a data-provider slot (Zillow, permit
/// records, hail history) that can auto-fill when API access lands.
struct PropertyIntel: Codable, Identifiable, Hashable {
    var id = UUID()
    var address: String
    var latitude: Double?
    var longitude: Double?
    var homeownerName = ""
    var valueEstimate: Double?      // Zillow-style estimate, manual for now
    var roofAgeYears: Int?
    var lastHailDate: Date?
    var permitNotes = ""            // permit history, free text
    var insuranceNotes = ""         // carrier, deductible, claim status

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Storm events

/// A storm the user (or later, NOAA data) logs. The most recent one
/// auto-tags new leads and draws the map overlay.
struct StormEvent: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var name = ""                   // "June 14 hail", "Derecho"
    var hailSizeInches: Double?
    var windMph: Int?
    var latitude: Double?           // overlay center (capture location)
    var longitude: Double?
    var radiusMiles: Double = 3

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var summary: String {
        var parts: [String] = [date.formatted(date: .abbreviated, time: .omitted)]
        if let hailSizeInches { parts.append("\(hailSizeInches.formatted())\" hail") }
        if let windMph { parts.append("\(windMph) mph wind") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Breadcrumb trail

/// One GPS fix on today's walking trail.
struct TrailPoint: Codable, Hashable {
    var timestamp: Date
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Rep profile (digital card)

/// The consultant's own contact card — feeds the QR code and vCard share.
struct RepProfile: Codable, Equatable {
    var name = "Kurt Olsen"
    var title = "Roofing Consultant"
    var company = "American Quality Exteriors"
    var phone = ""
    var email = ""
    var website = ""

    /// RFC 6350 vCard — what the QR encodes and the share sheet sends.
    var vCard: String {
        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        lines.append("FN:\(name)")
        lines.append("ORG:\(company)")
        lines.append("TITLE:\(title)")
        if !phone.isEmpty { lines.append("TEL;TYPE=CELL:\(phone)") }
        if !email.isEmpty { lines.append("EMAIL:\(email)") }
        if !website.isEmpty { lines.append("URL:\(website)") }
        lines.append("END:VCARD")
        return lines.joined(separator: "\n")
    }
}

// MARK: - House roll-up (derived, not persisted)

/// One card in Neighborhood Mode: an address plus everything known about it.
struct HouseSummary: Identifiable, Hashable {
    let id: String                  // normalized address key
    let address: String
    let coordinate: CLLocationCoordinate2D?
    let lastOutcome: KnockOutcome?
    let lastVisit: Date?
    let knockCount: Int
    let intel: PropertyIntel?

    static func == (lhs: HouseSummary, rhs: HouseSummary) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
