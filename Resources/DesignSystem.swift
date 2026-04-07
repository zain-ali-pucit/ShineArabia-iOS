import SwiftUI

// MARK: - ShineArabia Design System
// Mirrors the exact CSS variables from the HTML prototype:
// --coral: #8D1B3D  --teal: #2D8C7A  --amber: #D4893A  --lavender: #7B6FA0
// --bg: #F7F5F2  --surface: #FFFFFF  --ink: #1C1917

// MARK: - Colors
extension Color {
    // Primary accent — Qatar maroon
    static let shineCoral       = Color(hex: "8D1B3D")
    static let shineCoralLight  = Color(hex: "F7E8EE")
    static let shineCoralMid    = Color(hex: "C4728E")

    // Secondary — teal
    static let shineTeal        = Color(hex: "2D8C7A")
    static let shineTealLight   = Color(hex: "E4F4F1")
    static let shineTealMid     = Color(hex: "7EC8BC")

    // Tertiary — amber
    static let shineAmber       = Color(hex: "D4893A")
    static let shineAmberLight  = Color(hex: "FEF3E8")

    // Quaternary — lavender
    static let shineLavender    = Color(hex: "7B6FA0")
    static let shineLavLight    = Color(hex: "F0EEF8")

    // Backgrounds & surfaces
    static let shineBG          = Color(hex: "F7F5F2")
    static let shineSurface     = Color(hex: "FFFFFF")
    static let shineSurface2    = Color(hex: "F0EDE8")

    // Typography
    static let shineInk         = Color(hex: "1C1917")
    static let shineInk2        = Color(hex: "6B6560")
    static let shineInk3        = Color(hex: "A8A39E")

    // Dark card (promo banner)
    static let shineDark        = Color(hex: "1C1917")
    static let shineDark2       = Color(hex: "2E2925")

    // Border / divider
    static let shineBorder      = Color(hex: "E2DED8")
}

// MARK: - Hex Color Init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB,
                  red:   Double(r)/255,
                  green: Double(g)/255,
                  blue:  Double(b)/255,
                  opacity: Double(a)/255)
    }
}

// MARK: - Typography
// Uses Cormorant Garamond (display/headings) + Outfit (body)
// Register in Info.plist: UIAppFonts
struct ShineFont {
    // Cormorant Garamond — editorial headings
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("CormorantGaramond-SemiBold", size: size)
    }
    static func displayItalic(_ size: CGFloat) -> Font {
        .custom("CormorantGaramond-Italic", size: size)
    }
    static func displayBold(_ size: CGFloat) -> Font {
        .custom("CormorantGaramond-Bold", size: size)
    }

    // Outfit — clean body text
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .light:   return .custom("Outfit-Light",   size: size)
        case .medium:  return .custom("Outfit-Medium",  size: size)
        case .semibold:return .custom("Outfit-SemiBold",size: size)
        case .bold:    return .custom("Outfit-Bold",    size: size)
        default:       return .custom("Outfit-Regular", size: size)
        }
    }

    // Arabic fallback — Noto Kufi Arabic
    static func arabic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .semibold, .bold: return .custom("NotoKufiArabic-SemiBold", size: size)
        default:               return .custom("NotoKufiArabic-Regular",  size: size)
        }
    }
}

// MARK: - Spacing
struct ShineSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
struct ShineRadius {
    static let sm:  CGFloat = 14
    static let md:  CGFloat = 20
    static let lg:  CGFloat = 28
    static let xl:  CGFloat = 36
    static let pill: CGFloat = 50
}

// MARK: - Shadow
extension View {
    func shineShadowXS() -> some View {
        shadow(color: Color.shineInk.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    func shineShadowSM() -> some View {
        shadow(color: Color.shineInk.opacity(0.07), radius: 10, x: 0, y: 4)
    }
    func shineShadowMD() -> some View {
        shadow(color: Color.shineInk.opacity(0.10), radius: 20, x: 0, y: 12)
    }
    func shineShadowLG() -> some View {
        shadow(color: Color.shineInk.opacity(0.14), radius: 30, x: 0, y: 24)
    }
}
