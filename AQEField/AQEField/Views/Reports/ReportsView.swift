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
                funnelSection
                bestTimesSection
                bestStreetsSection
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

    // MARK: - Analytics sections

    private var funnelSection: some View {
        Section("Conversion Funnel (All-Time)") {
            let funnel = store.allTimeFunnel
            funnelRow("Knocks", count: funnel.knocks, max: funnel.knocks, color: AQETheme.navy)
            funnelRow("Conversations", count: funnel.conversations, max: funnel.knocks,
                      color: AQETheme.statusBlue)
            funnelRow("Leads", count: funnel.leads, max: funnel.knocks, color: AQETheme.statusGreen)
            funnelRow("Inspections", count: funnel.inspections, max: funnel.knocks,
                      color: AQETheme.statusPurple)
            funnelRow("Signed", count: funnel.signed, max: funnel.knocks, color: AQETheme.coral)
            LabeledContent("Conversation rate",
                           value: funnel.conversationRate.formatted(.percent.precision(.fractionLength(0))))
            LabeledContent("Close rate",
                           value: funnel.closeRate.formatted(.percent.precision(.fractionLength(0))))
            if let knocksPerLead = funnel.knocksPerLead {
                LabeledContent("Knocks per lead", value: String(format: "%.0f", knocksPerLead))
            }
        }
    }

    private func funnelRow(_ title: String, count: Int, max: Int, color: Color) -> some View {
        HStack {
            Text(title).frame(width: 110, alignment: .leading)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max > 0 ? geo.size.width * CGFloat(count) / CGFloat(max) : 0)
            }
            .frame(height: 12)
            Spacer()
            Text("\(count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(AQETheme.navy)
        }
    }

    private var bestTimesSection: some View {
        Section("Best Time of Day") {
            let hours = store.hourlyPerformance.filter { $0.knocks >= 5 }
            if hours.isEmpty {
                Text("Knock more doors — hourly stats unlock at 5 knocks per hour slot.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(hours.sorted { $0.rate > $1.rate }.prefix(5)) { hour in
                    HStack {
                        Text(hour.label).frame(width: 60, alignment: .leading)
                        Text("\(hour.knocks) knocks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(hour.rate.formatted(.percent.precision(.fractionLength(0))))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(AQETheme.statusGreen)
                    }
                }
            }
        }
    }

    private var bestStreetsSection: some View {
        Section("Best Streets") {
            if store.bestStreets.isEmpty {
                Text("Street rankings unlock once a street has 3+ knocks with addresses.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.bestStreets.prefix(5)) { street in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(street.street).font(.headline)
                            Text("\(street.knocks) knocks · \(street.leads) leads")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(street.rate.formatted(.percent.precision(.fractionLength(0))))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(AQETheme.statusGreen)
                    }
                }
            }
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
