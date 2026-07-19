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
                }
                Section("Coming Soon") {
                    comingSoon("Neighborhood Intel", icon: "house.and.flag.fill", phase: "Phase 3")
                    comingSoon("Team & Leaderboard", icon: "person.3.fill", phase: "Phase 4")
                    comingSoon("Digital Card", icon: "person.crop.rectangle.fill", phase: "Phase 4")
                }
                Section {
                    LabeledContent("Version", value: "0.2.0 · Phase 2")
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

    private func comingSoon(_ title: String, icon: String, phase: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(phase)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5), in: Capsule())
        }
        .foregroundStyle(.secondary)
    }
}
