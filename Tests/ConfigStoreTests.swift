import Foundation

@main
struct ConfigStoreTests {
    @MainActor
    static func main() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("parsec-chinese-helper-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.json")
        let logURL = temporaryDirectory.appendingPathComponent("log.txt")
        let fixture: [Any] = [
            "test fixture",
            [
                "unknown_future_key": ["value": "keep-me"],
                "client_vsync": ["value": 1],
                "encoder_bitrate": ["value": 12]
            ]
        ]
        let fixtureData = try JSONSerialization.data(
            withJSONObject: fixture,
            options: [.prettyPrinted, .sortedKeys]
        )
        try fixtureData.write(to: configURL, options: .atomic)

        let store = ParsecConfigStore(configURL: configURL, logURL: logURL)
        precondition(store.vSync == true, "应读取既有的 VSync 设置")
        precondition(store.bitrate == 12, "应读取既有的带宽设置")

        store.windowed = true
        store.vSync = false
        store.bitrate = 42
        store.showFriends = false
        store.hostName = "测试 Mac"
        store.save(restart: false)

        let savedData = try Data(contentsOf: configURL)
        let savedRoot = try JSONSerialization.jsonObject(with: savedData) as! [Any]
        let settings = savedRoot[1] as! [String: Any]

        func value(_ key: String) -> Any? {
            (settings[key] as? [String: Any])?["value"]
        }

        precondition(value("unknown_future_key") as? String == "keep-me", "必须保留未知配置")
        precondition((value("client_windowed") as? NSNumber)?.intValue == 1, "窗口模式保存失败")
        precondition((value("client_vsync") as? NSNumber)?.intValue == 0, "VSync 保存失败")
        precondition((value("encoder_bitrate") as? NSNumber)?.intValue == 42, "带宽保存失败")
        precondition((value("app_friends") as? NSNumber)?.intValue == 0, "好友菜单保存失败")
        precondition(value("host_name") as? String == "测试_Mac", "主机名规范化失败")

        print("CONFIG_STORE_TESTS_OK")
    }
}
