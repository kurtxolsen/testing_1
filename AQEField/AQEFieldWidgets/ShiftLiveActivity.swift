import WidgetKit
import SwiftUI
import ActivityKit

/// The shift timer: Dynamic Island + Lock Screen card, updated on every
/// logged knock by the app.
struct ShiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftActivityAttributes.self) { context in
            // Lock Screen banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AQE FIELD SHIFT")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AQETheme.coral)
                    Text(timerInterval: context.attributes.startedAt...Date(timeIntervalSinceNow: 86_400),
                         countsDown: false)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                }
                Spacer()
                statColumn("\(context.state.knocks)", label: "knocks")
                statColumn("\(context.state.conversations)", label: "convos")
                statColumn("\(context.state.leads)", label: "leads")
            }
            .padding()
            .activityBackgroundTint(AQETheme.navy)
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(timerInterval: context.attributes.startedAt...Date(timeIntervalSinceNow: 86_400),
                         countsDown: false)
                        .font(.headline.monospacedDigit())
                        .frame(maxWidth: 70)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.knocks)/\(context.state.knockGoal)")
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        statColumn("\(context.state.knocks)", label: "knocks")
                        statColumn("\(context.state.conversations)", label: "convos")
                        statColumn("\(context.state.leads)", label: "leads")
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: "hand.raised.fingers.spread.fill")
                    .foregroundStyle(AQETheme.coral)
            } compactTrailing: {
                Text("\(context.state.knocks)")
                    .font(.headline.monospacedDigit())
            } minimal: {
                Text("\(context.state.knocks)")
                    .font(.caption.weight(.bold).monospacedDigit())
            }
        }
    }

    private func statColumn(_ value: String, label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
