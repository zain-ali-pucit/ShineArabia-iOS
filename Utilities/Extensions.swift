import SwiftUI
import UIKit

// MARK: - View Extensions
extension View {
    /// Applies RTL layout direction for Arabic
    func arabicLayout(_ isArabic: Bool) -> some View {
        self.environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
    }

    /// Conditional modifier
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition { transform(self) } else { self }
    }

    /// Dismisses the keyboard when the user taps anywhere on the view.
    /// Uses simultaneousGesture so child buttons and scroll views still receive their events.
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
    }
}

// MARK: - Date Formatter
extension DateFormatter {
    static let shineDisplay: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Localization Helper
struct Loc {
    static func string(_ key: String, isArabic: Bool) -> String {
        let lang = isArabic ? "ar" : "en"
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
