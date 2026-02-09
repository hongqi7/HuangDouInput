#!/usr/bin/env python3
"""
创建macOS App图标
将SVG转换为icns格式
"""

import subprocess
import os
import tempfile
import shutil

def create_icns_from_svg(svg_path, output_name="Icon"):
    """使用sips和iconutil创建icns文件"""

    # 创建临时目录
    with tempfile.TemporaryDirectory() as tmpdir:
        iconset_dir = os.path.join(tmpdir, f"{output_name}.iconset")
        os.makedirs(iconset_dir)

        # 需要生成的尺寸
        sizes = [16, 32, 128, 256, 512]

        print("生成图标尺寸...")
        for size in sizes:
            # 1x 版本
            output_file = os.path.join(iconset_dir, f"icon_{size}x{size}.png")
            cmd = [
                "sips",
                "-z", str(size), str(size),
                svg_path,
                "--out", output_file
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"警告: 生成 {size}x{size} 失败: {result.stderr}")
            else:
                print(f"  ✓ {size}x{size}")

            # 2x 版本 (除了512，因为1024可能有问题)
            if size < 512:
                output_file2x = os.path.join(iconset_dir, f"icon_{size}x{size}@2x.png")
                cmd = [
                    "sips",
                    "-z", str(size * 2), str(size * 2),
                    svg_path,
                    "--out", output_file2x
                ]
                subprocess.run(cmd, capture_output=True)

        # 特殊处理512@2x (1024x1024)
        output_1024 = os.path.join(iconset_dir, "icon_512x512@2x.png")
        cmd = [
            "sips",
            "-z", "1024", "1024",
            svg_path,
            "--out", output_1024
        ]
        subprocess.run(cmd, capture_output=True)

        # 使用iconutil生成icns
        icns_path = f"{output_name}.icns"
        print(f"\n生成 {icns_path}...")

        cmd = ["iconutil", "-c", "icns", iconset_dir, "-o", icns_path]
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"错误: {result.stderr}")
            # 尝试备用方案：直接复制最大的png作为图标
            largest_png = os.path.join(iconset_dir, "icon_512x512.png")
            if os.path.exists(largest_png):
                shutil.copy(largest_png, f"{output_name}.png")
                print(f"已创建备用PNG图标: {output_name}.png")
            return False

        print(f"✓ 图标创建成功: {icns_path}")
        return True

if __name__ == "__main__":
    svg_file = "Icon.svg"
    if os.path.exists(svg_file):
        create_icns_from_svg(svg_file)
    else:
        print(f"错误: 找不到 {svg_file}")
