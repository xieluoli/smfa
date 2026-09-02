import XCTest

/// 端到端走查：把「添加 → 展示 → 搜索 → 复制 → 备份 → 删除」在真机流程上跑一遍，
/// 每一步留一张截图，作为交付证据。扫码需要摄像头，模拟器上无法覆盖。
final class AccountFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-store-for-uitest"]
        app.launch()
        // 等主界面渲染完再开始操作，否则冷启动较慢时后续的即时判断会误判
        XCTAssertTrue(app.navigationBars["S-MFA"].waitForExistence(timeout: 30),
                      "App 应完成启动")
    }

    func test走查主流程() {
        capture("01-空状态")

        addAccount(name: "Gitee:alice@example.com", secret: "JBSWY3DPEHPK3PXP")
        capture("02-首个账号与动态码")

        addAccount(name: "OpenAI:bob@example.com", secret: "MZXW6YTBOIFA2DQ")
        addAccount(name: "Google:carol@example.com", secret: "GEZDGNBVGY3TQOJQ")
        capture("03-账号列表")

        // 口令应随周期自动翻转：等到下一个周期后再截一张，用于对比
        Thread.sleep(forTimeInterval: 31)
        capture("04-下一周期口令已刷新")

        app.staticTexts["Google:carol@example.com"].tap()
        XCTAssertTrue(app.staticTexts["口令已复制"].waitForExistence(timeout: 3))
        capture("05-点击复制口令")

        openBackupSheet()
        capture("06-备份密码设置")
        app.navigationBars.buttons["取消"].tap()
        waitForListScreen()

        openDeleteConfirmation(for: "Google:carol@example.com")
        capture("07-删除二次确认")
        app.alerts.buttons["取消"].tap()
        waitForListScreen()

        // 搜索放在最后：iOS 26 进入搜索态会收起顶部工具栏，退出它得跟系统控件较劲，
        // 而搜索本身只需验证过滤结果。
        search("openai")
        // 等不匹配的账号消失，而不是等匹配的出现——后者本来就在屏幕上，等于没等
        XCTAssertTrue(app.staticTexts["Google:carol@example.com"].waitForNonExistence(timeout: 5),
                      "搜索后不匹配的账号应被过滤掉")
        XCTAssertTrue(app.staticTexts["OpenAI:bob@example.com"].exists)
        capture("08-搜索过滤")
    }

    func test手动添加的校验() {
        openManualAddPage()
        capture("09-手动添加页")

        // 两个输入框都为空时，确定应当不可用
        XCTAssertFalse(app.navigationBars.buttons["确定"].isEnabled)

        app.textFields["accountNameField"].tap()
        app.typeText("测试账号")
        app.textFields["secretField"].tap()
        app.typeText("11111111")   // 不在 Base32 字母表内
        app.navigationBars.buttons["确定"].tap()

        XCTAssertTrue(app.staticTexts["密钥格式不正确，请确认是网站给出的 Base32 密钥。"]
            .waitForExistence(timeout: 3))
        capture("10-非法密钥提示")
    }

    /// account-store 规格：冷启动后账号仍在。验证数据真的落到了 Keychain，
    /// 而不是只活在内存里。
    func test杀掉重启后账号仍在() {
        addAccount(name: "Gitee:alice@example.com", secret: "JBSWY3DPEHPK3PXP")

        app.terminate()

        // 不带重置参数重新启动，模拟用户杀掉 App 后再打开
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.staticTexts["Gitee:alice@example.com"].waitForExistence(timeout: 5),
                      "冷启动后账号应仍在列表中")
        capture("11-冷启动后账号仍在")
    }

    // MARK: - 操作封装

    private func addAccount(name: String, secret: String) {
        openManualAddPage()
        app.textFields["accountNameField"].tap()
        app.typeText(name)
        app.textFields["secretField"].tap()
        app.typeText(secret)
        app.navigationBars.buttons["确定"].tap()
        // 等新账号落到列表上再返回，否则下一次添加会撞上还没收起的表单
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 10),
                      "添加后 \(name) 应出现在列表中")
    }

    /// 一律走右上角「+」菜单：它在空列表和有账号时都在导航栏上，
    /// 不需要按列表状态分支，也就没有"用超时判断当前是哪种状态"的时序坑。
    private func openManualAddPage() {
        app.buttons["addMenu"].tap()
        app.buttons["menuManualAdd"].tap()
        XCTAssertTrue(app.navigationBars["添加账号"].waitForExistence(timeout: 10),
                      "点「+ → 手动添加」后应打开添加账号页")
    }

    private func search(_ keyword: String) {
        let field = app.searchFields.firstMatch
        field.tap()
        field.typeText(keyword)
    }

    private func openBackupSheet() {
        app.buttons["moreMenu"].tap()
        app.buttons["menuBackup"].tap()
        XCTAssertTrue(app.navigationBars["备份 MFA"].waitForExistence(timeout: 5))
    }

    private func openDeleteConfirmation(for accountName: String) {
        let row = app.staticTexts[accountName]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        // 列表按添加时间倒序，最新添加的账号在第一张卡片
        app.buttons.matching(identifier: "rowMenu").element(boundBy: 0).tap()
        app.buttons["rowDelete"].tap()
        XCTAssertTrue(app.alerts["删除账号"].waitForExistence(timeout: 10))
    }

    /// 浮层关闭有动画，等主列表重新可交互再继续，否则下一次点击会落在正在消失的浮层上。
    private func waitForListScreen() {
        XCTAssertTrue(app.buttons["moreMenu"].waitForExistence(timeout: 10),
                      "浮层关闭后应回到账号列表")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
