import SwiftUI

/// Large live stat cards: hours, knocks, conversations, leads, inspections,
/// close %, streak, and the money estimator.
struct StatCardsView: View {
    let stats: DayStats
    let streak: Int
    let estimatedValue: Double

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        VStack(spacing: 12) {
            // Hero row: money + streak.
            HStack(spacing: 12) {
                heroCard(title: "Est. Pipeline",
                         value: estimatedValue.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                         icon: "dollarsign.circle.fill",
                         background: AQETheme.navy)
                heroCard(title: "Streak",
                         value: "\(streak) day\(streak == 1 ? "" : "s")",
                         icon: "flame.fill",
                         background: AQETheme.coral)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                statCard("Hours", value: String(format: "%.1f", stats.hoursWorked), icon: "clock.fill")
                statCard("Knocks", value: "\(stats.knocks)", icon: "hand.raised.fingers.spread.fill")
                statCard("Conversations", value: "\(stats.conversations)", icon: "bubble.left.and.bubble.right.fill")
                statCard("Leads", value: "\(stats.leads)", icon: "star.fill")
                statCard("Inspections", value: "\(stats.inspectionsSet + stats.inspectionsCompleted)", icon: "checkmark.seal.fill")
                statCard("Close %", value: stats.closeRate.formatted(.percent.precision(.fractionLength(0))), icon: "percent")
            }
        }
    }

    private func heroCard(title: String, value: String, icon: String, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func statCard(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(AQETheme.coral)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.statNumber)
                .foregroundStyle(AQETheme.navy)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AQETheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }
}
