import SwiftUI

/// Manual storm log. The most recent storm auto-tags new leads and powers
/// the map's storm overlay. (NOAA auto-import is a future data provider.)
struct StormLogView: View {
    @Environment(AppStore.self) private var store
    @State private var showAdd = false

    var body: some View {
        List {
            if store.storms.isEmpty {
                Text("Log the storms you're working — the newest one auto-fills new leads and draws the map overlay.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.storms.sorted { $0.date > $1.date }) { storm in
                VStack(alignment: .leading, spacing: 2) {
                    Text(storm.name.isEmpty ? "Storm" : storm.name)
                        .font(.headline)
                    Text(storm.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        store.storms.removeAll { $0.id == storm.id }
                    }
                }
            }
        }
        .navigationTitle("Storm Log")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddStormSheet() }
    }
}

struct AddStormSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var date = Date()
    @State private var hailSize: Double?
    @State private var windMph: Int?
    @State private var radiusMiles = 3.0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (\"June 14 hail\")", text: $name)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                HStack {
                    Text("Hail size (inches)")
                    Spacer()
                    TextField("—", value: $hailSize, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Text("Wind (mph)")
                    Spacer()
                    TextField("—", value: $windMph, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Section("Map overlay") {
                    LabeledContent("Center", value: location.lastCoordinate == nil
                                   ? "Current location unavailable" : "Current location")
                    Stepper(value: $radiusMiles, in: 1...15, step: 1) {
                        Text("Radius: \(Int(radiusMiles)) mi")
                    }
                }
            }
            .navigationTitle("Log Storm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var storm = StormEvent(date: date, name: name)
                        storm.hailSizeInches = hailSize
                        storm.windMph = windMph
                        storm.latitude = location.lastCoordinate?.latitude
                        storm.longitude = location.lastCoordinate?.longitude
                        storm.radiusMiles = radiusMiles
                        store.storms.append(storm)
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
        .presentationDetents([.large])
    }
}
