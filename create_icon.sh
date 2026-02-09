#!/bin/bash

# 创建App图标脚本
# 将SVG转换为macOS .icns格式

ICON_NAME="Icon"
ICONSET_DIR="Icon.iconset"

# 清理旧文件
rm -rf "${ICONSET_DIR}"
rm -f "${ICON_NAME}.icns"

# 创建iconset目录
mkdir -p "${ICONSET_DIR}"

# 检查是否有rsvg-convert或sips
if command -v rsvg-convert &> /dev/null; then
    echo "使用 rsvg-convert 转换图标..."
    # 生成各种尺寸的图标
    for size in 16 32 64 128 256 512; do
        double_size=$((size * 2))
        rsvg-convert -w ${size} -h ${size} "${ICON_NAME}.svg" -o "${ICONSET_DIR}/icon_${size}x${size}.png"
        rsvg-convert -w ${double_size} -h ${double_size} "${ICON_NAME}.svg" -o "${ICONSET_DIR}/icon_${size}x${size}@2x.png"
    done
elif command -v qlmanage &> /dev/null; then
    echo "使用 qlmanage 生成图标..."
    # 使用macOS自带的quicklook生成预览
    for size in 16 32 128 256 512; do
        sips -z ${size} ${size} "${ICON_NAME}.svg" --out "${ICONSET_DIR}/icon_${size}x${size}.png" 2>/dev/null || \
        cp "${ICON_NAME}.svg" "${ICONSET_DIR}/icon_${size}x${size}.png"
    done
else
    echo "警告: 没有找到合适的图标转换工具"
    echo "将使用占位方式创建图标..."
fi

# 使用iconutil生成icns
if command -v iconutil &> /dev/null; then
    iconutil -c icns "${ICONSET_DIR}" -o "${ICON_NAME}.icns"
    echo "图标创建成功: ${ICON_NAME}.icns"
else
    echo "错误: 没有找到 iconutil"
    exit 1
fi

# 清理临时文件
rm -rf "${ICONSET_DIR}"

echo "完成!"
