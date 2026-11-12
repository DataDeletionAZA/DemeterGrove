import SwiftUI
import AppKit
import Observation

@Observable final class ThemeAppearance {
    static let shared = ThemeAppearance()
    var theme: AppTheme = .original
    var colors: ThemeColors { ThemeColors(theme) }
}

struct ThemeColors {
    var paper: Color
    var card: Color
    var control: Color
    var gold: Color
    var goldLight: Color
    var lavender: Color
    var sage: Color
    var moss: Color
    var ink: Color
    var muted: Color
    var clay: Color
    var line: Color

    init(_ theme: AppTheme) {
        func c(_ hex: UInt32, _ opacity: Double = 1) -> Color {
            Color(.sRGB, red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255,
                  blue: Double(hex & 255)/255, opacity: opacity)
        }
        switch theme {
        case .original:
            paper = Color(red:0.10,green:0.085,blue:0.14); card = Color(red:0.17,green:0.14,blue:0.21)
            control = Color(red:0.23,green:0.19,blue:0.28); gold = Color(red:0.69,green:0.57,blue:0.36)
            goldLight = Color(red:0.91,green:0.82,blue:0.62); lavender = Color(red:0.58,green:0.49,blue:0.65)
            sage = Color(red:0.65,green:0.72,blue:0.54); moss = Color(red:0.31,green:0.24,blue:0.36)
            ink = Color(red:0.91,green:0.87,blue:0.77); muted = Color(red:0.66,green:0.61,blue:0.58)
            clay = Color(red:0.74,green:0.49,blue:0.43); line = Color(red:0.37,green:0.30,blue:0.37)
        case .y2k:
            paper=c(0xDCE1EA); card=c(0xF4F6FA); control=c(0xC9D1DD); gold=c(0x295299)
            goldLight=c(0x173D74); lavender=c(0x6B409B); sage=c(0x2B6D67); moss=c(0xB7CEE9)
            ink=c(0x15233E); muted=c(0x52617A); clay=c(0xA02F67); line=c(0x8994AB)
        case .liquidGlass:
            paper=c(0xF2F2F7,0.48); card=c(0xFFFFFF,0.78); control=c(0xFFFFFF,0.72); gold=c(0x0064D2)
            goldLight=c(0x0054B1); lavender=c(0x7153AD); sage=c(0x24794D); moss=c(0xD6E8FC,0.8)
            ink=c(0x202124); muted=c(0x60636B); clay=c(0xAF3936); line=c(0x8E8E93,0.24)
        case .christmas:
            paper=c(0xF0E7D4); card=c(0xFFFAED); control=c(0xE8DCC1); gold=c(0x8B6533)
            goldLight=c(0x842F3D); lavender=c(0x8D6871); sage=c(0x37664B); moss=c(0xE5C9BC)
            ink=c(0x293C33); muted=c(0x6C6B57); clay=c(0xA13C40); line=c(0xC5B38C)
        }
    }
}

enum Palette {
    static var paper: Color { ThemeAppearance.shared.colors.paper }
    static var card: Color { ThemeAppearance.shared.colors.card }
    static var control: Color { ThemeAppearance.shared.colors.control }
    static var gold: Color { ThemeAppearance.shared.colors.gold }
    static var goldLight: Color { ThemeAppearance.shared.colors.goldLight }
    static var lavender: Color { ThemeAppearance.shared.colors.lavender }
    static var sage: Color { ThemeAppearance.shared.colors.sage }
    static var moss: Color { ThemeAppearance.shared.colors.moss }
    static var ink: Color { ThemeAppearance.shared.colors.ink }
    static var muted: Color { ThemeAppearance.shared.colors.muted }
    static var clay: Color { ThemeAppearance.shared.colors.clay }
    static var line: Color { ThemeAppearance.shared.colors.line }
}
