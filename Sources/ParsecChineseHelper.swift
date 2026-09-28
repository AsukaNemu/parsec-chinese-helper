import AppKit
import SwiftUI

private let parsecBundleIdentifier = "tv.parsec.www"
private let parsecApplicationURL = URL(fileURLWithPath: "/Applications/Parsec.app")

enum SidebarPage: String, CaseIterable, Identifiable {
    case home = "主页"
    case client = "客户端"
    case host = "主机"
    case advanced = "高级"
    case help = "帮助"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .client: return "display"
        case .host: return "desktopcomputer"
        case .advanced: return "slider.horizontal.3"
        case .help: return "questionmark.circle"
        }
    }
}

@MainActor
final class ParsecConfigStore: ObservableObject {
    @Published var parsecRunning = false
    @Published var parsecVersion = "未安装"
    @Published var connectionTarget = ""
    @Published var message = "已读取当前配置"
    @Published var messageIsError = false

    // Client settings
    @Published var windowed = false
    @Published var vSync = true
    @Published var h265 = true
    @Published var overlay = true
    @Published var overlayWarnings = true
    @Published var tenBitColor = false
    @Published var softwareDecoder = false
    @Published var macKeySwap = true
    @Published var hidKeyboard = true
    @Published var immersiveMode = 0
    @Published var microphonePassthrough = false

    // Host settings
    @Published var hostingEnabled = false
    @Published var preventSleep = false
    @Published var hostName = ""
    @Published var bitrate = 10
    @Published var muteHostSpeakers = true
    @Published var maxClients = 20
    @Published var constantFPS = false

    // Advanced settings
    @Published var showFriends = true
    @Published var logLevel = 1
    @Published var experimentalWebUI = false

    let configURL: URL
    let logURL: URL

    init(
        configURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".parsec/config.json"),
        logURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".parsec/log.txt")
    ) {
        self.configURL = configURL
        self.logURL = logURL
        refreshInstallationStatus()
        load()
    }

    func refreshInstallationStatus() {
        parsecRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: parsecBundleIdentifier
        ).isEmpty

        let plistURL = parsecApplicationURL
            .appendingPathComponent("Contents/Info.plist")
        if let dictionary = NSDictionary(contentsOf: plistURL),
           let version = dictionary["CFBundleShortVersionString"] as? String {
            parsecVersion = version
        } else {
            parsecVersion = "未安装"
        }
    }

    func load() {
        do {
            let settings = try readSettings()

            windowed = intValue(settings, "client_windowed", default: 0) == 1
            vSync = intValue(settings, "client_vsync", default: 1) == 1
            h265 = intValue(settings, "client_decoder_h265", default: 1) == 1
            overlay = intValue(settings, "client_overlay", default: 1) == 1
            overlayWarnings = intValue(settings, "client_overlay_warnings", default: 1) == 1
            tenBitColor = boolValue(settings, "client_decoder_10bit", default: false)
            softwareDecoder = intValue(settings, "decoder_software", default: 0) == 1
            macKeySwap = boolValue(settings, "client_macos_key_swap", default: true)
            hidKeyboard = boolValue(settings, "app_hid_keyboard", default: true)
            immersiveMode = intValue(settings, "client_immersive", default: 0)
            microphonePassthrough = boolValue(settings, "client_mic_passthrough", default: false)

            hostingEnabled = intValue(settings, "app_host", default: 0) == 1
            preventSleep = boolValue(settings, "host_prevent_sleep", default: false)
            hostName = stringValue(settings, "host_name", default: "")
            bitrate = intValue(settings, "encoder_bitrate", default: 10)
            muteHostSpeakers = intValue(settings, "server_admin_mute", default: 1) == 1
            maxClients = intValue(settings, "server_max_clients", default: 20)
            constantFPS = boolValue(settings, "host_full_fps", default: false)

            showFriends = intValue(settings, "app_friends", default: 1) == 1
            logLevel = intValue(settings, "app_log_level", default: 1)
            experimentalWebUI = boolValue(settings, "client_web_ui", default: false)

            setMessage("已读取当前配置")
        } catch {
            setMessage("读取配置失败：\(error.localizedDescription)", isError: true)
        }
    }

    func save(restart: Bool) {
        do {
            var root = try readRoot()
            var settings = root[1] as? [String: Any] ?? [:]

            set(&settings, "client_windowed", windowed ? 1 : 0)
            set(&settings, "client_vsync", vSync ? 1 : 0)
            set(&settings, "client_decoder_h265", h265 ? 1 : 0)
            set(&settings, "client_overlay", overlay ? 1 : 0)
            set(&settings, "client_overlay_warnings", overlayWarnings ? 1 : 0)
            set(&settings, "client_decoder_10bit", tenBitColor)
            set(&settings, "decoder_software", softwareDecoder ? 1 : 0)
            set(&settings, "client_macos_key_swap", macKeySwap)
            set(&settings, "app_hid_keyboard", hidKeyboard)
            set(&settings, "client_immersive", immersiveMode)
            set(&settings, "client_mic_passthrough", microphonePassthrough)

            set(&settings, "app_host", hostingEnabled ? 1 : 0)
            set(&settings, "host_prevent_sleep", preventSleep)
            if hostName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                settings.removeValue(forKey: "host_name")
            } else {
                let normalizedName = hostName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: " ", with: "_")
                set(&settings, "host_name", normalizedName)
            }
            set(&settings, "encoder_bitrate", max(1, min(bitrate, 100)))
            set(&settings, "server_admin_mute", muteHostSpeakers ? 1 : 0)
            set(&settings, "server_max_clients", max(1, min(maxClients, 20)))
            set(&settings, "host_full_fps", constantFPS)

            set(&settings, "app_friends", showFriends ? 1 : 0)
            set(&settings, "app_log_level", max(1, min(logLevel, 3)))
            set(&settings, "client_web_ui", experimentalWebUI)

            root[1] = settings
            let data = try JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )
            try data.write(to: configURL, options: .atomic)

            if restart {
                restartParsec()
                setMessage("配置已保存，正在重启 Parsec")
            } else {
                setMessage("配置已保存；重启 Parsec 后生效")
            }
        } catch {
            setMessage("保存失败：\(error.localizedDescription)", isError: true)
        }
    }

    func openParsec() {
        guard FileManager.default.fileExists(atPath: parsecApplicationURL.path) else {
            setMessage("没有在“应用程序”文件夹找到 Parsec", isError: true)
            return
        }
        NSWorkspace.shared.open(parsecApplicationURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.refreshInstallationStatus()
        }
        setMessage("已打开 Parsec")
    }

    func restartParsec() {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: parsecBundleIdentifier) {
            app.terminate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            NSWorkspace.shared.open(parsecApplicationURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.refreshInstallationStatus()
            }
        }
    }

    func connect() {
        let target = connectionTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else {
            setMessage("请先输入共享链接或 Peer ID", isError: true)
            return
        }

        if let url = URL(string: target),
           let scheme = url.scheme?.lowercased(),
           ["https", "http", "parsec"].contains(scheme) {
            NSWorkspace.shared.open(url)
            setMessage("已交给 Parsec 打开连接")
            return
        }

        let executableURL = parsecApplicationURL
            .appendingPathComponent("Contents/MacOS/parsecd")
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            setMessage("找不到 Parsec 可执行文件", isError: true)
            return
        }

        do {
            let process = Process()
            process.executableURL = executableURL
            process.arguments = ["peer_id=\(target)"]
            try process.run()
            setMessage("正在连接 Peer ID：\(target)")
        } catch {
            setMessage("连接失败：\(error.localizedDescription)", isError: true)
        }
    }

    func revealConfig() {
        NSWorkspace.shared.activateFileViewerSelecting([configURL])
    }

    func revealLog() {
        if FileManager.default.fileExists(atPath: logURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([logURL])
        } else {
            setMessage("暂时没有找到 Parsec 日志", isError: true)
        }
    }

    func openURL(_ address: String) {
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }

    private func setMessage(_ value: String, isError: Bool = false) {
        message = value
        messageIsError = isError
    }

    private func readRoot() throws -> [Any] {
        if !FileManager.default.fileExists(atPath: configURL.path) {
            try FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            return [
                "由 Parsec 中文助手创建。高级设置说明：https://parsec.app/config",
                [String: Any]()
            ]
        }

        let data = try Data(contentsOf: configURL)
        guard var root = try JSONSerialization.jsonObject(with: data) as? [Any] else {
            throw ConfigError.invalidRoot
        }
        while root.count < 2 { root.append([String: Any]()) }
        return root
    }

    private func readSettings() throws -> [String: Any] {
        let root = try readRoot()
        return root[1] as? [String: Any] ?? [:]
    }

    private func rawValue(_ settings: [String: Any], _ key: String) -> Any? {
        (settings[key] as? [String: Any])?["value"]
    }

    private func boolValue(_ settings: [String: Any], _ key: String, default fallback: Bool) -> Bool {
        if let value = rawValue(settings, key) as? Bool { return value }
        if let value = rawValue(settings, key) as? NSNumber { return value.boolValue }
        if let value = rawValue(settings, key) as? String {
            return ["1", "true", "yes", "on"].contains(value.lowercased())
        }
        return fallback
    }

    private func intValue(_ settings: [String: Any], _ key: String, default fallback: Int) -> Int {
        if let value = rawValue(settings, key) as? NSNumber { return value.intValue }
        if let value = rawValue(settings, key) as? String, let number = Int(value) { return number }
        return fallback
    }

    private func stringValue(_ settings: [String: Any], _ key: String, default fallback: String) -> String {
        rawValue(settings, key) as? String ?? fallback
    }

    private func set(_ settings: inout [String: Any], _ key: String, _ value: Any) {
        settings[key] = ["value": value]
    }

    enum ConfigError: LocalizedError {
        case invalidRoot

        var errorDescription: String? {
            switch self {
            case .invalidRoot: return "config.json 格式不正确"
            }
        }
    }
}

struct StatusPill: View {
    let running: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(running ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text(running ? "Parsec 运行中" : "Parsec 未运行")
                .font(.callout.weight(.medium))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
}

struct PageTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    init(_ title: String, detail: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 24)
            content
        }
        .padding(.vertical, 5)
    }
}

struct SaveBar: View {
    @EnvironmentObject var model: ParsecConfigStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.messageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(model.messageIsError ? .orange : .green)
            Text(model.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button("重新读取") { model.load() }
            Button("仅保存") { model.save(restart: false) }
            Button("保存并重启 Parsec") { model.save(restart: true) }
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(.bar)
    }
}

struct HomeView: View {
    @EnvironmentObject var model: ParsecConfigStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageTitle(
                    title: "Parsec 中文助手",
                    subtitle: "用中文完成连接和常用设置，官方 Parsec 负责实际传输。"
                )

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("快速连接", systemImage: "bolt.horizontal.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.purple)
                        Text("输入好友发来的共享链接，或直接输入 Peer ID。")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            TextField("共享链接或 Peer ID", text: $model.connectionTarget)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { model.connect() }
                            Button("连接") { model.connect() }
                                .buttonStyle(.borderedProminent)
                                .keyboardShortcut(.return, modifiers: [])
                        }
                    }
                    .padding(8)
                }

                HStack(spacing: 16) {
                    InfoCard(
                        icon: "app.badge.checkmark",
                        title: "Parsec 版本",
                        value: model.parsecVersion,
                        tint: .blue
                    )
                    InfoCard(
                        icon: "gearshape.2.fill",
                        title: "中文设置项",
                        value: "21 项",
                        tint: .purple
                    )
                    InfoCard(
                        icon: "lock.shield.fill",
                        title: "工作方式",
                        value: "本机配置",
                        tint: .green
                    )
                }

                GroupBox {
                    HStack(spacing: 16) {
                        Image(systemName: "display.2")
                            .font(.system(size: 34))
                            .foregroundStyle(.blue)
                            .frame(width: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("电脑列表和账户登录")
                                .font(.headline)
                            Text("这两部分仍由官方 Parsec 窗口显示；连接、画面和输入性能不会经过中文助手。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("打开 Parsec") { model.openParsec() }
                            .controlSize(.large)
                    }
                    .padding(8)
                }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("所有更改都写入 Parsec 官方 config.json；原程序和登录信息不会被修改。")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(28)
        }
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        GroupBox {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.headline)
                }
                Spacer(minLength: 0)
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ClientSettingsView: View {
    @EnvironmentObject var model: ParsecConfigStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageTitle(title: "客户端设置", subtitle: "控制连接到其他电脑时的画面、输入和声音。")

                    GroupBox("画面") {
                        VStack(spacing: 10) {
                            SettingRow("窗口模式", detail: "连接后使用窗口，而不是自动全屏。") {
                                Toggle("", isOn: $model.windowed).labelsHidden()
                            }
                            Divider()
                            SettingRow("垂直同步", detail: "消除画面撕裂；关闭可略微降低延迟。") {
                                Toggle("", isOn: $model.vSync).labelsHidden()
                            }
                            Divider()
                            SettingRow("H.265 / HEVC", detail: "画质更好、带宽更省；不兼容时会回退到 H.264。") {
                                Toggle("", isOn: $model.h265).labelsHidden()
                            }
                            Divider()
                            SettingRow("10 位色彩", detail: "需要同时开启 H.265，可能增加延迟和带宽。") {
                                Toggle("", isOn: $model.tenBitColor).labelsHidden()
                            }
                            Divider()
                            SettingRow("软件解码", detail: "仅在硬件解码异常时开启，通常会更慢。") {
                                Toggle("", isOn: $model.softwareDecoder).labelsHidden()
                            }
                        }
                        .padding(8)
                    }

                    GroupBox("连接时界面") {
                        VStack(spacing: 10) {
                            SettingRow("显示悬浮按钮", detail: "在远程画面左上角显示 Parsec 菜单按钮。") {
                                Toggle("", isOn: $model.overlay).labelsHidden()
                            }
                            Divider()
                            SettingRow("显示性能警告", detail: "网络或硬件性能不足时给出提示。") {
                                Toggle("", isOn: $model.overlayWarnings).labelsHidden()
                            }
                        }
                        .padding(8)
                    }

                    GroupBox("输入与声音") {
                        VStack(spacing: 10) {
                            SettingRow("交换 Command 与 Ctrl", detail: "在 macOS 与 Windows 间连接时更符合常用快捷键习惯。") {
                                Toggle("", isOn: $model.macKeySwap).labelsHidden()
                            }
                            Divider()
                            SettingRow("HID 键盘模式", detail: "让特殊快捷键传给远端；需要辅助功能权限。") {
                                Toggle("", isOn: $model.hidKeyboard).labelsHidden()
                            }
                            Divider()
                            SettingRow("沉浸模式", detail: "决定是否锁定键盘或鼠标到远程窗口。") {
                                Picker("", selection: $model.immersiveMode) {
                                    Text("关闭").tag(0)
                                    Text("键盘和鼠标").tag(1)
                                    Text("仅键盘").tag(2)
                                    Text("仅鼠标").tag(3)
                                }
                                .labelsHidden()
                                .frame(width: 150)
                            }
                            Divider()
                            SettingRow("传递本机麦克风", detail: "将本机默认麦克风发送到远端。") {
                                Toggle("", isOn: $model.microphonePassthrough).labelsHidden()
                            }
                        }
                        .padding(8)
                    }
                }
                .padding(28)
            }
            SaveBar()
        }
    }
}

struct HostSettingsView: View {
    @EnvironmentObject var model: ParsecConfigStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageTitle(title: "主机设置", subtitle: "控制别人连接到这台 Mac 时的行为。")

                    GroupBox("可用性") {
                        VStack(spacing: 10) {
                            SettingRow("允许连接到这台 Mac", detail: "开启主机功能；首次使用仍需在系统设置中授权。") {
                                Toggle("", isOn: $model.hostingEnabled).labelsHidden()
                            }
                            Divider()
                            SettingRow("主机保持唤醒", detail: "启用主机时阻止 Mac 自动睡眠。") {
                                Toggle("", isOn: $model.preventSleep).labelsHidden()
                            }
                            Divider()
                            SettingRow("显示名称", detail: "留空则使用系统电脑名；空格会自动替换为下划线。") {
                                TextField("使用系统电脑名", text: $model.hostName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 220)
                            }
                        }
                        .padding(8)
                    }

                    GroupBox("画质与带宽") {
                        VStack(spacing: 10) {
                            SettingRow("带宽上限", detail: "数值越高画质越好，也更依赖网络。") {
                                HStack(spacing: 8) {
                                    Stepper("", value: $model.bitrate, in: 1...100)
                                        .labelsHidden()
                                    Text("\(model.bitrate) Mbps")
                                        .monospacedDigit()
                                        .frame(width: 72, alignment: .trailing)
                                }
                            }
                            Divider()
                            SettingRow("恒定帧率", detail: "桌面静止时仍保持完整帧率；全屏游戏通常建议关闭。") {
                                Toggle("", isOn: $model.constantFPS).labelsHidden()
                            }
                        }
                        .padding(8)
                    }

                    GroupBox("会话") {
                        VStack(spacing: 10) {
                            SettingRow("连接本机时静音扬声器", detail: "自己远程连接后，自动静音主机扬声器。") {
                                Toggle("", isOn: $model.muteHostSpeakers).labelsHidden()
                            }
                            Divider()
                            SettingRow("最多连接人数", detail: "总带宽会在所有连接者之间分配。") {
                                HStack(spacing: 8) {
                                    Stepper("", value: $model.maxClients, in: 1...20)
                                        .labelsHidden()
                                    Text("\(model.maxClients) 人")
                                        .monospacedDigit()
                                        .frame(width: 54, alignment: .trailing)
                                }
                            }
                        }
                        .padding(8)
                    }
                }
                .padding(28)
            }
            SaveBar()
        }
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject var model: ParsecConfigStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageTitle(title: "高级设置", subtitle: "不常用的界面和故障排查选项。")

                    GroupBox("界面") {
                        VStack(spacing: 10) {
                            SettingRow("显示好友菜单", detail: "只隐藏入口，不会删除好友或更改账户。") {
                                Toggle("", isOn: $model.showFriends).labelsHidden()
                            }
                            Divider()
                            SettingRow("实验性 Web 界面", detail: "Parsec 官方预览功能，可能缺少功能；它本身仍是英文。") {
                                Toggle("", isOn: $model.experimentalWebUI).labelsHidden()
                            }
                        }
                        .padding(8)
                    }

                    GroupBox("日志") {
                        VStack(spacing: 10) {
                            SettingRow("日志详细程度", detail: "排查问题时可临时调高；级别 1 性能影响最小。") {
                                Picker("", selection: $model.logLevel) {
                                    Text("1 — 默认").tag(1)
                                    Text("2 — 详细").tag(2)
                                    Text("3 — 最详细").tag(3)
                                }
                                .labelsHidden()
                                .frame(width: 140)
                            }
                            Divider()
                            HStack {
                                Button("在 Finder 中显示日志") { model.revealLog() }
                                Button("显示配置文件") { model.revealConfig() }
                                Spacer()
                            }
                        }
                        .padding(8)
                    }

                    GroupBox {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundStyle(.orange)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("高级配置提醒").font(.headline)
                                Text("中文助手只维护页面中列出的选项，其他已有键值会原样保留。手工编辑 JSON 前请先退出 Parsec。")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(8)
                    }
                }
                .padding(28)
            }
            SaveBar()
        }
    }
}

struct HelpView: View {
    @EnvironmentObject var model: ParsecConfigStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageTitle(title: "帮助", subtitle: "常见入口和中文说明。")

                GroupBox("中文助手能做什么") {
                    VStack(alignment: .leading, spacing: 10) {
                        HelpLine(icon: "link", text: "用共享链接或 Peer ID 发起连接")
                        HelpLine(icon: "slider.horizontal.3", text: "用中文调整常见客户端和主机参数")
                        HelpLine(icon: "arrow.clockwise", text: "保存配置并自动重启 Parsec")
                        HelpLine(icon: "doc.text.magnifyingglass", text: "快速定位配置文件和日志")
                    }
                    .padding(8)
                }

                GroupBox("需要知道") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("• Parsec 的电脑列表、账户登录和远程画面仍在官方窗口中。")
                        Text("• 中文助手不读取密码，也不代理远程画面或网络流量。")
                        Text("• 修改的配置需要重启 Parsec 才会生效。")
                        Text("• Parsec 更新后，中文助手仍可继续使用；如果配置键发生变化，请以官方文档为准。")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(8)
                }

                GroupBox("官方资源") {
                    VStack(alignment: .leading, spacing: 12) {
                        LinkButton(title: "高级配置说明", icon: "gearshape", address: "https://parsec.app/config")
                        LinkButton(title: "错误代码说明", icon: "exclamationmark.triangle", address: "https://support.parsec.app/hc/en-us/articles/32381281333012-All-Error-Codes")
                        LinkButton(title: "Parsec 帮助中心", icon: "lifepreserver", address: "https://support.parsec.app/")
                    }
                    .padding(8)
                }

                HStack {
                    Button("打开 Parsec") { model.openParsec() }
                        .buttonStyle(.borderedProminent)
                    Button("显示配置文件") { model.revealConfig() }
                    Button("显示日志") { model.revealLog() }
                }
            }
            .padding(28)
        }
    }
}

struct HelpLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .frame(width: 24)
            Text(text)
        }
    }
}

struct LinkButton: View {
    @EnvironmentObject var model: ParsecConfigStore
    let title: String
    let icon: String
    let address: String

    var body: some View {
        Button {
            model.openURL(address)
        } label: {
            HStack {
                Image(systemName: icon).frame(width: 24)
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ContentView: View {
    @State private var selection: SidebarPage? = .home
    @EnvironmentObject var model: ParsecConfigStore

    var body: some View {
        NavigationSplitView {
            List(SidebarPage.allCases, selection: $selection) { page in
                Label(page.rawValue, systemImage: page.icon)
                    .tag(page)
                    .padding(.vertical, 3)
            }
            .navigationTitle("Parsec 中文助手")
            .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 250)
        } detail: {
            switch selection ?? .home {
            case .home: HomeView()
            case .client: ClientSettingsView()
            case .host: HostSettingsView()
            case .advanced: AdvancedSettingsView()
            case .help: HelpView()
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                StatusPill(running: model.parsecRunning)
            }
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            model.refreshInstallationStatus()
        }
    }
}

#if !TESTING
@main
struct ParsecChineseHelperApp: App {
    @StateObject private var model = ParsecConfigStore()

    var body: some Scene {
        WindowGroup("Parsec 中文助手") {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 Parsec 中文助手") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Parsec 中文助手",
                        .applicationVersion: "1.0.0",
                        .credits: NSAttributedString(string: "本机中文控制界面，不隶属于 Parsec 或 Unity。")
                    ])
                }
            }
        }
    }
}
#endif
