import Foundation

// MARK: - Touches

enum TouchChannel: String, Codable, CaseIterable {
    case text = "Text"
    case call = "Call"

    var icon: String {
        switch self {
        case .text: return "message.fill"
        case .call: return "phone.fill"
        }
    }
}

/// One logged follow-up contact on a lead. Timestamped when logged.
struct LeadTouch: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var channel: TouchChannel = .text
    var note = ""
}

// MARK: - The Roofing Strong cadence

/// The follow-up ladder from the Field Bible's Follow-Up SOP. Day offsets are
/// measured from lead creation; after the ladder it repeats quarterly.
enum RSACadence {
    struct Step: Hashable {
        let number: Int
        let dayOffset: Int
        let channel: TouchChannel
        let goal: String
    }

    static let steps: [Step] = [
        Step(number: 1, dayOffset: 0,  channel: .text, goal: "Thank + recap + photo of their roof"),
        Step(number: 2, dayOffset: 1,  channel: .call, goal: "Answer questions, set/confirm inspection"),
        Step(number: 3, dayOffset: 3,  channel: .text, goal: "Value drop: neighbor approval, storm map"),
        Step(number: 4, dayOffset: 7,  channel: .call, goal: "Direct ask for the appointment"),
        Step(number: 5, dayOffset: 14, channel: .text, goal: "Deadline frame: filing window"),
        Step(number: 6, dayOffset: 30, channel: .call, goal: "Last direct attempt, ask to go quarterly"),
    ]

    /// After the ladder: stay top-of-mind until the roof is replaced.
    static let quarterlyDays = 90

    static func step(after completedTouches: Int) -> Step {
        if completedTouches < steps.count {
            return steps[completedTouches]
        }
        return Step(number: completedTouches + 1,
                    dayOffset: 0,
                    channel: completedTouches % 2 == 0 ? .text : .call,
                    goal: "Quarterly stay-in-touch")
    }
}

// MARK: - Cadence state per lead

extension Lead {
    var touchLog: [LeadTouch] { touches ?? [] }

    var nextCadenceStep: RSACadence.Step {
        RSACadence.step(after: touchLog.count)
    }

    /// When the next cadence touch is owed. Fixed-ladder steps come due at
    /// creation + offset, but never sooner than a day after the last touch;
    /// past the ladder it's quarterly from the last touch.
    var cadenceDueDate: Date {
        let completed = touchLog.count
        let lastTouchDate = touchLog.map(\.date).max()
        if completed < RSACadence.steps.count {
            let scheduled = Calendar.current.date(
                byAdding: .day,
                value: RSACadence.steps[completed].dayOffset,
                to: createdAt) ?? createdAt
            guard let lastTouchDate else { return scheduled }
            let dayAfterLast = Calendar.current.date(byAdding: .day, value: 1, to: lastTouchDate)
                ?? lastTouchDate
            return max(scheduled, dayAfterLast)
        }
        let base = lastTouchDate ?? createdAt
        return Calendar.current.date(byAdding: .day, value: RSACadence.quarterlyDays, to: base)
            ?? base
    }

    /// The date the follow-up queue sorts and alerts on: a manually scheduled
    /// follow-up (a promised appointment) or the cadence, whichever is sooner.
    var effectiveFollowUpDate: Date {
        if let followUpDate {
            return min(followUpDate, cadenceDueDate)
        }
        return cadenceDueDate
    }

    var isFollowUpOverdue: Bool {
        effectiveFollowUpDate < Date()
    }
}
