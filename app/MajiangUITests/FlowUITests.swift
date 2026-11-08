import XCTest

/// 从开一局到结算，按真人的点法走一遍：开局、拍照（演示识别）、核对、宝牌、结果、记下、流局、特殊流局、错和、撤销、改局、
/// 这一局、发到群、结束、结算和记录。每一步截一张图，放到环境变量 SCREENSHOT_DIR 指的目录（不设就不存）。
/// 跑之前先把 App 删掉，保证是第一次打开（`xcrun simctl uninstall booted com.yangwy30.majiang.riichi`）。
final class FlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private var step = 0

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-ui-test-reset"]
    }

    // MARK: 工具

    /// 每个测试一个子目录：SCREENSHOT_DIR/<测试名>/。
    private var shotDir: String? {
        guard let root = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return nil }
        let test = name.components(separatedBy: " ").last?.trimmingCharacters(in: CharacterSet(charactersIn: "]")) ?? "test"
        return root + "/" + test
    }

    /// 截一张图：编号-名字.png。
    private func shot(_ name: String) {
        step += 1
        guard let dir = shotDir else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent(String(format: "%02d-%@.png", step, name)))
    }

    /// 找不到东西时把整棵无障碍树存下来，方便看是哪里不对。
    private func dump(_ name: String) {
        guard let dir = shotDir else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.debugDescription.write(toFile: dir + "/fail-\(name).txt", atomically: true, encoding: .utf8)
        shot("fail-\(name)")
    }

    @discardableResult
    private func wait(_ element: XCUIElement, _ name: String, timeout: TimeInterval = 10) -> XCUIElement {
        if !element.waitForExistence(timeout: timeout) {
            dump(name)
            XCTFail("找不到：\(name)")
        }
        return element
    }

    private func button(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func text(containing text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// 积分栏左边的「N 翻 N 符」。
    private var hanFu: String {
        app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+ 翻 [0-9]+ 符$")).firstMatch.label
    }

    // MARK: 整个流程

    func testWholeGame() throws {
        let launched = Date()
        app.launch()

        // 1. 空桌 → 开一局
        wait(app.buttons["开一局"], "开一局", timeout: 30)
        shot("empty-table")
        app.buttons["开一局"].tap()

        let names = ["杨", "阿强", "莉莉", "小张"]
        for (field, name) in zip(["你", "下家", "对家", "上家"], names) {
            let input = wait(app.textFields[field], "名字输入框 \(field)")
            input.tap()
            input.typeText(name)
        }
        shot("new-game")
        wait(app.buttons["开始"], "开始").tap()

        // 2. 牌桌出来了（顺便量一下从打开 App 到牌桌出现用了多久）
        wait(app.buttons["有人和了"], "牌桌：有人和了", timeout: 20)
        XCTAssertTrue(text(containing: "25,000").exists, "开局四家 25,000")
        print("TIMING table visible after \(Date().timeIntervalSince(launched)) s (includes typing)")
        shot("table-start")

        // 3. 第 1 手：拍照 → 演示识别（有一张看不清、和的是哪张会影响翻符）
        app.buttons["有人和了"].tap()
        wait(app.buttons["拍照"], "快门", timeout: 15)
        shot("capture")
        app.buttons["拍照"].tap()
        wait(text(containing: "这张看不太清"), "看不清的那张", timeout: 20)
        shot("check-unclear")
        wait(button(containing: "能和"), "能和的候选").tap()

        // 和的是哪张：翻符会变，才会出现这句
        wait(text(containing: "和的是哪张"), "和的是哪张提示")
        shot("check-which-tile")
        // 先选谁和了、怎么和的，积分栏才有翻符
        wait(app.buttons["莉莉"], "小桌上的莉莉").tap()
        wait(app.buttons["自摸"], "自摸").tap()
        let before = hanFu
        // 亮着的几张一张张点过去，总有一张算出来的翻符不一样
        let candidates = app.buttons.matching(NSPredicate(format: "value == %@", "可以是和的那张"))
        XCTAssertGreaterThan(candidates.count, 0, "应该有亮着的候选牌")
        var after = before
        for i in 0..<candidates.count where after == before {
            candidates.element(boundBy: i).tap()
            after = hanFu
        }
        print("WINNING TILE han/fu before=\(before) after=\(after) candidates=\(candidates.count)")
        XCTAssertNotEqual(before, after, "换了和的那张，翻符应该变")
        shot("check-other-winning-tile")

        // 4. 立直、宝牌指示牌、里宝
        wait(button(containing: "立直"), "立直筹码").tap()
        wait(app.buttons["翻宝牌指示牌"], "宝牌牌面").tap()
        wait(text(containing: "里宝牌指示牌"), "立直后才有的里宝牌")
        app.buttons.matching(NSPredicate(format: "label == %@", "加一张指示牌")).element(boundBy: 0).tap()
        // 牌桌那排里也有 4 饼，选面板上的（最后一个）
        let fours = app.buttons.matching(NSPredicate(format: "label == %@", "4饼"))
        wait(fours.firstMatch, "选 4 饼当指示牌")
        fours.element(boundBy: fours.count - 1).tap()
        XCTAssertTrue(wait(text(containing: "宝牌"), "宝牌数").exists)
        shot("dora-sheet")
        wait(app.buttons["好"], "数宝牌：好").tap()

        // 5. 看结果 → 记下
        wait(app.buttons["看结果"], "看结果").tap()
        wait(app.buttons["记下"], "结果页：记下", timeout: 10)
        shot("result")
        app.buttons["记下"].tap()
        wait(app.buttons["有人和了"], "回到牌桌")
        XCTAssertFalse(text(containing: "25,000").exists && text(containing: "13,800").exists)
        shot("table-after-win")

        // 6. 第 2 手：混一色，带碰和暗杠；不是每手都要问和的是哪张
        app.buttons["有人和了"].tap()
        wait(app.buttons["拍照"], "快门 2").tap()
        wait(app.buttons["重拍"], "核对页 2", timeout: 20)
        shot("check-second-hand")
        print("SECOND HAND asks which tile: \(text(containing: "和的是哪张").exists)")
        wait(app.buttons["阿强"], "小桌上的阿强").tap()
        wait(app.buttons["荣和"], "荣和").tap()
        wait(app.buttons["小张"], "小桌上的小张（放铳）").tap()
        shot("check-ron")
        if app.buttons["看结果"].waitForExistence(timeout: 3) {
            app.buttons["看结果"].tap()
            wait(app.buttons["记下"], "结果页 2").tap()
        } else {
            dump("second-hand-blocked")
            app.buttons["重拍"].tap()
            app.buttons.matching(NSPredicate(format: "label == %@", "取消")).firstMatch.tap()
        }
        wait(app.buttons["有人和了"], "回到牌桌 2")
        shot("table-after-ron")

        // 7. 流局：两家听牌，一家立直
        app.buttons["流局"].tap()
        wait(app.buttons["杨"], "流局：杨").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "莉莉")).firstMatch.tap()
        wait(button(containing: "有人立直"), "有人立直").tap()
        shot("draw-sheet")
        wait(app.buttons["记下流局"], "记下流局").tap()
        wait(app.buttons["有人和了"], "流局后牌桌")
        shot("table-after-draw")

        // 8. 特殊流局（九种九牌）
        wait(app.buttons["table-menu"], "更多菜单").tap()
        wait(app.buttons["特殊流局"], "特殊流局").tap()
        wait(app.buttons["九种九牌"], "九种九牌").tap()
        shot("special-draw")
        wait(app.buttons["记下"], "特殊流局：记下").tap()
        wait(app.buttons["有人和了"], "特殊流局后牌桌")

        // 9. 错和 → 撤销
        app.buttons["table-menu"].tap()
        wait(app.buttons["有人和错了"], "有人和错了").tap()
        shot("chombo-pick")
        wait(app.buttons["小张"], "错和：小张").tap()
        wait(app.buttons["撤销"], "撤销条")
        shot("after-chombo")
        app.buttons["撤销"].tap()
        XCTAssertFalse(text(containing: "错和").exists, "撤销以后账本里没有错和这一行")
        shot("after-undo")

        // 10. 改流局那一局（点账本里的流局行 → 改局页 → 保存）
        let drawRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "听牌")).firstMatch
        wait(drawRow, "账本里的流局").tap()
        wait(app.buttons["保存"], "改局页：保存")
        shot("edit-hand")
        app.buttons["保存"].tap()

        // 11. 这一局（点第一手和牌）
        let winRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "莉莉自摸")).firstMatch
        wait(winRow, "账本里的莉莉自摸").tap()
        wait(app.buttons["改"], "这一局：改")
        shot("hand-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 12. 发到群（系统分享面板出来就关掉）
        wait(app.buttons["把账本发到群里"], "发到群").tap()
        sleep(2)
        shot("share-sheet")
        let close = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "关闭", "Close")).firstMatch
        if close.waitForExistence(timeout: 5) { close.tap() } else { app.swipeDown(velocity: .fast) }

        // 13. 结束 → 结算 → 记录
        wait(app.buttons["table-menu"], "更多菜单 2").tap()
        wait(app.buttons["结束牌局"], "结束牌局").tap()
        wait(app.alerts.buttons["结束"], "确认结束").tap()
        wait(text(containing: "终局"), "结算页", timeout: 10)
        shot("settle")
        wait(app.buttons["返回"], "结算：返回").tap()
        wait(app.buttons["开一局"], "回到空桌")
        app.tabBars.buttons["记录"].tap()
        shot("history")
    }

    /// 七对子（幺九和字牌）：不管哪张当和的那张，翻符都一样，所以不问「和的是哪张」。
    func testNoWinningTileQuestionWhenItDoesNotMatter() {
        app.launch()
        if app.buttons["开一局"].waitForExistence(timeout: 20) {
            app.buttons["开一局"].tap()
            for (field, name) in zip(["你", "下家", "对家", "上家"], ["甲", "乙", "丙", "丁"]) {
                let input = wait(app.textFields[field], "名字 \(field)")
                input.tap()
                input.typeText(name)
            }
            wait(app.buttons["开始"], "开始").tap()
        }
        wait(app.buttons["有人和了"], "牌桌", timeout: 20).tap()
        wait(app.buttons["手动输入"], "手动输入").tap()
        for tile in ["1万", "1万", "9万", "9万", "1饼", "1饼", "9饼", "9饼", "1条", "1条", "东", "东", "南", "南"] {
            wait(app.buttons["加一张"], "加一张").tap()
            let picks = app.buttons.matching(NSPredicate(format: "label == %@", tile))
            wait(picks.firstMatch, "选 \(tile)")
            picks.element(boundBy: picks.count - 1).tap()
        }
        wait(app.buttons.matching(NSPredicate(format: "label == %@", "甲")).firstMatch, "小桌上的甲").tap()
        wait(app.buttons["自摸"], "自摸").tap()
        XCTAssertTrue(app.buttons["看结果"].waitForExistence(timeout: 5), "能看结果")
        XCTAssertFalse(text(containing: "和的是哪张").exists, "七对子不用问和的是哪张")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "value == %@", "可以是和的那张")).count, 0)
        shot("no-winning-tile-question")
    }

    /// 有没打完的牌局时，打开 App 多久能看到牌桌（以前新模拟器上第一次会白屏 4–6 秒）。
    func testTableAppearsQuicklyOnRelaunch() {
        app.launch()
        if app.buttons["开一局"].waitForExistence(timeout: 20) {
            app.buttons["开一局"].tap()
            for (field, name) in zip(["你", "下家", "对家", "上家"], ["甲", "乙", "丙", "丁"]) {
                let input = wait(app.textFields[field], "名字 \(field)")
                input.tap()
                input.typeText(name)
            }
            wait(app.buttons["开始"], "开始").tap()
        }
        wait(app.buttons["有人和了"], "牌桌", timeout: 20)
        app.launchArguments.removeAll { $0 == "-ui-test-reset" }
        for round in 1...3 {
            app.terminate()
            let start = Date()
            app.launch()
            // 先等 tab 栏（App 起来了），再等牌桌：两个时间差就是牌桌自己画了多久
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
            let shell = Date().timeIntervalSince(start)
            XCTAssertTrue(app.buttons["有人和了"].waitForExistence(timeout: 15))
            let table = Date().timeIntervalSince(start)
            print("TIMING relaunch \(round): app shell \(String(format: "%.2f", shell)) s, table \(String(format: "%.2f", table)) s")
            XCTAssertLessThan(table - shell, 1.5, "App 起来以后牌桌应该马上出来")
        }
        shot("relaunch-table")
    }
}
