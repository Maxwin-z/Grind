# iTerm2 颜色渲染测试指南

## 快速测试步骤

### 前置条件

1. **macOS 设备**: 运行 Grind 服务端
2. **iOS 设备或模拟器**: 运行 Grind 客户端
3. **iTerm2**: 已安装并配置 Python API
4. **同一网络**: 两个设备在同一局域网

### 测试步骤

#### 1. 启动 macOS 服务端

```bash
cd /Users/maxwin/workspace/Grind/Grind-macOS

# 构建项目
xcodebuild -project Grind.xcodeproj -scheme Grind -configuration Debug build

# 运行应用
open build/Debug/Grind.app
```

**验证点**:
- ✓ 应用启动无错误
- ✓ 网络服务在端口 9527 监听
- ✓ Bonjour 服务 "_grind._tcp" 已广播

#### 2. 打开 iTerm2 并运行彩色命令

在 iTerm2 中运行以下命令以生成彩色输出:

```bash
# 测试 1: ANSI 基础颜色
echo -e "\033[31mRed Text\033[0m"
echo -e "\033[32mGreen Text\033[0m"
echo -e "\033[33mYellow Text\033[0m"
echo -e "\033[34mBlue Text\033[0m"
echo -e "\033[35mMagenta Text\033[0m"
echo -e "\033[36mCyan Text\033[0m"

# 测试 2: 粗体和样式
echo -e "\033[1mBold Text\033[0m"
echo -e "\033[3mItalic Text\033[0m"
echo -e "\033[4mUnderlined Text\033[0m"

# 测试 3: 背景色
echo -e "\033[41mRed Background\033[0m"
echo -e "\033[42mGreen Background\033[0m"
echo -e "\033[43mYellow Background\033[0m"

# 测试 4: 组合样式
echo -e "\033[1;31mBold Red\033[0m"
echo -e "\033[4;32mUnderlined Green\033[0m"
echo -e "\033[1;3;33mBold Italic Yellow\033[0m"

# 测试 5: 256 色
echo -e "\033[38;5;196mBright Red (256)\033[0m"
echo -e "\033[38;5;21mDeep Blue (256)\033[0m"

# 测试 6: RGB True Color
echo -e "\033[38;2;255;100;0mOrange (RGB)\033[0m"
echo -e "\033[38;2;100;200;50mLight Green (RGB)\033[0m"

# 测试 7: 实际工具输出
ls -la --color=always
git status  # 如果在 git 仓库中
```

**验证点**:
- ✓ iTerm2 显示彩色输出
- ✓ Python 监控脚本已启动（检查日志）
- ✓ macOS Grind 应用显示 iTerm2 会话信息

#### 3. 启动 iOS 客户端

```bash
cd /Users/maxwin/workspace/Grind/Grind-iOS

# 构建并运行到模拟器
xcodebuild -project Grind.xcodeproj -scheme Grind -sdk iphonesimulator -configuration Debug build

# 或者在 Xcode 中打开并运行
open Grind.xcodeproj
```

**验证点**:
- ✓ 应用启动无错误
- ✓ DashboardView 显示 "Connected to [Mac Name]"
- ✓ iTerm2 区域显示终端内容

#### 4. 验证颜色渲染

在 iOS 应用的 DashboardView 中找到 iTerm2 终端区域，检查:

**基础验证**:
- [ ] 终端内容显示
- [ ] 文本颜色正确（红、绿、蓝等）
- [ ] 背景色正确
- [ ] 粗体文字加粗显示
- [ ] 斜体文字倾斜显示
- [ ] 下划线正确显示

**高级验证**:
- [ ] 256 色模式颜色准确
- [ ] RGB True Color 渲染正确
- [ ] 组合样式（粗体+斜体）正确
- [ ] 实时更新（在 iTerm2 输入新命令，iOS 端实时显示）

#### 5. 性能测试

```bash
# 在 iTerm2 中生成大量彩色输出
for i in {1..100}; do
    echo -e "\033[3$((i % 8))m Line $i with color \033[0m"
done

# 观察 iOS 端
# - 是否流畅更新？
# - 是否有延迟？
# - 内存使用是否正常？
```

## 调试步骤

### macOS 端调试

#### 检查 Python 脚本是否运行

```bash
# 查看 Python 进程
ps aux | grep iterm2_event_monitor.py

# 查看脚本输出（如果手动运行）
python3 /Users/maxwin/workspace/Grind/Grind-macOS/iterm2_event_monitor.py
```

#### 检查网络服务

```bash
# 查看端口 9527 是否监听
lsof -i TCP:9527

# 检查 Bonjour 服务
dns-sd -B _grind._tcp
```

#### 查看应用日志

```bash
# 在 Xcode Console 或系统日志中搜索
log stream --predicate 'subsystem == "me.maxwin.Grind"' --level debug
```

### iOS 端调试

#### 检查网络连接

在 Xcode 调试器中设置断点:
- `NetworkClient.swift`: `handleMessage()` 方法
- `DashboardViewModel.swift`: `iterm2Sessions` didSet

#### 验证数据接收

打印接收到的数据:
```swift
// 在 NetworkClient.swift 的 handleMessage 中添加
print("📨 Received iTerm2Sessions: \(sessions.count) sessions")
if let styledLines = sessions.first?.styledLines {
    print("🎨 Styled lines: \(styledLines.count)")
    print("🎨 First line: \(styledLines.first?.text ?? "N/A")")
}
```

#### 检查视图渲染

在 `ITerm2TerminalView.swift` 中添加:
```swift
// 在 body 中添加
.onAppear {
    print("🖥️ Rendering terminal view")
    if let styledLines = session.styledLines {
        print("🖥️ Styled lines count: \(styledLines.count)")
    }
}
```

## 常见问题排查

### 问题 1: iOS 端看不到 iTerm2 内容

**可能原因**:
1. macOS 和 iOS 不在同一网络
2. 网络服务未启动
3. iTerm2Service 未启动

**解决方案**:
```bash
# macOS 端检查
lsof -i TCP:9527  # 应该显示 Grind 进程
ps aux | grep iterm2_event_monitor  # 应该有 Python 进程

# iOS 端检查
# 在 Xcode Console 查看是否有 "Connected to [Mac Name]" 日志
```

### 问题 2: 终端显示纯文本，无颜色

**可能原因**:
1. Python 脚本未正确采集颜色
2. `styledLines` 未传输
3. iOS 端未使用 `styledLines`

**解决方案**:
```bash
# 手动测试 Python 脚本
cd /Users/maxwin/workspace/Grind/Grind-macOS
python3 iterm2_event_monitor.py

# 查看输出是否包含 "styled_lines" 字段
# 检查是否有 "fg_color", "bg_color" 数据
```

在 iOS 端验证:
```swift
// 在 ITerm2TerminalView.body 中添加
if let styledLines = session.styledLines {
    print("✅ Using styled lines: \(styledLines.count)")
} else {
    print("⚠️ No styled lines, using plain text")
}
```

### 问题 3: 颜色不准确

**可能原因**:
1. RGB 转换错误
2. iTerm2 配色方案不匹配

**验证步骤**:
```swift
// 在 TerminalCharacterView 中打印颜色值
.onAppear {
    if let fg = character.fgColor {
        print("Char '\(character.char)' FG: R=\(fg.r) G=\(fg.g) B=\(fg.b)")
    }
}
```

### 问题 4: 性能问题（卡顿）

**优化建议**:
1. 减少轮询频率（Python 脚本中的 `await asyncio.sleep(0.2)`）
2. 限制传输行数（当前最多 100 行）
3. 使用更简单的 UI 布局

## 测试报告模板

```markdown
## 测试报告

**测试日期**: 2025-11-18
**测试环境**:
- macOS 版本:
- iOS 版本/模拟器:
- iTerm2 版本:
- Xcode 版本:

### 功能测试

| 测试项 | 预期结果 | 实际结果 | 状态 |
|--------|---------|---------|------|
| 基础颜色渲染 | 红绿蓝等颜色正确显示 | | ✅/❌ |
| 背景色 | 背景色正确应用 | | ✅/❌ |
| 粗体 | 文字加粗 | | ✅/❌ |
| 斜体 | 文字倾斜 | | ✅/❌ |
| 下划线 | 下划线显示 | | ✅/❌ |
| 256 色 | 扩展调色板颜色准确 | | ✅/❌ |
| RGB True Color | RGB 颜色精确 | | ✅/❌ |
| 实时更新 | 200ms 内更新 | | ✅/❌ |

### 性能测试

| 指标 | 目标 | 实际 | 状态 |
|-----|-----|------|------|
| 内存使用 | < 100MB | | ✅/❌ |
| CPU 使用 | < 10% | | ✅/❌ |
| 延迟 | < 500ms | | ✅/❌ |
| 帧率 | > 30fps | | ✅/❌ |

### 问题记录

1. **问题描述**:
   - 重现步骤:
   - 错误信息:
   - 解决方案:

### 总结

- 主要成就:
- 发现的问题:
- 后续改进建议:
```

## 自动化测试脚本

创建测试脚本 `test_8_colors.swift`:

```bash
cd /Users/maxwin/workspace/Grind/Grind-macOS
cat > test_8_colors.swift << 'EOF'
#!/usr/bin/env swift

import Foundation

print("Testing 8 basic ANSI colors...")
print("")

let colors = [
    (30, "Black"),
    (31, "Red"),
    (32, "Green"),
    (33, "Yellow"),
    (34, "Blue"),
    (35, "Magenta"),
    (36, "Cyan"),
    (37, "White")
]

for (code, name) in colors {
    print("\u{001B}[\(code)m■ \(name)\u{001B}[0m")
}

print("")
print("Testing styles...")
print("\u{001B}[1mBold\u{001B}[0m")
print("\u{001B}[3mItalic\u{001B}[0m")
print("\u{001B}[4mUnderline\u{001B}[0m")
EOF

chmod +x test_8_colors.swift
swift test_8_colors.swift
```

---

**祝测试顺利！** 🎨✨
