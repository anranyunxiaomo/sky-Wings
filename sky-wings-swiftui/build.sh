#!/bin/bash

# 设置变量
APP_NAME="Sky Wings"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "清理旧版本..."
rm -rf "$APP_DIR"

echo "创建 App 目录结构..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "写入 Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SkyWings</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh_CN</string>
        <string>zh-Hans</string>
    </array>
    <key>CFBundleIdentifier</key>
    <string>com.xiaomo.skywings</string>
    <key>CFBundleName</key>
    <string>Sky Wings</string>
    <key>CFBundleDisplayName</key>
    <string>云端之翼</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
EOF

echo "复制核心资源文件..."
cp assets/ion-dist-en-US-fully-translated.json "$RESOURCES_DIR/"
cp assets/codex-engine "$MACOS_DIR/"
chmod +x "$MACOS_DIR/codex-engine"

echo "生成多分辨率高清图标包..."
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

# 生成各种尺寸的图标以适配 Retina 屏幕
sips -z 16 16   assets/icon.png --out "$ICONSET_DIR/icon_16x16.png" > /dev/null 2>&1
sips -z 32 32   assets/icon.png --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null 2>&1
sips -z 32 32   assets/icon.png --out "$ICONSET_DIR/icon_32x32.png" > /dev/null 2>&1
sips -z 64 64   assets/icon.png --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null 2>&1
sips -z 128 128 assets/icon.png --out "$ICONSET_DIR/icon_128x128.png" > /dev/null 2>&1
sips -z 256 256 assets/icon.png --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 256 256 assets/icon.png --out "$ICONSET_DIR/icon_256x256.png" > /dev/null 2>&1
sips -z 512 512 assets/icon.png --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 512 512 assets/icon.png --out "$ICONSET_DIR/icon_512x512.png" > /dev/null 2>&1
sips -z 1024 1024 assets/icon.png --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1

# 使用 iconutil 合并为标准的 icns 文件
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR"

echo "编译 Swift 代码..."
swiftc -parse-as-library -framework SwiftUI -framework AppKit Sources/*.swift -o "$MACOS_DIR/SkyWings"

echo "对 $APP_NAME 进行本地重签..."
codesign -f -s - "$APP_DIR"

# 强制刷新 Finder 缓存
touch "$APP_DIR"

echo "打包完成！应用位于: $APP_DIR"

echo "正在生成用于分发的专业 DMG 安装包..."
mkdir -p build_dmg
cp -R "$APP_DIR" build_dmg/
ln -s /Applications build_dmg/Applications
hdiutil create -volname "$APP_NAME" -srcfolder build_dmg -ov -format UDZO "$APP_NAME.dmg" > /dev/null
rm -rf build_dmg
echo "📦 DMG 安装包已生成: $APP_NAME.dmg"
