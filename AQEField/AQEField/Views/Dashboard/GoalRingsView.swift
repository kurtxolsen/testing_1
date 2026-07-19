import SwiftUI

/// Apple-Fitness-style progress rings for today's goals.
struct GoalRingsView: View {
    let stats: DayStats
    let goals: DailyGoals

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Goals")
                .font(.title3.weight(.bold))
                .foregroundStyle(AQETheme.navy)
            HStack(spacing: 0) {
                GoalRing(label: "Knocks", current: stats.knocks,
                         goal: goals.knocks, color: AQETheme.coral)
                GoalRing(label: "Convos", current: stats.conversations,
                         goal: goals.conversations, color: AQETheme.statusOrange)
                GoalRing(label: "Inspections", current: stats.inspectionsSet + stats.inspectionsCompleted,
                         goal: goals.inspections, color: AQETheme.statusPurple)
                GoalRing(label: "Signed", current: stats.contractsSigned,
                         goal: goals.signedJobs, color: AQETheme.statusGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AQETheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GoalRing: View {
    let label: String
    let current: Int
    let goal: Int
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: progress)
                VStack(spacing: 0) {
                    Text("\(current)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(AQETheme.navy)
                    Text("/\(goal)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 68, height: 68)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(current) of \(goal)")
    }
}
