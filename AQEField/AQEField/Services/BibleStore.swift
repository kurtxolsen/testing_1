import Foundation
import Observation

/// One searchable Field Bible article, loaded from the bundled markdown.
struct BibleArticle: Identifiable, Hashable {
    let id: String            // resource file name
    let title: String
    let category: String
    let tags: [String]
    let body: String          // raw markdown

    /// Lowercased haystack for search.
    var searchText: String {
        "\(title) \(category) \(tags.joined(separator: " ")) \(body)".lowercased()
    }
}

/// Loads the bundled Field Bible (manifest.json + markdown files) once at
/// startup and serves category browsing + full-text search. Fully offline.
@Observable
final class BibleStore {
    private(set) var articles: [BibleArticle] = []

    /// Display order for category sections.
    let categoryOrder = ["Scripts", "Objections", "Insurance", "GAF & Warranty",
                         "Roof Knowledge", "Psychology", "SOPs"]

    init() {
        load()
    }

    var categories: [String] {
        let present = Set(articles.map(\.category))
        return categoryOrder.filter(present.contains)
            + present.subtracting(categoryOrder).sorted()
    }

    func articles(in category: String) -> [BibleArticle] {
        articles.filter { $0.category == category }
    }

    /// Case-insensitive search across title, tags, category, and body.
    /// Every whitespace-separated term must match somewhere.
    func search(_ query: String) -> [BibleArticle] {
        let terms = query.lowercased().split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return articles }
        return articles.filter { article in
            let haystack = article.searchText
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    // MARK: - Structured objection entries (for quiz mode)

    /// One drillable objection: the homeowner's words plus the word-for-word
    /// response, parsed from the strict "## OBJECTION:" format the Objections
    /// articles use.
    struct ObjectionEntry: Identifiable, Hashable {
        let id: String
        let objection: String
        let category: String
        let reframe: String
        let response: String
        let psychology: String
    }

    /// Every objection across the Objections category, parsed once per access.
    var objectionEntries: [ObjectionEntry] {
        articles(in: "Objections").flatMap(Self.parseObjections)
    }

    static func parseObjections(from article: BibleArticle) -> [ObjectionEntry] {
        var entries: [ObjectionEntry] = []
        var objection: String?
        var sections: [String: [String]] = [:]
        var currentSection: String?

        func flush() {
            guard let text = objection else { return }
            let joined = { (key: String) in
                (sections[key] ?? []).joined(separator: " ")
            }
            entries.append(ObjectionEntry(
                id: "\(article.id)#\(entries.count)",
                objection: text,
                category: article.title,
                reframe: joined("the reframe"),
                response: joined("word-for-word response"),
                psychology: joined("the psychology")))
            objection = nil
            sections = [:]
            currentSection = nil
        }

        for rawLine in article.body.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## OBJECTION:") {
                flush()
                objection = String(line.dropFirst("## OBJECTION:".count))
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            } else if line.hasPrefix("### ") {
                currentSection = String(line.dropFirst(4)).lowercased()
            } else if line == "---" || line.hasPrefix("**Tags:**") || line.hasPrefix("**Category:**") {
                if line == "---" { currentSection = nil }
            } else if let section = currentSection, !line.isEmpty {
                sections[section, default: []].append(line)
            }
        }
        flush()
        // Only keep entries that actually have a deliverable response.
        return entries.filter { !$0.response.isEmpty }
    }

    // MARK: - Loading

    private struct Manifest: Decodable {
        struct Entry: Decodable {
            let file: String
            let title: String
            let category: String
            let tags: [String]
        }
        let articles: [Entry]
    }

    private func load() {
        guard let manifestURL = Bundle.main.url(forResource: "manifest", withExtension: "json"),
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
            return
        }
        articles = manifest.articles.compactMap { entry in
            guard let url = Bundle.main.url(forResource: entry.file, withExtension: "md"),
                  let body = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return BibleArticle(id: entry.file, title: entry.title,
                                category: entry.category, tags: entry.tags, body: body)
        }
    }
}
