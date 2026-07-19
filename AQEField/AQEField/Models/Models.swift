import Foundation
import SwiftUI
import CoreLocation

// MARK: - Knock outcomes

/// One-tap outcomes on the Knock screen. Order here is display order.
enum KnockOutcome: String, Codable, CaseIterable, Identifiable {
    case noAnswer = "No Answer"
    case conversation = "Conversation"
    case notInterested = "Not Interested"
    case renter = "Renter"
    case followUp = "Follow Up"
    case lead = "Lead"
    case inspectionSet = "Inspection Set"
    case inspectionCompleted = "Inspection Completed"
    case contractSigned = "Contract Signed"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .noAnswer: return "door.left.hand.closed"
        case .conversation: return "bubble.left.and.bubble.right.fill"
        case .notInterested: return "hand.raised.fill"
        case .renter: return "key.fill"
        case .followUp: return "clock.arrow.circlepath"
        case .lead: return "star.fill"
        case .inspectionSet: return "calendar.badge.plus"
        case .inspectionCompleted: return "checkmark.seal.fill"
        case .contractSigned: return "signature"
        }
    }

    var color: Color {
        switch self {
        case .noAnswer: return AQETheme.statusBlue
        case .conversation: return AQETheme.navyLight
        case .notInterested: return AQETheme.statusRed
        case .renter: return AQETheme.statusGray
        case .followUp: return AQETheme.statusOrange
        case .lead: return AQETheme.statusGreen
        case .inspectionSet, .inspectionCompleted: return AQETheme.statusPurple
        case .contractSigned: return AQETheme.coral
        }
    }

    /// Did the homeowner actually talk to us?
    var isConversation: Bool {
        switch self {
        case .conversation, .notInterested, .followUp, .lead,
             .inspectionSet, .inspectionCompleted, .contractSigned:
            return true
        case .noAnswer, .renter:
            return false
        }
    }
}

// MARK: - Knock event

/// A single logged door. Timestamp + GPS captured automatically.
struct KnockEvent: Codable, Identifiable, Hashable {
    var id = UUID()
    var outcome: KnockOutcome
    var timestamp = Date()
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var note: String?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Lead

struct Lead: Codable, Identifiable, Hashable {
    var id = UUID()
    var name = ""
    var address = ""
    var phone = ""
    var note = ""
    var createdAt = Date()
    var latitude: Double?
    var longitude: Double?
    var weatherAtCreation: String?
    var followUpDate: Date?
}

// MARK: - Goals

struct DailyGoals: Codable, Equatable {
    var knocks = 100
    var conversations = 25
    var inspections = 5
    var signedJobs = 2

    /// Rough commission value per signed job, for the money estimator.
    var valuePerSignedJob = 1200.0
}

// MARK: - Day stats (computed from events)

struct DayStats {
    var knocks = 0
    var conversations = 0
    var leads = 0
    var inspectionsSet = 0
    var inspectionsCompleted = 0
    var contractsSigned = 0
    var firstKnock: Date?
    var lastKnock: Date?

    var hoursWorked: Double {
        guard let firstKnock, let lastKnock, lastKnock > firstKnock else { return 0 }
        return lastKnock.timeIntervalSince(firstKnock) / 3600
    }

    /// Signed ÷ conversations, the number that matters at the kitchen table.
    var closeRate: Double {
        guard conversations > 0 else { return 0 }
        return Double(contractsSigned) / Double(conversations)
    }
}
