import SwiftUI
import PhotosUI
import MajiangKit

/// 拍照：整页就是取景器。下方一根胡桃木牌架，提示把 14 张牌摆在上面；快门是一张象牙白的牌。
/// 谁和了、怎么和的不在这里选，拍完到核对页的小牌桌上点座位。
struct CaptureView: View {
    @Environment(AppModel.self) private var model
    @Bindable var flow: RoundFlow
    var close: () -> Void

    @State private var camera = CameraController()
    @State private var cameraOn = false
    @State private var choosingPhoto = false
    @State private var pickerItem: PhotosPickerItem?
    /// 端侧模型零点几秒就认完了，转圈晚一点出来，免得一闪而过。
    @State private var slow = false
    @State private var autoShot = false
    /// 按一次快门加一，触发一下轻震。
    @State private var shots = 0

    var body: some View {
        ZStack {
            viewfinder.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                if flow.photo == nil { rackGuide }
                Spacer(minLength: 0)
                // 邀请码不在这里提：拍照时只管拍。离线认牌这手要改牌时，核对页再说一句
                Text(status ?? " ")
                    .font(.system(size: 14))
                    .foregroundStyle(flow.recognitionError == nil ? Color.white.opacity(0.8) : Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(minHeight: 34)
                    .padding(.horizontal, 24)
                controls
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            // iPhone Duo 内屏、横过来时不铺满：快门和两边的按钮不至于隔得太远
            .frame(maxWidth: 560)

            if flow.isRecognizing && slow {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                    .frame(width: 80, height: 80)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .foregroundStyle(.white)
        .background(Theme.darkroom.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .photosPicker(isPresented: $choosingPhoto, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    use(image)
                }
                pickerItem = nil
            }
        }
        // 核对页盖在上面时拍照页还在下面（定格的照片露在后面），相机先关掉
        .task(id: flow.steps.isEmpty) {
            guard flow.steps.isEmpty else {
                camera.stop()
                return
            }
            // 从核对页退回来时，照片清掉、还在跑的复核不要了，重新取景
            flow.cancelRecognition()
            flow.photo = nil
            cameraOn = await camera.start()
            await model.preloadOnDeviceModel()
            #if DEBUG
            // 截图用：`-demo-screen capture -auto-shoot` 进拍照页 1.5 秒后自动拍一张（演示数据），看核对页出来
            if model.demoScreen == .capture && ProcessInfo.processInfo.arguments.contains("-auto-shoot") && !autoShot {
                autoShot = true
                try? await Task.sleep(for: .seconds(1.5))
                use(UIImage(systemName: "photo") ?? UIImage())
            }
            #endif
        }
        .onDisappear { camera.stop() }
        .sensoryFeedback(.impact(weight: .medium), trigger: shots)
        .task(id: flow.isRecognizing) {
            slow = false
            guard flow.isRecognizing else { return }
            try? await Task.sleep(for: .seconds(0.6))
            if !Task.isCancelled { withAnimation(.easeIn(duration: 0.2)) { slow = true } }
        }
    }

    private var status: String? {
        if flow.isRecognizing { return slow ? tr("正在认牌…", "牌を読み取り中…", "Recognizing tiles…") : nil }
        return flow.recognitionError
    }

    /// 顶上：左边一个玻璃圆的关闭，中间一行标题。
    private var topBar: some View {
        ZStack {
            Text(tr("拍和了的牌", "和了の手牌を撮影", "Snap the winning hand"))
                .font(.system(size: 16, weight: .semibold))
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .glassCircle()
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("取消", "キャンセル", "Cancel"))
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var viewfinder: some View {
        ZStack {
            if let photo = flow.photo {
                Color.clear.overlay {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
            } else if cameraOn {
                CameraPreview(camera: camera)
            } else {
                // 没有相机（模拟器）或没给权限：一片暗绿，像对着桌面
                RadialGradient(colors: [Color(hex: 0x4F6B5E), Color(hex: 0x2B3A33), Color(hex: 0x151C18)],
                               center: UnitPoint(x: 0.5, y: 0.55), startRadius: 0, endRadius: 420)
            }
        }
    }

    /// 取景提示：一句话、一排示意牌立在胡桃木牌架上，两头标着 1 和 14。
    private var rackGuide: some View {
        VStack(spacing: 14) {
            Text(cameraOn || model.effectiveRecognitionMode == .demo || model.demoScreen != nil
                 ? tr("把 14 张牌摆在牌架上，和的那张放最右", "14枚を牌架に並べ、和了牌を一番右に", "Line up all 14 tiles on the rack, winning tile on the right")
                 : tr("这台设备没有相机，从左下角的相册选一张", "カメラがありません。左下のアルバムから選んでください", "No camera here. Pick a photo from the album"))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            VStack(spacing: 0) {
                ViewThatFits(in: .horizontal) {
                    sampleHand(tileWidth: 20)
                    sampleHand(tileWidth: 16)
                }
                .opacity(0.6)
                RackBar()
                    .frame(height: 16)
                    .padding(.top, -3)
                HStack {
                    Text("1")
                    Spacer()
                    Text("14")
                }
                .font(Theme.score(10, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 6)
                .padding(.top, 6)
            }
            .padding(.horizontal, 12)
        }
        .accessibilityElement(children: .combine)
    }

    private func sampleHand(tileWidth: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(Array(Tile.parseList("1112233445566p").enumerated()), id: \.offset) { _, tile in
                TileFace(tile: tile, width: tileWidth, state: .dim)
            }
            Color.clear.frame(width: tileWidth * 0.45, height: 1)
            TileFace(tile: Tile(suit: .dots, rank: 7)!, width: tileWidth, state: .dim)
        }
    }

    /// 左边相册、中间一张牌形的快门、右边手动输入。
    private var controls: some View {
        HStack {
            Button {
                choosingPhoto = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 19))
                    .frame(width: 54, height: 54)
                    .glassCircle()
                    .contentShape(Circle())
            }
            .accessibilityLabel(tr("从相册选", "アルバムから選ぶ", "Choose from album"))
            Spacer()
            Button(action: shoot) {
                TileShutter()
            }
            .accessibilityLabel(tr("拍照", "撮影", "Take photo"))
            Spacer()
            Button { flow.startManualEntry() } label: {
                Image(systemName: "square.grid.3x3")
                    .font(.system(size: 19))
                    .frame(width: 54, height: 54)
                    .glassCircle()
                    .contentShape(Circle())
            }
            .accessibilityLabel(tr("手动输入", "手入力", "Enter manually"))
        }
        .buttonStyle(PressFade())
        .padding(.horizontal, 28)
        .disabled(flow.isRecognizing)
        .opacity(flow.isRecognizing ? 0.4 : 1)
    }

    private func shoot() {
        shots += 1
        if cameraOn {
            Task {
                if let image = await camera.capture() { use(image) }
            }
        } else if model.effectiveRecognitionMode == .demo {
            // 演示识别不看照片，模拟器里也能走完流程
            use(UIImage(systemName: "photo") ?? UIImage())
        } else {
            choosingPhoto = true
        }
    }

    private func use(_ image: UIImage) {
        flow.photo = image.downscaled()
        Task {
            await flow.recognize(with: model.makeRecognizer())
            // 认不出来时回到取景，让人重拍
            if flow.recognitionError != nil { flow.photo = nil }
        }
    }
}

/// 胡桃木牌架：一根横条，上亮下暗。
private struct RackBar: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(LinearGradient(colors: Theme.walnut, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.25), .clear, .black.opacity(0.25)], startPoint: .top, endPoint: .bottom))
            )
            .shadow(color: .black.opacity(0.45), radius: 9, y: 8)
    }
}

/// 快门：一张竖着的象牙白牌，底下露黄色牌背，牌面上一个相机。
private struct TileShutter: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Image(systemName: "camera")
            .font(.system(size: 26, weight: .medium))
            .foregroundStyle(Theme.tileInk)
            .frame(width: 70, height: 74)
            .frame(width: 70, height: 92, alignment: .top)
            .background(
                LinearGradient(stops: [.init(color: Theme.tileFace, location: 0.8), .init(color: Theme.tileBack, location: 0.8)],
                               startPoint: .top, endPoint: .bottom),
                in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 4).padding(-4))
            .shadow(color: .black.opacity(0.4), radius: 10, y: 8)
            .contentShape(shape)
    }
}
