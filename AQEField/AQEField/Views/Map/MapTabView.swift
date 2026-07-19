import SwiftUI
import MapKit

/// Working map: every logged knock drops a color-coded pin at its GPS fix.
/// Tap a pin for details. (Neighborhood intelligence overlays land in Phase 3.)
struct MapTabView: View {
    @Environment(AppStore.self) private var store
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedEvent: KnockEvent?

    private var pinnedEvents: [KnockEvent] {
        store.events.filter { $0.coordinate != nil }
    }

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                UserAnnotation()
                ForEach(pinnedEvents) { event in
                    Annotation(event.outcome.rawValue, coordinate: event.coordinate!) {
                        Button {
                            selectedEvent = event
                        } label: {
                            Image(systemName: event.outcome.icon)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(event.outcome.color, in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(radius: 2)
                        }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { legendMenu }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event)
            }
        }
    }

    private var legendMenu: some View {
        Menu {
            ForEach(KnockOutcome.allCases) { outcome in
                Label(outcome.rawValue, systemImage: "circle.fill")
            }
        } label: {
            Image(systemName: "list.bullet.circle.fill")
                .font(.title3)
        }
    }
}

struct EventDetailSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let event: KnockEvent

    var body: some View {
        NavigationStack {
            List {
                HStack {
                    Image(systemName: event.outcome.icon)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(event.outcome.color, in: Circle())
                    Text(event.outcome.rawValue)
                        .font(.title3.weight(.bold))
                }
                if let address = event.address, !address.isEmpty {
                    LabeledContent("Address", value: address)
                }
                LabeledContent("Time", value: event.timestamp.formatted(date: .abbreviated, time: .shortened))
                if let note = event.note, !note.isEmpty {
                    LabeledContent("Note", value: note)
                }
                Button("Delete", role: .destructive) {
                    store.deleteEvent(event)
                    dismiss()
                }
            }
            .navigationTitle("Knock Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
