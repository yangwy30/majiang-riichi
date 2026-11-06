import Foundation

/// App 支持的三种语言：简体中文、日文、英文。
public enum AppLang: String, CaseIterable, Codable, Sendable {
    case zh = "zh-Hans"
    case ja = "ja"
    case en = "en"

    public var displayName: String {
        switch self {
        case .zh: return "中文"
        case .ja: return "日本語"
        case .en: return "English"
        }
    }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }

    /// 当前生效的语言：优先读用户在 App 内手动选的语言，否则跟随系统语言（单元测试环境下固定为中文）。
    public static var current: AppLang {
        if NSClassFromString("XCTestCase") != nil {
            return .zh
        }
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLang(rawValue: saved) {
            return lang
        }
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "zh"
        if preferred.hasPrefix("ja") { return .ja }
        if preferred.hasPrefix("zh") { return .zh }
        return .en
    }
}

/// 三语内联翻译辅助函数（按 中文 / 日文 / 英文 返回当前语言文本）。
public func tr(_ zh: String, _ ja: String, _ en: String) -> String {
    switch AppLang.current {
    case .zh: return zh
    case .ja: return ja
    case .en: return en
    }
}
