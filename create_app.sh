#!/bin/bash

# 黄豆输入法 - 创建App Bundle脚本

APP_NAME="黄豆输入法"
BUNDLE_ID="com.huangdou.inputmethod"
VERSION="1.0"

# 清理之前的构建
rm -rf "${APP_NAME}.app"


# 创建App目录结构
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"

# 复制可执行文件
cp "黄豆输入法" "${APP_NAME}.app/Contents/MacOS/"

# 创建Info.plist
cat > "${APP_NAME}.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>黄豆输入法</string>
    <key>CFBundleIdentifier</key>
    <string>com.huangdou.inputmethod</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>黄豆输入法</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2024 黄豆输入法</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>此应用需要辅助功能权限来监听键盘快捷键，以便触发语音输入。</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# 复制图标文件
cp Icon.icns "${APP_NAME}.app/Contents/Resources/AppIcon.icns"

# 设置权限
chmod +x "${APP_NAME}.app/Contents/MacOS/黄豆输入法"

# 临时签名
codesign --force --deep --sign - "${APP_NAME}.app"

echo ""
echo "=========================================="
echo "构建完成！"
echo "App位置: $(pwd)/${APP_NAME}.app"
echo "=========================================="
echo ""
echo "使用说明："
echo "1. 将 ${APP_NAME}.app 拖到 Applications 文件夹"
echo "2. 首次运行需要在 系统设置 > 隐私与安全性 > 辅助功能 中授权"
echo "3. 确保豆包App已安装，并设置语音输入快捷键为 Control+D"
echo ""
echo "快捷键选项（点击菜单栏图标切换）："
echo "  - 左Command键"
echo "  - 右Command键（默认）"
echo "  - 左Option键"
echo "  - 右Option键"
echo ""
