import WidgetKit
import SwiftUI

@main
struct AQEFieldWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        ShiftLiveActivity()
    }
}

// MARK: - Shared snapshot reading

/// Lenient read of the app's shared store file — decodes only what the
/// widget shows, ignoring every other key.
struct WidgetSnapshot: Decodable {
    var events: [KnockEvent]
    var goals: DailyGoals

    static func load() -> WidgetSnapshot? {
        let url: URL? = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.aqe.field")?
            .appendingPathComponent("AQEField/store.json")
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    var todayKnocks: Int {
        events.filter { Calendar.current.isDateInToday($0.timestamp) }.count
    }

    var todayLeads: Int {
        events.filter {
            Calendar.current.isDateInToday($0.timestamp) && $0.outcome == .lead
        }.count
    }
}

// MARK: - Today widget

struct TodayEntry: TimelineEntry {
    let date: Date
    let knocks: Int
    let leads: Int
    let knockGoal: Int
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), knocks: 42, leads: 3, knockGoal: 100)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [currentEntry()], policy: .after(refresh)))
    }

    private func currentEntry() -> TodayEntry {
        let snapshot = WidgetSnapshot.load()
        return TodayEntry(date: Date(),
                          knocks: snapshot?.todayKnocks ?? 0,
                          leads: snapshot?.todayLeads ?? 0,
                          knockGoal: snapshot?.goals.knocks ?? 100)
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AQEFieldToday", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Knocks")
        .description("Knock count vs. goal, at a glance.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var progress: Double {
        entry.knockGoal > 0 ? min(Double(entry.knocks) / Double(entry.knockGoal), 1) : 0
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: progress) {
                Image(systemName: "hand.raised.fingers.spread.fill")
            } currentValueLabel: {
                Text("\(entry.knocks)")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("AQE FIELD").font(.caption2.weight(.bold))
                Text("\(entry.knocks)/\(entry.knockGoal) knocks").font(.headline)
                Text("\(entry.leads) leads").font(.caption)
            }
        default:
            VStack(spacing: 6) {
                Gauge(value: progress) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(entry.knocks)")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(AQETheme.coral)
                Text("of \(entry.knockGoal) knocks")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(entry.leads) leads today")
                    .font(.caption2)
                    .foregroundStyle(AQETheme.statusGreen)
            }
        }
    }
}
