import XCTest

/// 冒烟：第一次打开是空桌，开一局后牌桌出来。
final class SmokeUITests: XCTestCase {
    func testFreshLaunchShowsEmptyTable() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-ui-test-reset"]
        app.launch()
        XCTAssertTrue(app.buttons["开一局"].waitForExistence(timeout: 20))
    }
}
