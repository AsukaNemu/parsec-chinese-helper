# Parsec 中文助手

一个独立的 macOS 中文控制界面，用来启动 Parsec、通过共享链接或 Peer ID 连接，以及管理常见的客户端、主机和日志设置。

它不会修改 Parsec 应用本身，也不会读取密码或代理远程画面。设置写入 Parsec 官方配置文件：

`~/.parsec/config.json`

## 功能

- 通过共享链接或 Peer ID 快速连接
- 中文管理 21 项常用客户端、主机和高级设置
- 保存设置并自动重启 Parsec
- 快速定位 Parsec 配置文件和日志
- 保留配置文件中的未知键值，兼容后续版本扩展

## 系统要求

- Apple Silicon 或 Intel Mac（按本机架构构建）
- macOS 13 或更高版本
- 已安装官方 [Parsec](https://parsec.app/downloads)
- Xcode 命令行构建工具

## 构建

```bash
./build.sh
```

构建结果位于 `build/Parsec 中文助手.app`。

若命令行工具使用的 SDK 报 `SwiftUIMacros.StateMacro` 插件缺失，请先确认 Xcode/命令行工具与 SDK 配套。
如果本机已有兼容的 macOS SDK，可以临时通过 `SDKROOT` 指定它运行 `./test.sh` 和 `./build.sh`，无需更改全局开发工具设置。
例如将下方路径替换为本机已安装 SDK 的绝对路径：

```bash
SDKROOT=/path/to/MacOSX.sdk ./test.sh
SDKROOT=/path/to/MacOSX.sdk ./build.sh
```

安装到“应用程序”文件夹：

```bash
ditto "build/Parsec 中文助手.app" "/Applications/Parsec 中文助手.app"
open "/Applications/Parsec 中文助手.app"
```

## 测试

```bash
./test.sh
```

测试会在临时目录验证配置读取、保存以及未知键值保留，不会改动真实的 Parsec 配置。

## 说明

- 电脑列表、账户登录和远程画面仍由官方 Parsec 窗口提供。
- 配置保存后需要重启 Parsec 才会生效。
- 本项目与 Parsec Cloud, Inc. 或 Unity 无隶属关系。
