import SwiftUI

/// Self-quiz mode: a random objection with the response hidden. Say your
/// answer out loud, reveal, compare, next. Deliberately stateless — no
/// scores, no history, zero friction (same design as the obj CLI's -r mode).
struct ObjectionQuizView: View {
    let entries: [BibleStore.ObjectionEntry]

    @Environment(\.dismiss) private var dismiss
    @State private var current: BibleStore.ObjectionEntry?
    @State private var revealed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let entry = current {
                        Text("SAY YOUR ANSWER OUT LOUD FIRST")
                            .font(.caption.weight(.semibold))
                            .kerning(1)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)

                        Text("“\(entry.objection)”")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AQETheme.navy)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)

                        Text(entry.category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)

                        if revealed {
                            answerSection(entry)
                        } else {
                            Button {
                                revealed = true
                            } label: {
                                Text("Reveal the response")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AQETheme.coral)
                            .padding(.top, 12)
                        }
                    } else {
                        ContentUnavailableView(
                            "No objections loaded",
                            systemImage: "shield.lefthalf.filled",
                            description: Text("The Objections articles couldn't be parsed."))
                    }
                }
                .padding()
            }
            .background(AQETheme.screenBackground)
            .navigationTitle("Objection Drill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") { next() }
                        .disabled(entries.count < 2)
                }
            }
            .onAppear { if current == nil { next() } }
        }
    }

    @ViewBuilder
    private func answerSection(_ entry: BibleStore.ObjectionEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !entry.reframe.isEmpty {
                quizLabel("THE REFRAME", color: AQETheme.navy)
                Text(entry.reframe).font(.body)
            }
            quizLabel("SAY THIS", color: AQETheme.coral)
            Text("“\(entry.response)”")
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AQETheme.navy.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            if !entry.psychology.isEmpty {
                quizLabel("WHY IT WORKS", color: .secondary)
                Text(entry.psychology)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private func quizLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .kerning(1)
            .foregroundStyle(color)
    }

    private func next() {
        revealed = false
        let pool = entries.filter { $0.id != current?.id }
        current = pool.randomElement() ?? entries.randomElement()
    }
}
