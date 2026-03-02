import Foundation

struct AppSettings: Codable, Equatable {
    var launchAtLogin: Bool
    var hotkeyPreset: HotkeyPreset
    var themeMode: ThemeMode
    var maxItemCount: Int
    var maxRetentionDays: Int
    var ignoreConsecutiveDuplicates: Bool
    var ignoreWhitespaceText: Bool

    static let `default` = AppSettings(
        launchAtLogin: false,
        hotkeyPreset: .commandSemicolon,
        themeMode: .followSystem,
        maxItemCount: 300,
        maxRetentionDays: 30,
        ignoreConsecutiveDuplicates: true,
        ignoreWhitespaceText: true
    )

    enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case hotkeyPreset
        case themeMode
        case maxItemCount
        case maxRetentionDays
        case ignoreConsecutiveDuplicates
        case ignoreWhitespaceText
    }

    init(
        launchAtLogin: Bool,
        hotkeyPreset: HotkeyPreset,
        themeMode: ThemeMode,
        maxItemCount: Int,
        maxRetentionDays: Int,
        ignoreConsecutiveDuplicates: Bool,
        ignoreWhitespaceText: Bool
    ) {
        self.launchAtLogin = launchAtLogin
        self.hotkeyPreset = hotkeyPreset
        self.themeMode = themeMode
        self.maxItemCount = maxItemCount
        self.maxRetentionDays = maxRetentionDays
        self.ignoreConsecutiveDuplicates = ignoreConsecutiveDuplicates
        self.ignoreWhitespaceText = ignoreWhitespaceText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        hotkeyPreset = try container.decodeIfPresent(HotkeyPreset.self, forKey: .hotkeyPreset) ?? .commandSemicolon
        themeMode = try container.decode(ThemeMode.self, forKey: .themeMode)
        maxItemCount = try container.decode(Int.self, forKey: .maxItemCount)
        maxRetentionDays = try container.decode(Int.self, forKey: .maxRetentionDays)
        ignoreConsecutiveDuplicates = try container.decode(Bool.self, forKey: .ignoreConsecutiveDuplicates)
        ignoreWhitespaceText = try container.decode(Bool.self, forKey: .ignoreWhitespaceText)
    }
}
