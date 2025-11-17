# Grind Dashboard 快速开始指南

本指南帮助你快速启动 Grind macOS 和 iOS Dashboard 功能。

## 📋 前置条件

- macOS 26.1+（用于运行 Grind-macOS）
- iOS 设备或模拟器（用于运行 Grind-iOS）
- Xcode 最新版本
- macOS 和 iOS 设备在同一 WiFi 网络

## 🚀 步骤 1: 启动 macOS 应用

### 1.1 构建并运行

```bash
cd Grind-macOS
xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Debug build
open build/Debug/Grind.app
```

或者直接在 Xcode 中打开并运行：
```bash
open Grind-macOS/Grind.xcodeproj
```

### 1.2 授予权限

首次运行时，应用会请求以下权限：
- **Accessibility 权限** - 用于监控键盘和鼠标活动
- **Screen Recording 权限** - 用于捕获窗口标题

前往 **系统设置 > 隐私与安全性** 授予这些权限。

### 1.3 验证服务运行

应用启动后会自动：
1. ✅ 开始监控活动（每 2 秒生成一个 heartbeat）
2. ✅ 启动网络服务器（端口 9527）
3. ✅ 广播 Bonjour 服务（`_grind._tcp`）

检查控制台输出：
```
✅ Database initialized at: ~/Library/Application Support/Grind/grind.db
✅ Added mouse tracking columns to daily_stats table
✅ Added mouse tracking columns to blocks_5min table
✅ Network server started on port 9527
```

## 📊 步骤 2: 生成测试数据

由于 DailyStats 聚合是按需运行的，你需要先生成一些测试数据。

### 2.1 方法 1: 手动触发聚合（推荐）

在 macOS 应用中添加一个按钮来触发聚合。修改 `ContentView.swift`：

```swift
Button("Aggregate Today's Data") {
    let calendar = Calendar.current
    for dayOffset in 0..<7 {
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
        TimeBlockAggregator.shared.aggregateToDailyStats(for: date)
    }
}
```

### 2.2 方法 2: 在应用启动时自动聚合

在 `GrindApp.swift` 的 `init()` 中添加：

```swift
// Aggregate last 7 days of data on startup
Task {
    let calendar = Calendar.current
    for dayOffset in 0..<7 {
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
        TimeBlockAggregator.shared.aggregateToDailyStats(for: date)
    }
}
```

### 2.3 验证数据

使用数据库工具（如 DB Browser for SQLite）打开数据库：
```bash
open ~/Library/Application\ Support/Grind/grind.db
```

检查 `daily_stats` 表是否有数据。

## 📱 步骤 3: 启动 iOS 应用

### 3.1 构建并运行

使用模拟器：
```bash
cd Grind-iOS
xcodebuild -project Grind.xcodeproj -scheme Grind -sdk iphonesimulator -configuration Debug build
open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app
```

或在 Xcode 中运行：
```bash
open Grind-iOS/Grind.xcodeproj
```

### 3.2 配置权限（Info.plist）

确保 iOS 应用的 `Info.plist` 包含以下权限：

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Grind needs local network access to connect to your Mac</string>

<key>NSBonjourServices</key>
<array>
    <string>_grind._tcp</string>
</array>
```

### 3.3 连接到 macOS Server

应用启动后会自动：
1. 🔍 搜索本地网络上的 Grind 服务器（Bonjour）
2. 🔗 自动连接到第一个发现的服务器
3. 📥 接收历史数据（最近 30 天）
4. 📊 显示 Dashboard

## 🎯 步骤 4: 验证 Dashboard 功能

### 4.1 检查连接状态

在 iOS Dashboard 顶部，你应该看到：
- 🟢 绿色指示器 + "Connected to [Mac Name]"

### 4.2 验证图表显示

**1. 实时打字速度仪表盘**
- 在 macOS 上开始打字
- iOS 上的 KPM 应实时更新（每分钟更新一次）
- 显示当前活跃应用名称

**2. Weekly Activity Chart**
- 显示最近 7 天的活跃时长
- 按应用堆叠显示
- X 轴显示日期，Y 轴显示小时数

**3. Weekly Keystrokes Chart**
- 显示最近 7 天的按键统计
- 按应用堆叠显示
- Y 轴单位为千（K）

**4. Today's Activity Timeline**
- 24 小时时间线（0:00 - 23:59）
- 蓝色块表示有活动，灰色表示无活动
- 5 分钟粒度

## 🐛 故障排除

### 问题 1: iOS 无法连接到 macOS

**解决方法：**
1. 确认两台设备在同一 WiFi 网络
2. 检查 macOS 防火墙设置（允许端口 9527）
3. 在 iOS 设置中检查本地网络权限
4. 查看 macOS 控制台日志确认服务器已启动

**临时方法：** 手动连接
```swift
// 在 DashboardViewModel.swift 的 connectToServer() 中
networkClient.connectToServer(host: "192.168.1.100", port: 9527)
```

### 问题 2: Dashboard 图表为空

**原因：** DailyStats 表没有数据

**解决方法：**
1. 按照步骤 2 生成测试数据
2. 重启 iOS 应用触发重新连接
3. 检查 macOS 控制台确认数据已发送

### 问题 3: Bonjour 服务发现失败

**解决方法：**
1. 检查网络连接类型（需要 WiFi）
2. 确认 macOS 的 NetworkService 代码中 `requiredInterfaceType = .wifi`
3. 在 iOS 中添加手动连接选项

## 📈 使用技巧

### 1. 实时监控

在 macOS 上进行以下操作，观察 iOS Dashboard 的变化：
- 打字 → KPM 实时更新
- 切换应用 → "Current App" 更新
- 持续活动 → Timeline 显示蓝色块

### 2. 历史数据分析

- 每天使用 macOS 应用积累数据
- 每天运行一次 `aggregateToDailyStats()` 生成每日统计
- iOS Dashboard 自动显示最近 7 天趋势

### 3. 性能优化

- macOS 每 30 秒自动保存 TimeBlocks
- iOS 使用 Combine 框架响应式更新 UI
- 网络传输使用 JSON + 长度前缀协议

## 🔧 进阶配置

### 自动每日聚合

在 macOS 应用中添加定时器（每天凌晨执行）：

```swift
// 在 GrindApp.swift
Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    TimeBlockAggregator.shared.aggregateToDailyStats(for: yesterday)
}
```

### 手动输入 IP 连接

在 iOS Dashboard 添加一个设置界面：

```swift
struct SettingsView: View {
    @State private var serverIP = "192.168.1.100"

    var body: some View {
        VStack {
            TextField("Server IP", text: $serverIP)
            Button("Connect") {
                NetworkClient.shared.connectToServer(host: serverIP, port: 9527)
            }
        }
    }
}
```

## 📚 相关文档

- `Grind-macOS/docs/PRD.md` - 完整产品需求文档
- `Grind-macOS/docs/PROJECT_STRUCTURE.md` - 架构说明
- `Grind-macOS/CLAUDE.md` - 构建和开发指南

## 💡 下一步

1. **增强数据展示**：修改 iOS Dashboard 显示按应用细分数据
2. **添加过滤功能**：按分类、按时间范围过滤
3. **导出功能**：导出统计报告为 PDF 或 CSV
4. **通知功能**：达到目标时推送通知

---

**享受你的生产力追踪之旅！** 🚀
