import SwiftUI

/// Minimal-typing lead capture. Address, GPS, date, and weather auto-fill;
/// the rep only types a name and phone if they have them.
struct NewLeadSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(WeatherService.self) private var weather
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var note = ""
    @State private var wantsFollowUp = true
    @State private var followUpDate = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Homeowner") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                Section("Auto-filled") {
                    TextField("Address", text: $address)
                        .textContentType(.fullStreetAddress)
                    LabeledContent("Date", value: Date().formatted(date: .abbreviated, time: .shortened))
                    if let summary = weather.summary {
                        LabeledContent("Weather", value: summary)
                    }
                    if location.lastCoordinate != nil {
                        LabeledContent("GPS", value: "Captured ✓")
                    }
                    if let storm = store.latestStorm {
                        LabeledContent("Storm", value: storm.name.isEmpty ? storm.summary : storm.name)
                    }
                }
                Section("Follow-up") {
                    Toggle("Schedule follow-up", isOn: $wantsFollowUp)
                    if wantsFollowUp {
                        DatePicker("When", selection: $followUpDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                Section("Notes") {
                    TextField("Roof condition, insurance carrier, best time to reach…",
                              text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("New Lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.headline)
                }
            }
            .onAppear {
                if address.isEmpty { address = location.lastAddress ?? "" }
            }
        }
    }

    private func save() {
        var lead = Lead()
        lead.name = name
        lead.phone = phone
        lead.address = address
        lead.note = note
        lead.latitude = location.lastCoordinate?.latitude
        lead.longitude = location.lastCoordinate?.longitude
        lead.weatherAtCreation = weather.summary
        lead.stormEvent = store.latestStorm.map { $0.name.isEmpty ? $0.summary : $0.name }
        lead.followUpDate = wantsFollowUp ? followUpDate : nil
        store.addLead(lead)
        // A saved lead is also a logged door — keeps stats honest with one tap.
        store.logKnock(.lead,
                       latitude: lead.latitude,
                       longitude: lead.longitude,
                       address: address.isEmpty ? nil : address,
                       note: note.isEmpty ? nil : note)
        dismiss()
    }
}
