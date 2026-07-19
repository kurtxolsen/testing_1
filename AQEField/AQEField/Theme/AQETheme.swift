import SwiftUI

/// AQE brand palette — deep navy, coral, white. High contrast for bright sunlight.
enum AQETheme {
    static let navy = Color(red: 0.043, green: 0.122, blue: 0.227)      // #0B1F3A
    static let navyLight = Color(red: 0.102, green: 0.208, blue: 0.345) // #1A3558
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.38)          // #FF6B61
    static let cream = Color(red: 0.98, green: 0.97, blue: 0.95)
    static let cardBackground = Color.white
    static let screenBackground = Color(red: 0.95, green: 0.96, blue: 0.97)

    /// Pin / outcome status colors (match the map legend).
    static let statusGray = Color(.systemGray)
    static let statusBlue = Color(red: 0.20, green: 0.48, blue: 0.97)
    static let statusOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let statusGreen = Color(red: 0.13, green: 0.69, blue: 0.30)
    static let statusPurple = Color(red: 0.56, green: 0.27, blue: 0.88)
    static let statusRed = Color(red: 0.89, green: 0.17, blue: 0.17)
}

extension Font {
    /// Large stat number — readable at arm's length in sunlight.
    static let statNumber = Font.system(size: 34, weight: .heavy, design: .rounded)
    static let bigButton = Font.system(size: 22, weight: .bold, design: .rounded)
}
