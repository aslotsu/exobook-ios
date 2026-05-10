import SwiftUI

extension Color {
    /// Page background. Zinc-900 in dark mode, systemBackground in light.
    static let appBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 24/255, green: 24/255, blue: 27/255, alpha: 1)
            : UIColor.systemBackground
    })

    /// Card surface. Same tone as appBackground today; kept as a separate
    /// token so we can lighten cards later without touching every view.
    static let appCardBackground = appBackground

    /// Secondary surface for chips, search bars, list rows, secondary buttons.
    static let appSecondaryBackground = Color(uiColor: .secondarySystemBackground)

    /// Brand accent.
    static let appAccent = Color.blue
}
