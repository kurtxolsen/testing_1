import SwiftUI

/// Neighborhood Mode: swipe left/right between houses, huge one-handed
/// outcome buttons, and the house's full intel card — everything you need
/// while standing at the door.
struct NeighborhoodView: View {
    @Environment(AppStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHouseID: String?
    @State private var editingIntel: PropertyIntel?

    var body: some View {
        NavigationStack {
            Group {
                if store.houses.isEmpty {
                    ContentUnavailableView(
                        "No houses yet",
                        systemImage: "house.and.flag.fill",
                        description: Text("Houses appear here as you knock. Log a door from the Knock tab first.")
                    )
                } else {
                    TabView(selection: $selectedHouseID) {
                        ForEach(store.houses) { house in
                            HouseCard(house: house) {
                                editingIntel = existingOrNewIntel(for: house)
                            }
                            .tag(Optional(house.id))
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                }
            }
            .background(AQETheme.screenBackground)
            .navigationTitle("Neighborhood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingIntel) { record in
                IntelEditorSheet(record: record)
            }
        }
    }

    private func existingOrNewIntel(for house: HouseSummary) -> PropertyIntel {
        if let existing = house.intel { return existing }
        return PropertyIntel(address: house.address,
                             latitude: house.coordinate?.latitude,
                             longitude: house.coordinate?.longitude)
    }
}

/// One swipeable house: status header, intel grid, and one-tap outcomes.
struct HouseCard: View {
    @Environment(AppStore.self) private var store
    let house: HouseSummary
    var onEditIntel: () -> Void

    /// The doorstep short list — full list lives on the Knock tab.
    private let quickOutcomes: [KnockOutcome] = [
        .noAnswer, .conversation, .followUp, .lead, .inspectionSet, .notInterested,
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                intelGrid
                outcomes
            }
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(house.address)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(AQETheme.navy)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                if let outcome = house.lastOutcome {
                    Label(outcome.rawValue, systemImage: outcome.icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(outcome.color, in: Capsule())
                } else {
                    Label("Not visited", systemImage: "circle.dashed")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                if let lastVisit = house.lastVisit {
                    Text(lastVisit.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if house.knockCount > 1 {
                Text("\(house.knockCount) visits")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AQETheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private var intelGrid: some View {
        VStack(spacing: 8) {
            HStack {
                Text("House Intel")
                    .font(.headline)
                    .foregroundStyle(AQETheme.navy)
                Spacer()
                Button(action: onEditIntel) {
                    Label(house.intel == nil ? "Add" : "Edit", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.bold))
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                intelTile("Est. Value", value: house.intel?.valueEstimate.map {
                    $0.formatted(.currency(code: "USD").precision(.fractionLength(0)))
                }, icon: "dollarsign.circle.fill")
                intelTile("Roof Age", value: house.intel?.roofAgeYears.map { "\($0) yrs" },
                          icon: "house.fill")
                intelTile("Last Hail", value: house.intel?.lastHailDate.map {
                    $0.formatted(date: .abbreviated, time: .omitted)
                }, icon: "cloud.hail.fill")
                intelTile("Homeowner", value: house.intel.flatMap {
                    $0.homeownerName.isEmpty ? nil : $0.homeownerName
                }, icon: "person.fill")
            }
            if let permits = house.intel?.permitNotes, !permits.isEmpty {
                noteRow("Permits", text: permits, icon: "doc.text.fill")
            }
            if let insurance = house.intel?.insuranceNotes, !insurance.isEmpty {
                noteRow("Insurance", text: insurance, icon: "building.columns.fill")
            }
        }
        .padding()
        .background(AQETheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func intelTile(_ title: String, value: String?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value ?? "—")
                .font(.headline)
                .foregroundStyle(value == nil ? Color.secondary : AQETheme.navy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AQETheme.screenBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private func noteRow(_ title: String, text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AQETheme.coral)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(text).font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AQETheme.screenBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private var outcomes: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(quickOutcomes) { outcome in
                Button {
                    store.logKnock(outcome,
                                   latitude: house.coordinate?.latitude,
                                   longitude: house.coordinate?.longitude,
                                   address: house.address)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: outcome.icon)
                            .font(.title3)
                        Text(outcome.rawValue)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(outcome.color, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Edit every intel field for one house. All fields optional — capture what
/// you know, skip what you don't.
struct IntelEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var record: PropertyIntel
    @State private var hasHailDate = false

    var body: some View {
        NavigationStack {
            Form {
                Section("House") {
                    TextField("Address", text: $record.address)
                    TextField("Homeowner name", text: $record.homeownerName)
                }
                Section("Property") {
                    HStack {
                        Text("Est. value")
                        Spacer()
                        TextField("$", value: $record.valueEstimate,
                                  format: .currency(code: "USD").precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 130)
                    }
                    HStack {
                        Text("Roof age (years)")
                        Spacer()
                        TextField("—", value: $record.roofAgeYears, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Toggle("Known hail date", isOn: $hasHailDate)
                    if hasHailDate {
                        DatePicker("Last hail",
                                   selection: Binding(
                                       get: { record.lastHailDate ?? store.latestStorm?.date ?? Date() },
                                       set: { record.lastHailDate = $0 }),
                                   displayedComponents: .date)
                    }
                }
                Section("Permit history") {
                    TextField("Roof permits, year re-roofed, solar…",
                              text: $record.permitNotes, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Insurance notes") {
                    TextField("Carrier, deductible, claim status…",
                              text: $record.insuranceNotes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("House Intel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !hasHailDate { record.lastHailDate = nil }
                        store.upsertIntel(record)
                        dismiss()
                    }
                    .font(.headline)
                    .disabled(record.address.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { hasHailDate = record.lastHailDate != nil }
        }
    }
}
