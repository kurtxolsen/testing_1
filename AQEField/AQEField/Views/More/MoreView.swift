import SwiftUI

/// Settings + goal editing. Field Bible, Digital Card, and Team slots are
/// stubbed here so navigation doesn't move when later phases fill them in.
struct MoreView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section("Daily Goals") {
                    goalStepper("Knocks", value: $store.goals.knocks, step: 10)
                    goalStepper("Conversations", value: $store.goals.conversations, step: 5)
                    goalStepper("Inspections", value: $store.goals.inspections, step: 1)
                    goalStepper("Signed Jobs", value: $store.goals.signedJobs, step: 1)
                }
                Section("Money Estimator") {
                    HStack {
                        Text("Value per signed job")
                        Spacer()
                        TextField("Value", value: $store.goals.valuePerSignedJob,
                                  format: .currency(code: "USD").precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                    }
                }
                Section("Library") {
                    NavigationLink {
                        FieldBibleContentView()
                    } label: {
                        Label("Field Bible", systemImage: "book.fill")
                            .font(.headline)
                    }
                    NavigationLink {
                        StormLogView()
                    } label: {
                        Label("Storm Log", systemImage: "cloud.bolt.rain.fill")
                            .font(.headline)
                    }
                    NavigationLink {
                        DigitalCardView()
                    } label: {
                        Label("Digital Card", systemImage: "person.crop.rectangle.fill")
                            .font(.headline)
                    }
                    NavigationLink {
                        TeamView()
                    } label: {
                        Label("Team & Leaderboard", systemImage: "person.3.fill")
                            .font(.headline)
                    }
                    NavigationLink {
                        CloudSyncView()
                    } label: {
                        Label("Cloud Sync", systemImage: "icloud.fill")
                            .font(.headline)
                    }
                }
                Section("Shift") {
                    Button {
                        ShiftActivityManager.end()
                    } label: {
                        Label("End Shift Timer", systemImage: "stop.circle.fill")
                            .font(.headline)
                            .foregroundStyle(AQETheme.statusRed)
                    }
                }
                Section {
                    LabeledContent("Version", value: "0.7.0 · Phase 7")
                }
            }
            .navigationTitle("More")
        }
    }

    private func goalStepper(_ title: String, value: Binding<Int>, step: Int) -> some View {
        Stepper(value: value, in: step...1000, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(AQETheme.coral)
            }
        }
    }
}
