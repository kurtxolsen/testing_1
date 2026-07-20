import SwiftUI
import MapKit

/// The primary work surface: color-coded pins for every knock, plus Phase 3
/// intelligence layers — GPS breadcrumb trail, storm overlay, heat view —
/// and the Neighborhood Mode launcher.
struct MapTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(LocationService.self) private var location
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedEvent: KnockEvent?
    @State private var showNeighborhood = false
    @State private var showTrail = true
    @State private var showStorm = true
    @State private var showHeat = false

    private var pinnedEvents: [KnockEvent] {
        store.events.filter { $0.coordinate != nil }
    }

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                UserAnnotation()

                if showHeat {
                    // Poor-man's heat map: translucent halo per event, so
                    // worked streets glow by density and outcome color.
                    ForEach(pinnedEvents) { event in
                        MapCircle(center: event.coordinate!, radius: 40)
                            .foregroundStyle(event.outcome.color.opacity(0.18))
                    }
                }

                if showStorm, let storm = store.latestStorm, let center = storm.coordinate {
                    MapCircle(center: center, radius: storm.radiusMiles * 1609.34)
                        .foregroundStyle(AQETheme.coral.opacity(0.10))
                        .stroke(AQETheme.coral.opacity(0.6), lineWidth: 2)
                }

                if showTrail, store.todayTrail.count > 1 {
                    MapPolyline(coordinates: store.todayTrail.map(\.coordinate))
                        .stroke(AQETheme.navy.opacity(0.65),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 7]))
                }

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
                ToolbarItem(placement: .topBarLeading) { trailButton }
                ToolbarItem(placement: .topBarTrailing) { layersMenu }
            }
            .safeAreaInset(edge: .bottom) { neighborhoodButton }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event)
            }
            .sheet(isPresented: $showNeighborhood) { NeighborhoodView() }
        }
    }

    // MARK: - Controls

    /// Start/stop the breadcrumb recorder.
    private var trailButton: some View {
        Button {
            location.isTrackingTrail.toggle()
        } label: {
            Label(location.isTrackingTrail ? "Recording" : "Trail",
                  systemImage: location.isTrackingTrail ? "record.circle.fill" : "record.circle")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(location.isTrackingTrail ? AQETheme.statusRed : AQETheme.navy)
        }
    }

    private var layersMenu: some View {
        Menu {
            Toggle("Breadcrumb trail", isOn: $showTrail)
            Toggle("Storm overlay", isOn: $showStorm)
            Toggle("Heat view", isOn: $showHeat)
            if let storm = store.latestStorm {
                Text("Storm: \(storm.name.isEmpty ? storm.summary : storm.name)")
            }
        } label: {
            Image(systemName: "square.3.layers.3d.top.filled")
                .font(.title3)
        }
    }

    private var neighborhoodButton: some View {
        Button {
            showNeighborhood = true
        } label: {
            Label("Neighborhood Mode", systemImage: "house.and.flag.fill")
                .font(.bigButton)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(AQETheme.navy, in: RoundedRectangle(cornerRadius: 18))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
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
