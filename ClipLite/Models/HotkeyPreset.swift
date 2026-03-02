import Carbon
import Foundation

enum HotkeyPreset: String, CaseIterable, Codable, Identifiable {
    case commandSemicolon
    case commandShiftV
    case commandOptionSpace

    var id: String { rawValue }

    var keyCode: UInt32 {
        switch self {
        case .commandSemicolon:
            return UInt32(kVK_ANSI_Semicolon)
        case .commandShiftV:
            return UInt32(kVK_ANSI_V)
        case .commandOptionSpace:
            return UInt32(kVK_Space)
        }
    }

    var modifiers: UInt32 {
        switch self {
        case .commandSemicolon:
            return UInt32(cmdKey)
        case .commandShiftV:
            return UInt32(cmdKey | shiftKey)
        case .commandOptionSpace:
            return UInt32(cmdKey | optionKey)
        }
    }

    var displayName: String {
        switch self {
        case .commandSemicolon:
            return "Command + ;"
        case .commandShiftV:
            return "Command + Shift + V"
        case .commandOptionSpace:
            return "Command + Option + Space"
        }
    }
}
