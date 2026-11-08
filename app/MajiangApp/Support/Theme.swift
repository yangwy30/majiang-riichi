import MajiangKit
import SwiftUI
import UIKit

/// 视觉「胡桃木牌桌」：暖白的页面上放一张胡桃木框的绿毡牌桌，风位用真的风牌，供托用真的千点棒。
/// 页面颜色在 Assets.xcassets 的 Table*，各有深色版本；牌桌、木框、牌是实物颜色，深浅模式一样。
/// 红色只用在两处：庄家和立直棒上的红点。赢的点数用毡绿，输的用墨色。
/// 文字用 `ink`，按钮底色用 `fill`（毡绿，上面放白字）：`ink` 在深色模式是浅色，不能拿来垫白字。
enum Theme {
    static let paper = Color("TablePaper")
    /// 卡片底：浅色模式是白，不加边框阴影。
    static let card = Color("TableCard")
    static let line = Color("TableLine")
    /// 卡片里面的分隔线。
    static let lineSoft = Color("TableLineSoft")
    static let gray = Color("TableGray")
    static let faint = Color("TableFaint")
    static let ink = Color("TableInk")
    static let fill = Color("TableFill")
    /// 唯一的强调色：庄家、立直棒的红点。
    static let red = Color("TableRed")
    static let positive = Color("TablePositive")
    static let segment = Color("TableSegment")
    /// 拍照页的底色，深浅模式一样。
    static let darkroom = Color(hex: 0x0F1311)
    /// 卡片、选项的圆角；按钮是胶囊形。
    static let radius: CGFloat = 16

    /// 页面内容最宽多少（含两边 24 的留白）。iPhone Duo 内屏有 669 点宽、横过来 951 点，
    /// 字和按钮不铺满，收在中间一栏，跟在普通 iPhone 上看到的比例差不多。窄屏上不起作用。
    static let columnWidth: CGFloat = 560

    // 牌桌：绿毡、胡桃木框。
    static let felt = [Color(hex: 0x2E7353), Color(hex: 0x215A40), Color(hex: 0x1A4733)]
    static let walnut = [Color(hex: 0x8A5836), Color(hex: 0x5E3820), Color(hex: 0x4A2B18)]

    // 牌面：象牙白牌面、黄色牌背，深色模式也不变。
    static let tileFace = Color(hex: 0xF9F6EC)
    static let tileDim = Color(hex: 0xE9E5DA)
    static let tileEdge = Color(hex: 0xE4DFD2)
    static let tileShadow = Color(hex: 0xE7A33A)
    static let tileBack = Color(hex: 0xE7A33A)
    static let tileBackDeep = Color(hex: 0xC9852A)
    static let tileInk = Color(hex: 0x1B1F1D)
    static let tileBlue = Color(hex: 0x23406B)
    static let tileGreen = Color(hex: 0x2F5D46)
    static let tileRed = Color(hex: 0xC8402A)

    static func scoreColor(_ value: Int) -> Color { value > 0 ? positive : ink }

    /// 「+12,000」「−7,600」「0」。负号用真正的减号，和加号一样宽。
    static func signed(_ value: Int) -> String {
        value > 0 ? "+\(grouped(value))" : value < 0 ? "−\(grouped(-value))" : "0"
    }

    /// 风牌上的字：不管什么语言都写传统的「東南西北」，跟桌上的真牌一样。
    static func tileGlyph(_ wind: Wind) -> String {
        ["東", "南", "西", "北"][wind.rawValue]
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

    /// 点数、翻、符：系统字体，等宽数字。
    static func score(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    /// 风位、局顺、翻这些单字：系统字体加粗。
    static func glyph(_ size: CGFloat, semibold: Bool = false) -> Font {
        .system(size: size, weight: semibold ? .semibold : .bold)
    }

    /// 页面标题。
    static func heading(_ text: String, size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }
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

    /// 卡片：白底圆角，不加边框。
    func block(radius: CGFloat = Theme.radius) -> some View {
        self
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
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

/// 每页唯一的主按钮：毡绿胶囊。不能点时变成灰底，按钮上直接写原因。
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule()
        return configuration.label
            .font(.system(size: isEnabled ? 17 : 16, weight: isEnabled ? .semibold : .medium))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(isEnabled ? Color.white : Theme.gray)
            .background(isEnabled ? Theme.fill.opacity(configuration.isPressed ? 0.82 : 1) : Theme.segment, in: shape)
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

/// 红色印章「庄」（日文为「親」，英文为「D」）。
struct DealerStamp: View {
    var size: CGFloat = 22

    var body: some View {
        Seal(text: tr("庄", "親", "D"), size: size)
            .accessibilityLabel(tr("庄家", "親", "Dealer"))
    }
}

/// 小方印，一个字：红色的「庄」，核对页和的那张牌下面墨色的「和」。
struct Seal: View {
    var text: String
    var size: CGFloat = 22
    var color: Color = Theme.red

    var body: some View {
        Text(text)
            .font(Theme.glyph(size * 0.6))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
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
                .fill(Theme.red)
                .frame(width: height * 0.64, height: height * 0.64)
        }
        .accessibilityHidden(true)
    }
}

/// 满贯 / 跳满 / 倍满 / 三倍满 / 役满 的描边标签。毡面上用白色。
struct LimitStamp: View {
    var text: String
    var size: CGFloat = 15
    var color: Color = Theme.ink

    var body: some View {
        Text(text)
            .font(Theme.glyph(size, semibold: true))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(color.opacity(0.55), lineWidth: 1)
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
                .font(Theme.heading(title, size: 30))
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

/// 选人的胶囊：选中毡绿底白字，没选卡片底细线。
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
                .background(selected ? Theme.fill : Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.line))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 一排等宽的选项：选中毡绿底白字，没选卡片底细线。名字长了缩小，不折行。
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
                .background(selected ? Theme.fill : Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.line))
                .contentShape(Capsule())
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

/// 一张风牌：象牙白牌面写风位，底下露一截黄色牌背。庄家那张描红边。
struct WindTile: View {
    var text: String
    var isDealer = false
    var width: CGFloat = 24

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: width * 0.2, style: .continuous)
        Text(text)
            .font(.system(size: width * 0.6, weight: .bold))
            .foregroundStyle(isDealer ? Theme.tileRed : Theme.tileInk)
            .minimumScaleFactor(0.5)
            .frame(width: width, height: width * 1.3 * 0.78)
            .frame(width: width, height: width * 1.3, alignment: .top)
            .background(
                LinearGradient(stops: [.init(color: Theme.tileFace, location: 0.78), .init(color: Theme.tileBack, location: 0.78)],
                               startPoint: .top, endPoint: .bottom),
                in: shape)
            .overlay { if isDealer { shape.strokeBorder(Theme.tileRed, lineWidth: 2) } }
            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
            .accessibilityLabel(isDealer ? text + tr("，庄家", "、親", ", dealer") : text)
    }
}

extension View {
    /// 拍照页上的玻璃圆按钮。
    @ViewBuilder
    func glassCircle() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: Circle())
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }

    /// Liquid Glass 胶囊：iOS 26 起用系统的玻璃，之前的系统用毛玻璃。
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }
}
