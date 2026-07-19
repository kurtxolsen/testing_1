import SwiftUI

/// The heart of the app: huge one-tap outcome buttons. Each tap timestamps,
/// GPS-tags, and updates goals/reports instantly — then confirms with haptics.
struct KnockView: View {
    @Environment(AppStore.self) private var store
    @Environment(LocationService.self) private var location
    @State private var lastLogged: KnockEvent?
    @State private var confirmationVisible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    locationChip
                    ForEach(KnockOutcome.allCases) { outcome in
                        outcomeButton(outcome)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 90)
            }
            .background(AQETheme.screenBackground)
            .navigationTitle("Knock")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) {
                if confirmationVisible, let event = lastLogged {
                    confirmationBanner(event)
                }
            }
        }
    }

    private var locationChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
            Text(location.lastAddress ?? "Locating…")
                .lineLimit(1)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func outcomeButton(_ outcome: KnockOutcome) -> some View {
        Button {
            log(outcome)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: outcome.icon)
                    .font(.title2)
                    .frame(width: 36)
                Text(outcome.rawValue)
                    .font(.bigButton)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(outcome.color, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: lastLogged?.id)
    }

    private func log(_ outcome: KnockOutcome) {
        lastLogged = store.logKnock(outcome,
                                    latitude: location.lastCoordinate?.latitude,
                                    longitude: location.lastCoordinate?.longitude,
                                    address: location.lastAddress)
        withAnimation(.spring(duration: 0.25)) { confirmationVisible = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { confirmationVisible = false }
        }
    }

    private func confirmationBanner(_ event: KnockEvent) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text("\(event.outcome.rawValue) logged")
                .font(.headline)
            Button("Undo") {
                store.deleteEvent(event)
                withAnimation { confirmationVisible = false }
            }
            .font(.headline)
            .foregroundStyle(AQETheme.coral)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(AQETheme.navy, in: Capsule())
        .shadow(radius: 6, y: 3)
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
