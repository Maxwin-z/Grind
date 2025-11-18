# iTerm2 颜色 1:1 还原实现总结

## 概览

本文档记录了 Grind 项目中 iTerm2 终端内容颜色 1:1 还原功能的完整实现。该功能允许 iOS 客户端精确还原 macOS iTerm2 终端的颜色显示，包括前景色、背景色和文字样式（粗体、斜体、下划线）。

## 实现日期
2025-11-18

## 架构概述

```
┌─────────────────────────────────────────────────────────────────┐
│                       macOS 端（数据源）                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ iterm2_event_monitor.py (Python Script)                  │  │
│  │                                                            │  │
│  │ • 使用 iTerm2 Python API 监听终端变化                       │  │
│  │ • 每 200ms 轮询屏幕内容变化                                 │  │
│  │ • 采集每个字符的:                                           │  │
│  │   - 字符内容 (char)                                         │  │
│  │   - 前景色 RGB (foreground_color)                           │  │
│  │   - 背景色 RGB (background_color)                           │  │
│  │   - 粗体 (bold)                                             │  │
│  │   - 斜体 (italic)                                           │  │
│  │   - 下划线 (underline)                                      │  │
│  │                                                            │  │
│  │ • 输出 JSON 格式:                                           │  │
│  │   {                                                        │  │
│  │     "styled_lines": [                                      │  │
│  │       {                                                    │  │
│  │         "text": "Hello World",                             │  │
│  │         "characters": [                                    │  │
│  │           {                                                │  │
│  │             "char": "H",                                   │  │
│  │             "fg_color": {"r": 255, "g": 0, "b": 0, "a": 255},│ │
│  │             "bg_color": null,                              │  │
│  │             "bold": true,                                  │  │
│  │             "italic": false,                               │  │
│  │             "underline": false                             │  │
│  │           },                                               │  │
│  │           ...                                              │  │
│  │         ]                                                  │  │
│  │       }                                                    │  │
│  │     ]                                                      │  │
│  │   }                                                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ ITerm2Service.swift (Swift Service)                       │  │
│  │                                                            │  │
│  │ • 启动/停止 Python 监控脚本                                  │  │
│  │ • 解析 JSON 输出到 Swift 模型                               │  │
│  │ • 管理会话生命周期                                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Models/ITerm2Info.swift (Data Models)                     │  │
│  │                                                            │  │
│  │ • struct RGBColor                                          │  │
│  │ • struct ITerm2Character                                   │  │
│  │ • struct ITerm2StyledLine                                  │  │
│  │ • struct ITerm2Session                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ NetworkService.swift (Network Layer)                       │  │
│  │                                                            │  │
│  │ • 监听端口 9527                                             │  │
│  │ • Bonjour 服务广播 (_grind._tcp)                           │  │
│  │ • 实时广播 iTerm2SessionsMessage                           │  │
│  │ • 包含完整的 styledLines 数据                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                               ↓
                    TCP + JSON (端口 9527)
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                        iOS 端（显示端）                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ NetworkClient.swift (Network Client)                       │  │
│  │                                                            │  │
│  │ • Bonjour 服务发现                                          │  │
│  │ • 自动连接 macOS 服务器                                      │  │
│  │ • 接收 iTerm2SessionsMessage                               │  │
│  │ • 解析 styledLines 数据                                     │  │
│  │ • 发布到 @Published 属性供 UI 使用                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Models/NetworkMessage.swift (Data Models)                  │  │
│  │                                                            │  │
│  │ • struct RGBColor                                          │  │
│  │ • struct ITerm2Character                                   │  │
│  │ • struct ITerm2StyledLine                                  │  │
│  │ • struct ITerm2Session                                     │  │
│  │                                                            │  │
│  │ • extension RGBColor {                                     │  │
│  │     var color: Color {  // SwiftUI Color 转换              │  │
│  │       Color(r/255, g/255, b/255, a/255)                    │  │
│  │     }                                                      │  │
│  │   }                                                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Views/ITerm2TerminalView.swift (UI Layer)                  │  │
│  │                                                            │  │
│  │ • ITerm2TerminalView(session:)                             │  │
│  │   - 主终端视图，渲染单个会话                                 │  │
│  │   - 优先使用 styledLines（带颜色）                          │  │
│  │   - 降级到 screenLines（纯文本）                            │  │
│  │                                                            │  │
│  │ • TerminalLineView(line:)                                  │  │
│  │   - 渲染单行终端内容                                         │  │
│  │   - 使用 HStack 水平排列字符                                │  │
│  │                                                            │  │
│  │ • TerminalCharacterView(character:)                        │  │
│  │   - 渲染单个字符及其样式                                     │  │
│  │   - .foregroundColor(char.fgColor?.color)                  │  │
│  │   - .background(char.bgColor?.color)                       │  │
│  │   - .fontWeight(char.bold ? .bold : .regular)              │  │
│  │   - .italic(char.italic)                                   │  │
│  │   - .underline(char.underline)                             │  │
│  │                                                            │  │
│  │ • ITerm2SessionCardView(session:)                          │  │
│  │   - 带展开/折叠的会话卡片                                    │  │
│  │   - 显示会话元数据                                           │  │
│  │   - 包含完整的终端视图                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## 关键文件修改

### macOS 端

#### 1. `Grind-macOS/iterm2_event_monitor.py`

**新增函数**:
```python
def color_to_dict(self, color):
    """Convert iTerm2 color object to RGB dictionary."""
    if color is None:
        return None
    return {
        "r": int(color.red),
        "g": int(color.green),
        "b": int(color.blue),
        "a": int(color.alpha) if hasattr(color, 'alpha') else 255
    }
```

**增强 `get_session_info` 函数**:
- 添加 `styled_lines` 数组
- 为每行的每个字符提取颜色和样式信息
- 保留 `screen_lines` 用于向后兼容

#### 2. `Grind-macOS/Grind/Models/ITerm2Info.swift`

**新增数据结构**:
```swift
struct RGBColor: Codable {
    let r: Int
    let g: Int
    let b: Int
    let a: Int
}

struct ITerm2Character: Codable {
    let char: String
    let fgColor: RGBColor?
    let bgColor: RGBColor?
    let bold: Bool
    let italic: Bool
    let underline: Bool
}

struct ITerm2StyledLine: Codable {
    let text: String
    let characters: [ITerm2Character]
}
```

**修改 `ITerm2Session`**:
- 添加 `styledLines: [ITerm2StyledLine]?` 属性

#### 3. `Grind-macOS/Grind/Services/Network/NetworkMessage.swift`

**修改 `ITerm2SessionData`**:
- 添加 `styledLines: [ITerm2StyledLine]?` 属性
- 引用 `ITerm2Info.swift` 中的共享类型定义

#### 4. `Grind-macOS/Grind/Services/ITerm2Service.swift`

**增强 `broadcastSessionsToNetwork` 函数**:
- 将 `ITerm2Session.styledLines` 映射到网络消息格式
- 传输完整的颜色数据到 iOS 客户端

### iOS 端

#### 1. `Grind-iOS/Grind/Models/NetworkMessage.swift`

**新增数据结构**:
```swift
struct RGBColor: Codable {
    let r: Int
    let g: Int
    let b: Int
    let a: Int
}

struct ITerm2Character: Codable {
    let char: String
    let fgColor: RGBColor?
    let bgColor: RGBColor?
    let bold: Bool
    let italic: Bool
    let underline: Bool
}

struct ITerm2StyledLine: Codable {
    let text: String
    let characters: [ITerm2Character]
}
```

**修改 `ITerm2Session`**:
- 添加 `styledLines: [ITerm2StyledLine]?` 属性

#### 2. `Grind-iOS/Grind/Views/ITerm2TerminalView.swift` (新文件)

**核心组件**:

1. **RGBColor 扩展**:
```swift
extension RGBColor {
    var color: Color {
        Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}
```

2. **TerminalCharacterView**:
```swift
struct TerminalCharacterView: View {
    let character: ITerm2Character

    var body: some View {
        Text(character.char.isEmpty ? " " : character.char)
            .font(.system(size: 12, design: .monospaced))
            .fontWeight(character.bold ? .bold : .regular)
            .italic(character.italic)
            .underline(character.underline)
            .foregroundColor(character.fgColor?.color ?? .white)
            .background(character.bgColor?.color ?? Color.clear)
    }
}
```

3. **ITerm2TerminalView**:
- 优先渲染 `styledLines`（带颜色）
- 降级到 `screenLines`（纯文本）
- 默认终端配色（黑底白字）

4. **ITerm2SessionCardView**:
- 可展开/折叠的会话卡片
- 显示会话状态和元数据
- 包含完整的终端视图

#### 3. `Grind-iOS/Grind/Views/DashboardView.swift`

**修改**:
- 移除旧的 `ITerm2TerminalView` 定义
- 添加 `ITerm2TerminalListView` 包装器
- 适配多个 iTerm2 会话的显示

## 数据流

### 1. macOS 采集阶段
```
iTerm2 终端
    ↓ (iTerm2 Python API)
Python 脚本每 200ms 检测屏幕变化
    ↓ (JSON stdout)
ITerm2Service.swift 解析
    ↓ (Swift 模型)
ITerm2Info (包含 styledLines)
```

### 2. 网络传输阶段
```
ITerm2Service 触发网络广播
    ↓
NetworkService.broadcastITerm2Sessions()
    ↓ (TCP + JSON)
发送 iTerm2SessionsMessage
    {
      "type": "iterm2Sessions",
      "timestamp": "2025-11-18T...",
      "sessions": [
        {
          "sessionId": "...",
          "styledLines": [...]
        }
      ]
    }
    ↓ (端口 9527)
iOS NetworkClient
```

### 3. iOS 渲染阶段
```
NetworkClient 接收消息
    ↓
解析到 ITerm2Session 模型
    ↓
发布到 @Published var iterm2Sessions
    ↓
DashboardViewModel 订阅
    ↓
ITerm2TerminalListView 显示
    ↓
ITerm2TerminalView 渲染单个会话
    ↓
TerminalLineView 渲染每一行
    ↓
TerminalCharacterView 渲染每个字符
    (应用颜色、粗体、斜体、下划线)
```

## 颜色映射

### iTerm2 颜色系统

iTerm2 使用以下颜色系统:
- **RGB True Color**: 每个颜色通道 0-255
- **ANSI 颜色**: 标准 16 色调色板
- **256 色模式**: 扩展调色板
- **自定义配色方案**: 用户可配置

### 实现的颜色映射

本实现直接获取 iTerm2 的 RGB 值:
```python
# Python 端
screen_char.foreground_color.red   # 0-255
screen_char.foreground_color.green # 0-255
screen_char.foreground_color.blue  # 0-255
```

```swift
// Swift 端 (iOS)
Color(
    red: Double(r) / 255.0,
    green: Double(g) / 255.0,
    blue: Double(b) / 255.0,
    opacity: Double(a) / 255.0
)
```

这保证了 **1:1 精确颜色还原**，无需额外的颜色映射表。

## 性能优化

### macOS 端
1. **变化检测**: 使用 MD5 哈希检测屏幕内容变化，避免重复发送
2. **轮询间隔**: 200ms (可调整)
3. **行数限制**: 最多采集最后 100 行

### iOS 端
1. **惰性渲染**: 使用 SwiftUI 的惰性加载
2. **视图复用**: 字符级别的视图复用
3. **降级策略**: 优先使用 styledLines，失败时降级到 screenLines

## 测试验证

### 构建验证
```bash
# macOS 端
cd Grind-macOS
xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Debug build
# ✅ BUILD SUCCEEDED

# iOS 端
cd Grind-iOS
xcodebuild -project Grind.xcodeproj -scheme Grind -sdk iphonesimulator -configuration Debug build
# ✅ BUILD SUCCEEDED
```

### 功能测试清单

- [x] macOS: Python 脚本能正确采集颜色信息
- [x] macOS: ITerm2Service 能解析 styled_lines
- [x] macOS: NetworkService 能传输颜色数据
- [x] iOS: NetworkClient 能接收颜色数据
- [x] iOS: ITerm2TerminalView 能正确渲染颜色
- [x] iOS: 粗体、斜体、下划线样式正确应用

## 后续改进建议

### 1. 性能优化
- [ ] 实现增量更新（仅发送变化的行）
- [ ] 添加字符级别的差异检测
- [ ] 使用 WebSocket 替代 TCP 以减少延迟

### 2. 功能增强
- [ ] 支持 iTerm2 自定义配色方案同步
- [ ] 实现光标渲染和闪烁动画
- [ ] 支持终端滚动缓冲区完整历史
- [ ] 添加终端输入功能（远程控制）

### 3. 用户体验
- [ ] 添加字体大小调节
- [ ] 支持双指缩放
- [ ] 实现选择和复制文本功能
- [ ] 添加主题切换（暗色/亮色模式）

### 4. 兼容性
- [ ] 支持其他终端模拟器（Terminal.app, Alacritty）
- [ ] 处理特殊字符和 Unicode
- [ ] 优化 CJK（中日韩）字符显示

## 已知限制

1. **仅支持 iTerm2**: 当前实现依赖 iTerm2 Python API
2. **单向渲染**: iOS 端仅显示，不支持输入
3. **性能**: 大量彩色输出可能影响性能
4. **网络依赖**: 需要 macOS 和 iOS 在同一局域网

## 文件清单

### 新增文件
- `Grind-iOS/Grind/Views/ITerm2TerminalView.swift`
- `Grind-macOS/test_colors.swift` (测试脚本)

### 修改文件
- `Grind-macOS/iterm2_event_monitor.py`
- `Grind-macOS/Grind/Models/ITerm2Info.swift`
- `Grind-macOS/Grind/Services/Network/NetworkMessage.swift`
- `Grind-macOS/Grind/Services/ITerm2Service.swift`
- `Grind-iOS/Grind/Models/NetworkMessage.swift`
- `Grind-iOS/Grind/Views/DashboardView.swift`

## 总结

本次实现成功为 Grind 项目添加了 iTerm2 终端颜色 1:1 还原功能。通过 Python 脚本采集完整的字符样式信息，经由网络传输到 iOS 客户端，并使用 SwiftUI 精确渲染，实现了真正的终端内容镜像显示。

关键成就:
- ✅ 完整的颜色数据采集（RGB + 样式）
- ✅ 高效的网络传输协议
- ✅ 精确的 SwiftUI 渲染
- ✅ 向后兼容的降级策略
- ✅ 两端构建成功验证

---

**实现者**: Claude (Anthropic)
**日期**: 2025-11-18
**版本**: 1.0.0
