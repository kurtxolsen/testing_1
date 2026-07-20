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
