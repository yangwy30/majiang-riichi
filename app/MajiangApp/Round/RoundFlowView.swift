import SwiftUI
import MajiangKit

/// 记一局：全屏弹出，拍照 → 核对 → 结果。记下或关掉后回到牌桌。
struct RoundFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow: RoundFlow
    /// 状态栏跟着谁在最上面：核对页升到顶以后才换成深色字，不然升的半路上是黑底黑字。
    @State private var lightBars = false
    /// 系统现在是浅色还是深色（从牌桌传进来）：拍照页永远深色，核对页跟系统。
    var colorScheme: ColorScheme
    /// 记下的结果，和拍的那张照片（手动输入的没有）。
    var onFinish: (HandOutcome, UIImage?) -> Void

    init(game: Game, demo: DemoScreen? = nil, colorScheme: ColorScheme, onFinish: @escaping (HandOutcome, UIImage?) -> Void) {
        let flow = RoundFlow(game: game)
        #if DEBUG
        if let demo { DemoData.prepare(flow, for: demo) }
        #endif
        _flow = State(initialValue: flow)
        _lightBars = State(initialValue: !flow.steps.isEmpty)
        self.colorScheme = colorScheme
        self.onFinish = onFinish
    }

    private var checking: Bool { !flow.steps.isEmpty }

    var body: some View {
        // 核对页不是推进来的：拍完照片定格、变暗，核对页淡进来，牌从左往右一张张摆上绿毡
        ZStack {
            NavigationStack {
                CaptureView(flow: flow) { dismiss() }
            }
            .opacity(checking ? 0.25 : 1)
            .blur(radius: checking ? 8 : 0)
            .allowsHitTesting(!checking)

            if checking {
                NavigationStack {
                    CheckView(flow: flow, finish: finish)
                }
                // 升上来的半路上整层还是深色，核对页先按系统的颜色画
                .environment(\.colorScheme, colorScheme)
                .transition(.opacity.combined(with: .scale(scale: 1.03)))
                .zIndex(1)
            }
        }
        // 拍照页被圆角裁过，边上的安全区（iPhone Duo 外屏右边竖着的状态栏、底部横条）露的是这层底色：
        // 平时跟拍照页同色，免得有一道接缝；核对页升上来时才换成纯黑，衬出往后退的拍照页
        .background((checking ? Color.black : Theme.darkroom).ignoresSafeArea())
        .animation(.easeOut(duration: 0.35), value: checking)
        .tint(Theme.ink)
        // 拍照页是深色底，状态栏要白字；导航栏的 toolbarColorScheme 管不到整个全屏弹层
        .preferredColorScheme(lightBars ? colorScheme : .dark)
        .task(id: checking) {
            guard checking else {
                lightBars = false
                return
            }
            if lightBars { return }
            try? await Task.sleep(for: .seconds(0.45))
            if !Task.isCancelled { lightBars = true }
        }
    }

    private func finish(_ outcome: HandOutcome) {
        flow.showResult = false
        onFinish(outcome, flow.photo)
        dismiss()
    }
}
