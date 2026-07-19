import SwiftUI

/// Searchable Field Bible presented as its own sheet (from the Dashboard
/// quick action). Wraps the shared content in a NavigationStack.
struct FieldBibleView: View {
    var body: some View {
        NavigationStack {
            FieldBibleContentView()
        }
    }
}

/// The Bible's browsable/searchable content. Push-safe: no NavigationStack of
/// its own, so it also lives inside the More tab's stack.
struct FieldBibleContentView: View {
    @State private var bible = BibleStore()
    @State private var query = ""

    private var results: [BibleArticle] {
        bible.search(query)
    }

    var body: some View {
        Group {
            if query.isEmpty {
                categoryList
            } else {
                searchResults
            }
        }
        .navigationTitle("Field Bible")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Objection, carrier, GAF, script…")
        .navigationDestination(for: BibleArticle.self) { article in
            ArticleView(article: article)
        }
    }

    private var categoryList: some View {
        List {
            ForEach(bible.categories, id: \.self) { category in
                Section(category) {
                    ForEach(bible.articles(in: category)) { article in
                        NavigationLink(value: article) {
                            Label(article.title, systemImage: Self.icon(for: category))
                                .font(.headline)
                                .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
    }

    private var searchResults: some View {
        List(results) { article in
            NavigationLink(value: article) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(.headline)
                    Text(article.category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    static func icon(for category: String) -> String {
        switch category {
        case "Scripts": return "text.bubble.fill"
        case "Objections": return "shield.lefthalf.filled"
        case "Insurance": return "building.columns.fill"
        case "GAF & Warranty": return "checkmark.seal.fill"
        case "Roof Knowledge": return "house.fill"
        case "Psychology": return "brain.head.profile"
        case "SOPs": return "list.clipboard.fill"
        default: return "book.fill"
        }
    }
}

/// Renders an article's markdown with a lightweight block parser —
/// headings, bullets, tables-as-text, and inline bold/italics via
/// AttributedString. No dependencies, instant, offline.
struct ArticleView: View {
    let article: BibleArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .padding()
        }
        .background(AQETheme.screenBackground)
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private enum Block {
        case heading1(String), heading2(String), heading3(String)
        case bullet(String), numbered(String), paragraph(String), rule
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var paragraph: [String] = []

        func flush() {
            if !paragraph.isEmpty {
                result.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph = []
            }
        }

        for rawLine in article.body.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush() }
            else if line == "---" { flush(); result.append(.rule) }
            else if line.hasPrefix("### ") { flush(); result.append(.heading3(String(line.dropFirst(4)))) }
            else if line.hasPrefix("## ") { flush(); result.append(.heading2(String(line.dropFirst(3)))) }
            else if line.hasPrefix("# ") { flush(); result.append(.heading1(String(line.dropFirst(2)))) }
            else if line.hasPrefix("- ") { flush(); result.append(.bullet(String(line.dropFirst(2)))) }
            else if let range = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                flush(); result.append(.numbered(String(line[range.upperBound...])))
            } else { paragraph.append(line) }
        }
        flush()
        // Drop the top-level title heading — the nav bar already shows it.
        if case .heading1 = result.first { result.removeFirst() }
        return result
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading1(let text), .heading2(let text):
            Text(inline(text))
                .font(.title2.weight(.bold))
                .foregroundStyle(AQETheme.navy)
                .padding(.top, 10)
        case .heading3(let text):
            Text(inline(text))
                .font(.headline)
                .foregroundStyle(AQETheme.coral)
                .padding(.top, 6)
        case .bullet(let text):
            HStack(alignment: .top, spacing: 8) {
                Circle().fill(AQETheme.coral).frame(width: 6, height: 6).padding(.top, 8)
                Text(inline(text)).font(.body)
            }
        case .numbered(let text):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AQETheme.coral)
                    .padding(.top, 4)
                Text(inline(text)).font(.body)
            }
        case .paragraph(let text):
            Text(inline(text)).font(.body)
        case .rule:
            Divider().padding(.vertical, 4)
        }
    }
}
