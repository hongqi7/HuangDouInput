//
//  黄豆输入法 - Swift版本
//  原生macOS App，零Python依赖
//

import Cocoa
import Carbon
import CoreGraphics
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isRecording = false
    var originalClipboard: String?

    // 快捷键选项
    var useLeftCommand = false
    var useRightCommand = true
    var useLeftOption = false
    var useRightOption = false

    // 延迟设置
    var coldStartDelay: Double = 3.5  // 冷启动延迟（第一次使用）
    var normalDelay: Double = 3.0     // 正常延迟（后续使用）
    var isFirstUse: Bool = true       // 是否为冷启动

    // 长按检测
    var longPressTimer: DispatchWorkItem?
    var longPressThreshold: Double = 0.5  // 长按阈值（秒）

    // 防连击：延迟回车任务（可取消）
    var pendingEnterWorkItem: DispatchWorkItem?

    // 合成事件标记（通过 event userData 区分自己模拟的按键）
    let syntheticEventMarker: Int64 = 0x484449

    // 事件监听
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 从 UserDefaults 读取设置
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "coldStartDelay") != nil {
            coldStartDelay = defaults.double(forKey: "coldStartDelay")
        }
        if defaults.object(forKey: "normalDelay") != nil {
            normalDelay = defaults.double(forKey: "normalDelay")
        }
        if defaults.object(forKey: "longPressThreshold") != nil {
            longPressThreshold = defaults.double(forKey: "longPressThreshold")
        }

        // 从 UserDefaults 读取快捷键设置，默认为右Command键(tag=2)
        let savedShortcut = defaults.object(forKey: "shortcutTag") != nil ? defaults.integer(forKey: "shortcutTag") : 2
        useLeftCommand = (savedShortcut == 1)
        useRightCommand = (savedShortcut == 2)
        useLeftOption = (savedShortcut == 3)
        useRightOption = (savedShortcut == 4)

        setupMenuBar()
        setupKeyboardMonitor()
        requestAccessibilityPermission()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🎤"

        let menu = NSMenu()

        // 标题
        let titleItem = NSMenuItem(title: "黄豆输入法 v1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // 快捷键选项
        menu.addItem(createShortcutMenuItem(title: "左Command键", shortcut: .leftCommand))
        menu.addItem(createShortcutMenuItem(title: "右Command键", shortcut: .rightCommand))
        menu.addItem(createShortcutMenuItem(title: "左Option键", shortcut: .leftOption))
        menu.addItem(createShortcutMenuItem(title: "右Option键", shortcut: .rightOption))

        menu.addItem(NSMenuItem.separator())

        // 延迟设置
        let delayTitle = NSMenuItem(title: "延迟设置", action: nil, keyEquivalent: "")
        delayTitle.isEnabled = false
        menu.addItem(delayTitle)

        // 冷启动延迟子菜单
        let coldStartItem = NSMenuItem(title: "冷启动延迟（第一次使用）: \(String(format: "%.1f", coldStartDelay)) 秒", action: nil, keyEquivalent: "")
        coldStartItem.tag = 100
        let coldStartSubmenu = NSMenu()
        for value in stride(from: 0.5, through: 6.0, by: 0.5) {
            let option = NSMenuItem(title: "\(String(format: "%.1f", value)) 秒", action: #selector(coldStartDelaySelected(_:)), keyEquivalent: "")
            option.target = self
            option.tag = Int(value * 10)
            option.state = (abs(value - coldStartDelay) < 0.01) ? .on : .off
            coldStartSubmenu.addItem(option)
        }
        coldStartSubmenu.addItem(NSMenuItem.separator())
        let coldCustom = NSMenuItem(title: "自定义...", action: #selector(customColdStartDelay), keyEquivalent: "")
        coldCustom.target = self
        coldStartSubmenu.addItem(coldCustom)
        coldStartItem.submenu = coldStartSubmenu
        menu.addItem(coldStartItem)

        // 正常延迟子菜单
        let normalDelayItem = NSMenuItem(title: "正常延迟（后续使用）: \(String(format: "%.1f", normalDelay)) 秒", action: nil, keyEquivalent: "")
        normalDelayItem.tag = 101
        let normalDelaySubmenu = NSMenu()
        for value in stride(from: 0.5, through: 6.0, by: 0.5) {
            let option = NSMenuItem(title: "\(String(format: "%.1f", value)) 秒", action: #selector(normalDelaySelected(_:)), keyEquivalent: "")
            option.target = self
            option.tag = Int(value * 10)
            option.state = (abs(value - normalDelay) < 0.01) ? .on : .off
            normalDelaySubmenu.addItem(option)
        }
        normalDelaySubmenu.addItem(NSMenuItem.separator())
        let normalCustom = NSMenuItem(title: "自定义...", action: #selector(customNormalDelay), keyEquivalent: "")
        normalCustom.target = self
        normalDelaySubmenu.addItem(normalCustom)
        normalDelayItem.submenu = normalDelaySubmenu
        menu.addItem(normalDelayItem)

        // 触发时间（长按阈值）子菜单
        let thresholdItem = NSMenuItem(title: "触发时间（长按阈值）: \(String(format: "%.1f", longPressThreshold)) 秒", action: nil, keyEquivalent: "")
        thresholdItem.tag = 102
        let thresholdSubmenu = NSMenu()
        for value in [0.3, 0.5, 0.8, 1.0, 1.5, 2.0] {
            let option = NSMenuItem(title: "\(String(format: "%.1f", value)) 秒", action: #selector(thresholdSelected(_:)), keyEquivalent: "")
            option.target = self
            option.tag = Int(value * 10)
            option.state = (abs(value - longPressThreshold) < 0.01) ? .on : .off
            thresholdSubmenu.addItem(option)
        }
        thresholdSubmenu.addItem(NSMenuItem.separator())
        let thresholdCustom = NSMenuItem(title: "自定义...", action: #selector(customThreshold), keyEquivalent: "")
        thresholdCustom.target = self
        thresholdSubmenu.addItem(thresholdCustom)
        thresholdItem.submenu = thresholdSubmenu
        menu.addItem(thresholdItem)

        menu.addItem(NSMenuItem.separator())

        // 开机自启动
        let autoLaunchItem = NSMenuItem(title: "开机自启动", action: #selector(toggleAutoLaunch(_:)), keyEquivalent: "")
        autoLaunchItem.target = self
        autoLaunchItem.tag = 200
        autoLaunchItem.state = isAutoLaunchEnabled() ? .on : .off
        menu.addItem(autoLaunchItem)

        menu.addItem(NSMenuItem.separator())

        // 使用说明
        let helpItem = NSMenuItem(title: "使用说明", action: #selector(showHelp), keyEquivalent: "")
        menu.addItem(helpItem)

        menu.addItem(NSMenuItem.separator())

        // 退出
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    enum ShortcutType {
        case leftCommand, rightCommand, leftOption, rightOption
    }

    func createShortcutMenuItem(title: String, shortcut: ShortcutType) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(shortcutSelected(_:)), keyEquivalent: "")
        item.target = self

        // 设置tag来标识快捷键类型
        switch shortcut {
        case .leftCommand: item.tag = 1
        case .rightCommand: item.tag = 2
        case .leftOption: item.tag = 3
        case .rightOption: item.tag = 4
        }

        // 设置初始状态
        updateMenuItemState(item)

        return item
    }

    func updateMenuItemState(_ item: NSMenuItem) {
        let isSelected: Bool
        switch item.tag {
        case 1: isSelected = useLeftCommand
        case 2: isSelected = useRightCommand
        case 3: isSelected = useLeftOption
        case 4: isSelected = useRightOption
        default: isSelected = false
        }
        item.state = isSelected ? .on : .off
    }

    @objc func shortcutSelected(_ sender: NSMenuItem) {
        // 重置所有选项
        useLeftCommand = false
        useRightCommand = false
        useLeftOption = false
        useRightOption = false

        // 设置选中的选项
        switch sender.tag {
        case 1: useLeftCommand = true
        case 2: useRightCommand = true
        case 3: useLeftOption = true
        case 4: useRightOption = true
        default: break
        }

        // 保存到 UserDefaults
        UserDefaults.standard.set(sender.tag, forKey: "shortcutTag")

        // 更新菜单状态
        if let menu = statusItem.menu {
            for i in 0..<menu.items.count {
                if let item = menu.item(at: i), item.tag >= 1 && item.tag <= 4 {
                    updateMenuItemState(item)
                }
            }
        }
    }

    @objc func coldStartDelaySelected(_ sender: NSMenuItem) {
        coldStartDelay = Double(sender.tag) / 10.0
        UserDefaults.standard.set(coldStartDelay, forKey: "coldStartDelay")
        updateDelayMenus()
    }

    @objc func normalDelaySelected(_ sender: NSMenuItem) {
        normalDelay = Double(sender.tag) / 10.0
        UserDefaults.standard.set(normalDelay, forKey: "normalDelay")
        updateDelayMenus()
    }

    @objc func thresholdSelected(_ sender: NSMenuItem) {
        longPressThreshold = Double(sender.tag) / 10.0
        UserDefaults.standard.set(longPressThreshold, forKey: "longPressThreshold")
        updateDelayMenus()
    }

    @objc func customThreshold() {
        if let value = showCustomDelayDialog(title: "自定义触发时间（长按阈值）", current: longPressThreshold) {
            longPressThreshold = value
            UserDefaults.standard.set(longPressThreshold, forKey: "longPressThreshold")
            updateDelayMenus()
        }
    }

    @objc func customColdStartDelay() {
        if let value = showCustomDelayDialog(title: "自定义冷启动延迟", current: coldStartDelay) {
            coldStartDelay = value
            UserDefaults.standard.set(coldStartDelay, forKey: "coldStartDelay")
            updateDelayMenus()
        }
    }

    @objc func customNormalDelay() {
        if let value = showCustomDelayDialog(title: "自定义正常延迟", current: normalDelay) {
            normalDelay = value
            UserDefaults.standard.set(normalDelay, forKey: "normalDelay")
            updateDelayMenus()
        }
    }

    func showCustomDelayDialog(title: String, current: Double) -> Double? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "请输入延迟时间（秒），范围 0.1 ~ 10.0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = String(format: "%.1f", current)
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            if let value = Double(input.stringValue), value >= 0.1, value <= 10.0 {
                return value
            }
        }
        return nil
    }

    func updateDelayMenus() {
        guard let menu = statusItem.menu else { return }
        // 更新冷启动延迟
        if let coldItem = menu.item(withTag: 100) {
            coldItem.title = "冷启动延迟（第一次使用）: \(String(format: "%.1f", coldStartDelay)) 秒"
            if let submenu = coldItem.submenu {
                for item in submenu.items {
                    if item.tag > 0 {
                        item.state = (abs(Double(item.tag) / 10.0 - coldStartDelay) < 0.01) ? .on : .off
                    }
                }
            }
        }
        // 更新正常延迟
        if let normalItem = menu.item(withTag: 101) {
            normalItem.title = "正常延迟（后续使用）: \(String(format: "%.1f", normalDelay)) 秒"
            if let submenu = normalItem.submenu {
                for item in submenu.items {
                    if item.tag > 0 {
                        item.state = (abs(Double(item.tag) / 10.0 - normalDelay) < 0.01) ? .on : .off
                    }
                }
            }
        }
        // 更新触发时间
        if let thresholdItem = menu.item(withTag: 102) {
            thresholdItem.title = "触发时间（长按阈值）: \(String(format: "%.1f", longPressThreshold)) 秒"
            if let submenu = thresholdItem.submenu {
                for item in submenu.items {
                    if item.tag > 0 {
                        item.state = (abs(Double(item.tag) / 10.0 - longPressThreshold) < 0.01) ? .on : .off
                    }
                }
            }
        }
    }

    @objc func showHelp() {
        let alert = NSAlert()
        alert.messageText = "黄豆输入法 - 使用说明"
        alert.informativeText = """
        1. 确保豆包App已安装并登录
        2. 在豆包设置中将语音输入快捷键设为 Control+D
        3. 选择你想要的快捷键（左/右 Command 或 Option）
        4. 按住选择的键说话，松开后自动插入文字
        5. 剪贴板内容会被保护，不会被覆盖

        注意：首次使用需要在系统设置中授予辅助功能权限。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - 开机自启动

    func getLaunchAgentPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/LaunchAgents/com.huangdou.inputmethod.plist"
    }

    func isAutoLaunchEnabled() -> Bool {
        return FileManager.default.fileExists(atPath: getLaunchAgentPath())
    }

    @objc func toggleAutoLaunch(_ sender: NSMenuItem) {
        if isAutoLaunchEnabled() {
            // 关闭自启动
            try? FileManager.default.removeItem(atPath: getLaunchAgentPath())
            sender.state = .off
        } else {
            // 开启自启动
            let appPath = Bundle.main.bundlePath
            let plist: [String: Any] = [
                "Label": "com.huangdou.inputmethod",
                "ProgramArguments": ["\(appPath)/Contents/MacOS/黄豆输入法"],
                "RunAtLoad": true,
                "KeepAlive": false
            ]

            let launchAgentsDir = (getLaunchAgentPath() as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)

            let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            FileManager.default.createFile(atPath: getLaunchAgentPath(), contents: data)
            sender.state = .on
        }
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessibilityEnabled {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "请在系统设置中授予此应用辅助功能权限，以便监听键盘快捷键。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")

            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    func setupKeyboardMonitor() {
        // 创建事件监听
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                return delegate.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("无法创建事件监听，请检查辅助功能权限")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 如果是自己模拟发出的按键（通过 userData 标记），直接放行不处理
        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        // 如果按了其他键（快捷键组合），取消长按计时器
        if type == .keyDown {
            if let timer = longPressTimer {
                timer.cancel()
                longPressTimer = nil
            }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags

        // 检测左右修饰键
        let isCommand = flags.contains(.maskCommand)
        let isOption = flags.contains(.maskAlternate)

        // 通过检查特定位来区分左右键
        let isRightCommand = isCommand && (flags.rawValue & 0x00000010 != 0)
        let isLeftCommand = isCommand && !isRightCommand
        let isRightOption = isOption && (flags.rawValue & 0x00000040 != 0)
        let isLeftOption = isOption && !isRightOption

        // 判断是否触发
        var shouldTrigger = false
        if useLeftCommand && isLeftCommand { shouldTrigger = true }
        if useRightCommand && isRightCommand { shouldTrigger = true }
        if useLeftOption && isLeftOption { shouldTrigger = true }
        if useRightOption && isRightOption { shouldTrigger = true }

        if type == .flagsChanged {
            if shouldTrigger && !isRecording && longPressTimer == nil {
                // 新的按压开始，取消上一次还在排队的回车任务（防连击）
                if let pendingEnter = pendingEnterWorkItem {
                    pendingEnter.cancel()
                    pendingEnterWorkItem = nil
                }

                // 按下修饰键：启动长按定时器
                let timer = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.longPressTimer = nil
                    self.startRecording()
                }
                longPressTimer = timer
                DispatchQueue.main.asyncAfter(deadline: .now() + longPressThreshold, execute: timer)
            } else if !shouldTrigger {
                // 松开修饰键
                if let timer = longPressTimer {
                    // 短按：取消定时器，不触发录音
                    timer.cancel()
                    longPressTimer = nil
                } else if isRecording {
                    // 长按后松开：正常停止录音
                    stopRecording()
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    func startRecording() {
        isRecording = true
        statusItem.button?.title = "🔴"

        // 保存当前剪贴板
        let pasteboard = NSPasteboard.general
        if let content = pasteboard.string(forType: .string) {
            originalClipboard = content
        }

        // 触发豆包语音输入 (Control+D)
        let source = CGEventSource(stateID: .combinedSessionState)

        // Control键按下
        let controlDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(59), keyDown: true)
        controlDown?.flags = .maskControl
        controlDown?.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        controlDown?.post(tap: .cghidEventTap)

        // D键按下
        let dDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(2), keyDown: true)
        dDown?.flags = .maskControl
        dDown?.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        dDown?.post(tap: .cghidEventTap)

        // D键释放
        let dUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(2), keyDown: false)
        dUp?.flags = .maskControl
        dUp?.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        dUp?.post(tap: .cghidEventTap)

        // Control键释放
        let controlUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(59), keyDown: false)
        controlUp?.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        controlUp?.post(tap: .cghidEventTap)
    }

    func stopRecording() {
        isRecording = false
        statusItem.button?.title = "🎤"

        // 根据是否冷启动选择延迟时间
        let delay = isFirstUse ? coldStartDelay : normalDelay
        if isFirstUse {
            isFirstUse = false
        }

        // 用 DispatchWorkItem 包装回车任务，以便可以被取消（防连击）
        let enterTask = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // 按Enter键插入文字
            let source = CGEventSource(stateID: .combinedSessionState)
            let enterDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(36), keyDown: true)
            let enterUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(36), keyDown: false)
            enterDown?.setIntegerValueField(.eventSourceUserData, value: self.syntheticEventMarker)
            enterUp?.setIntegerValueField(.eventSourceUserData, value: self.syntheticEventMarker)
            enterDown?.post(tap: .cghidEventTap)
            enterUp?.post(tap: .cghidEventTap)

            // 任务完成，清空引用
            self.pendingEnterWorkItem = nil

            // 再延迟一点，恢复原始剪贴板内容
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let original = self.originalClipboard {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(original, forType: .string)
                }
            }
        }

        pendingEnterWorkItem = enterTask
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: enterTask)
    }
}

// 主程序入口
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
