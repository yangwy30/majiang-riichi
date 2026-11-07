import CoreText
import MajiangKit
import SwiftUI
import UIKit

/// 视觉「和纸与藍」：和纸底、藍色主操作、朱红只用于立直棒和赢点。颜色都在 Assets.xcassets 的 Washi* 里，各有深色版本。
/// 文字用 `ink`，填充用 `indigo`（上面放白字）：`ink` 在深色模式是浅色，不能拿来垫白字。
enum Theme {
    static let paper = Color("WashiPaper")
    /// 卡片底：浅一档的和纸，配细线边框，不用阴影。
    static let card = Color("WashiCard")
    static let line = Color("WashiLine")
    /// 卡片里面的分隔线。
    static let lineSoft = Color("WashiLineSoft")
    static let gray = Color("WashiGray")
    static let faint = Color("WashiFaint")
    static let ink = Color("WashiInk")
    static let indigo = Color("WashiIndigo")
    static let vermilion = Color("WashiVermilion")
    static let segment = Color("WashiSegment")
    /// 拍照页的底色，深浅模式一样。
    static let darkroom = Color(hex: 0x0F151E)
    /// 卡片、按钮、选项的圆角。
    static let radius: CGFloat = 12

    /// 页面内容最宽多少（含两边 24 的留白）。iPhone Duo 内屏有 669 点宽、横过来 951 点，
    /// 字和按钮不铺满，收在中间一栏，跟在普通 iPhone 上看到的比例差不多。窄屏上不起作用。
    static let columnWidth: CGFloat = 560

    // 牌面：实物颜色，深色模式也不变。牌背是藍色，底边露一点。
    static let tileFace = Color(hex: 0xFFFDF8)
    static let tileDim = Color(hex: 0xE9E5DA)
    static let tileEdge = Color(hex: 0xE4DFD2)
    static let tileShadow = Color(hex: 0x23395B)
    static let tileBack = Color(hex: 0x23395B)
    static let tileBackDeep = Color(hex: 0x1A2C48)
    static let tileInk = Color(hex: 0x1C2A40)
    static let tileBlue = Color(hex: 0x23406B)
    static let tileGreen = Color(hex: 0x2F5D46)
    static let tileRed = Color(hex: 0xC8402A)

    static func scoreColor(_ value: Int) -> Color { value > 0 ? vermilion : ink }

    /// 「+12,000」「−7,600」「0」。负号用真正的减号，和加号一样宽。
    static func signed(_ value: Int) -> String {
        value > 0 ? "+\(grouped(value))" : value < 0 ? "−\(grouped(-value))" : "0"
    }

    /// 风位一个字：英文只写首字母（E、S、W、N），窄的地方放不下四个字母。
    static func windGlyph(_ name: String) -> String {
        AppLang.current == .en ? String(name.prefix(1)) : name
    }

    /// 「25,000」。不跟地区走，三种语言都是逗号。
    static func grouped(_ value: Int) -> String {
        var digits = String(abs(value))
        var parts: [String] = []
        while digits.count > 3 {
            parts.insert(String(digits.suffix(3)), at: 0)
            digits.removeLast(3)
        }
        parts.insert(digits, at: 0)
        return (value < 0 ? "−" : "") + parts.joined(separator: ",")
    }

    /// 点数、翻、符：圆体，等宽数字。
    static func score(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    /// 明朝体，用于标题、风位、局顺、翻。日文用系统的 Hiragino Mincho，英文用系统衬线；
    /// 中文先用打包的 Noto Serif SC 子集（SIL OFL，见 Resources/Fonts），子集里没有的字由 Hiragino Mincho 补。
    static func serif(_ size: CGFloat, semibold: Bool = false) -> Font {
        if AppLang.current == .ja {
            return .custom("HiraMinProN-W6", fixedSize: size)
        }
        if AppLang.current == .en {
            return .system(size: size, weight: semibold ? .semibold : .bold, design: .serif)
        }
        if let name = semibold ? serifFonts.semibold : serifFonts.bold, let base = UIFont(name: name, size: size) {
            let fallback = UIFontDescriptor(name: "HiraMinProN-W6", size: size)
            let descriptor = base.fontDescriptor.addingAttributes([.cascadeList: [fallback]])
            return Font(UIFont(descriptor: descriptor, size: size))
        }
        return .system(size: size, weight: semibold ? .semibold : .bold, design: .serif)
    }

    /// 一整句标题用的字体。中文里有明朝体都没有的简体字（比如「谁」）时，整句换成系统黑体，免得一句话里两种字体。
    static func heading(_ text: String, size: CGFloat) -> Font {
        if AppLang.current == .zh && !text.unicodeScalars.allSatisfy(serifCoverage.contains) {
            return .system(size: size, weight: .semibold)
        }
        return serif(size, semibold: true)
    }

    private static let serifCoverage: CharacterSet = {
        _ = serifFonts
        var set = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols)
        for name in ["NotoSerifSC-SemiBold", "HiraMinProN-W6"] {
            if let font = UIFont(name: name, size: 12) {
                set.formUnion(CTFontCopyCharacterSet(font as CTFont) as CharacterSet)
            }
        }
        return set
    }()

    private static let serifFonts: (bold: String?, semibold: String?) = {
        func register(_ file: String, name: String) -> String? {
            if let url = Bundle.main.url(forResource: file, withExtension: "otf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
            return UIFont(name: name, size: 12) != nil ? name : nil
        }
        return (register("NotoSerifSC-Bold-subset", name: "NotoSerifSC-Bold"),
                register("NotoSerifSC-SemiBold-subset", name: "NotoSerifSC-SemiBold"))
    }()
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - 通用组件

extension View {
    /// 纸白底的页面。页面宽过 `Theme.columnWidth` 时（iPhone Duo 内屏），滚动内容收在中间一栏，
    /// 两边空白仍然能滑动。
    func page() -> some View {
        self
            .modifier(ReadableColumn())
            .scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
    }

    /// 卡片：浅和纸底加一圈细线，不用阴影。
    func block(radius: CGFloat = Theme.radius) -> some View {
        self
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.line, lineWidth: 0.5))
    }

    /// 页面底部固定的按钮区，底下垫一层纸色，免得滚动内容透出来。
    func bottomBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        safeAreaInset(edge: .bottom) {
            VStack(spacing: 4, content: content)
                .frame(maxWidth: Theme.columnWidth - 48)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Theme.paper)
        }
    }
}

/// 宽屏上给滚动内容两边加空白，让内容停在中间一栏。用整页的宽度算，不用屏幕宽度（Duo 分屏时窗口比屏幕窄）。
private struct ReadableColumn: ViewModifier {
    @State private var margin: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { proxy in
                max(0, ((proxy.size.width - Theme.columnWidth) / 2).rounded())
            } action: { margin = $0 }
    }
}

/// 每页唯一的藍色主按钮。不能点时变成灰底，按钮上直接写原因。
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
        return configuration.label
            .font(.system(size: isEnabled ? 17 : 16, weight: isEnabled ? .semibold : .medium))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(isEnabled ? Color.white : Theme.gray)
            .background(isEnabled ? Theme.indigo.opacity(configuration.isPressed ? 0.82 : 1) : Theme.segment, in: shape)
            .contentShape(shape)
    }
}

/// 其余操作都是文字按钮，没有描边按钮。
struct TextButtonStyle: ButtonStyle {
    var color: Color = Theme.gray
    var size: CGFloat = 15

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size))
            .foregroundStyle(color)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == TextButtonStyle {
    static var text: TextButtonStyle { TextButtonStyle() }
    static func text(_ color: Color = Theme.gray, size: CGFloat = 15) -> TextButtonStyle {
        TextButtonStyle(color: color, size: size)
    }
}

// MARK: - 顶部按钮

/// 顶部按钮的规矩：左上是回去或关掉（推进来的页写「‹ 回到哪儿」，弹出层有改动写「取消」、只是看看写「关闭」），
/// 右上只放这一页的工具，用浅一档的字。确认不放顶上，一律用页面底部的主按钮。
/// 都是直接写在纸上的字：iOS 26 起系统会给导航栏按钮包一层玻璃泡，这里关掉。
struct NavBack: ToolbarContent {
    var title: String
    var action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: action) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text(LocalizedStringKey(title))
                }
            }
            .buttonStyle(NavButtonStyle())
        }
        .withoutGlass()
    }
}

/// 弹出层左上的「取消」「关闭」。
struct NavClose: ToolbarContent {
    var title: String
    /// 拍照页是深色底，用白字。
    var color: Color
    var action: () -> Void

    init(_ title: String = "取消", color: Color = Theme.ink, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.action = action
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(LocalizedStringKey(title), action: action)
                .buttonStyle(NavButtonStyle(color: color))
        }
        .withoutGlass()
    }
}

/// 右上的工具：一个词，灰一点，免得和左上的回去抢。
struct NavTool<Label: View>: ToolbarContent {
    @ViewBuilder var label: () -> Label

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            label()
                .buttonStyle(NavButtonStyle(color: Theme.gray, size: 16))
        }
        .withoutGlass()
    }
}

struct NavButtonStyle: ButtonStyle {
    var color: Color = Theme.ink
    var size: CGFloat = 17

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size))
            .foregroundStyle(color)
            // 导航栏给的宽度很窄，不撑开的话「首页」会折成两行
            .fixedSize()
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.4 : 1)
    }
}

extension ToolbarContent {
    @ToolbarContentBuilder
    func withoutGlass() -> some ToolbarContent {
        if #available(iOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

/// 朱红印章「庄」（日文为「親」，英文为「D」）。
struct DealerStamp: View {
    var size: CGFloat = 22

    var body: some View {
        Seal(text: tr("庄", "親", "D"), size: size)
            .accessibilityLabel(tr("庄家", "親", "Dealer"))
    }
}

/// 朱红小方印，一个宋体字：「庄」，核对页和的那张牌下面的「和」（跟 App 图标一个样子）。
struct Seal: View {
    var text: String
    var size: CGFloat = 22

    var body: some View {
        Text(text)
            .font(Theme.serif(size * 0.6))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.vermilion, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}

/// 千点立直棒小图标：白底细长圆角棒 + 中央朱红圆点（—•—）。
struct RiichiStickIcon: View {
    var width: CGFloat = 34
    var height: CGFloat = 7
    var borderColor: Color = Theme.line

    var body: some View {
        ZStack {
            Capsule()
                .fill(Theme.tileFace)
                .frame(width: width, height: height)
                .overlay(Capsule().strokeBorder(borderColor, lineWidth: 0.8))
            Circle()
                .fill(Theme.vermilion)
                .frame(width: height * 0.64, height: height * 0.64)
        }
        .accessibilityHidden(true)
    }
}

/// 满贯 / 跳满 / 倍满 / 三倍满 / 役满 的朱红方框印章标签。
struct LimitStamp: View {
    var text: String
    var size: CGFloat = 15

    var body: some View {
        Text(text)
            .font(Theme.serif(size, semibold: true))
            .foregroundStyle(Theme.vermilion)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.vermilion.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Theme.vermilion.opacity(0.45), lineWidth: 1)
            )
    }
}

/// 灰色小节标题，比如「账本」「常一起打的」。
struct SectionLabel: View {
    var text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(LocalizedStringKey(text))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 页面大标题和一行灰色说明。
struct PageTitle: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(Theme.heading(title, size: 28))
            if let subtitle {
                Text(LocalizedStringKey(subtitle))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 几段的切换：选中的一段是卡片色，带细线。
struct SegmentedSwitch<Value: Hashable>: View {
    var options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, label in
                let on = value == selection
                Button {
                    selection = value
                } label: {
                    Text(LocalizedStringKey(label))
                        .font(.system(size: 15, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? Theme.ink : Theme.gray)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.card)
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line, lineWidth: 0.5))
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.segment, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}

/// 选人的小方块：选中藍底白字，没选卡片底细线。
struct NameChip: View {
    var name: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 15))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minHeight: 36)
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .background(selected ? Theme.indigo : Theme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(selected ? Color.clear : Theme.line))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 一排等宽的选项（核对页的谁和了、怎么和的）：选中藍底白字，没选卡片底细线。名字长了缩小，不折行。
struct ChoiceChip: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 15, weight: selected ? .medium : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .background(selected ? Theme.indigo : Theme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(selected ? Color.clear : Theme.line))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 细线。
struct Hairline: View {
    var color: Color = Theme.line

    var body: some View {
        Rectangle().fill(color).frame(height: 0.5)
    }
}
