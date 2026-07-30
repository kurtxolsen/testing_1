import SwiftUI

/// Wrist knock logging: the outcomes you actually tap at a door, sized for a
/// gloved thumb. One tap logs, buzzes, and syncs to the phone.
struct WatchKnockView: View {
    @Environment(PhoneLink.self) private var link
    /// Counter, not the outcome itself — repeat taps of the same button must
    /// still buzz.
    @State private var logCount = 0

    /// Short list on purpose — the full nine live on the phone.
    private let outcomes: [KnockOutcome] = [
        .noAnswer, .conversation, .followUp, .lead, .inspectionSet, .notInterested,
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                header
                ForEach(outcomes) { outcome in
                    Button {
                        link.log(outcome)
                        logCount += 1
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: outcome.icon)
                            Text(outcome.rawValue)
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(outcome.color, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
        .sensoryFeedback(.success, trigger: logCount)
        .navigationTitle("Knock")
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("\(link.knocks)")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(AQETheme.coral)
            Text("today")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            if link.pendingCount > 0 {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Second page: today's numbers and the knock-goal ring.
struct WatchStatsView: View {
    @Environment(PhoneLink.self) private var link

    private var progress: Double {
        link.knockGoal > 0 ? min(Double(link.knocks) / Double(link.knockGoal), 1) : 0
    }

    var body: some View {
        VStack(spacing: 10) {
            Gauge(value: progress) {
                EmptyView()
            } currentValueLabel: {
                Text("\(link.knocks)")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(AQETheme.coral)

            Text("of \(link.knockGoal) knocks")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                statColumn("\(link.conversations)", label: "convos")
                statColumn("\(link.leads)", label: "leads")
            }
        }
        .navigationTitle("Today")
    }

    private func statColumn(_ value: String, label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .heavy))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
