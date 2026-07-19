import SwiftUI

/// Phase-1 reports: today at a glance, 7-day trend, and the follow-up queue.
/// (Deep analytics — best streets, time-of-day, neighborhoods — land in Phase 4.)
struct ReportsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section("Follow-Ups") {
                    if upcomingFollowUps.isEmpty {
                        Text("No follow-ups scheduled.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(upcomingFollowUps) { lead in
                            FollowUpRow(lead: lead)
                        }
                    }
                }
                Section("Last 7 Days") {
                    ForEach(last7Days, id: \.date) { day in
                        HStack {
                            Text(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                .frame(width: 110, alignment: .leading)
                            dayBar(knocks: day.knocks)
                            Spacer()
                            Text("\(day.knocks)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(AQETheme.navy)
                        }
                    }
                }
                Section("All-Time") {
                    LabeledContent("Total knocks", value: "\(store.events.count)")
                    LabeledContent("Total leads", value: "\(store.leads.count)")
                    LabeledContent("Contracts signed",
                                   value: "\(store.events.filter { $0.outcome == .contractSigned }.count)")
                    LabeledContent("Current streak", value: "\(store.streakDays) days")
                }
            }
            .navigationTitle("Reports")
        }
    }

    private var upcomingFollowUps: [Lead] {
        store.leads
            .filter { $0.followUpDate != nil }
            .sorted { ($0.followUpDate ?? .distantFuture) < ($1.followUpDate ?? .distantFuture) }
    }

    private struct DayCount {
        let date: Date
        let knocks: Int
    }

    private var last7Days: [DayCount] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let count = store.events.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.count
            return DayCount(date: calendar.startOfDay(for: date), knocks: count)
        }
    }

    private func dayBar(knocks: Int) -> some View {
        GeometryReader { geo in
            let maxKnocks = max(last7Days.map(\.knocks).max() ?? 1, 1)
            RoundedRectangle(cornerRadius: 4)
                .fill(AQETheme.coral)
                .frame(width: geo.size.width * CGFloat(knocks) / CGFloat(maxKnocks))
        }
        .frame(height: 12)
    }
}

struct FollowUpRow: View {
    let lead: Lead

    private var isOverdue: Bool {
        (lead.followUpDate ?? .distantFuture) < Date()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(isOverdue ? AQETheme.statusRed : AQETheme.statusOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text(lead.name.isEmpty ? (lead.address.isEmpty ? "Lead" : lead.address) : lead.name)
                    .font(.headline)
                if let date = lead.followUpDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(isOverdue ? AQETheme.statusRed : .secondary)
                }
            }
            Spacer()
            if !lead.phone.isEmpty, let url = URL(string: "tel:\(lead.phone.filter(\.isNumber))") {
                Link(destination: url) {
                    Image(systemName: "phone.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AQETheme.statusGreen)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
