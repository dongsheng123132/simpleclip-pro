#!/bin/bash
# SimpleClip 一键安装脚本
# 用法: curl -fsSL https://raw.githubusercontent.com/dongsheng123132/simpleclip-pro/main/install.sh | bash

set -e

APP_NAME="SimpleClip"
REPO="dongsheng123132/simpleclip-pro"
INSTALL_DIR="/Applications"

echo "==> 正在获取最新版本..."
LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
    echo "❌ 无法获取最新版本，请检查网络连接"
    exit 1
fi

DMG_NAME="${APP_NAME}-${LATEST_TAG}.dmg"
DMG_URL="https://github.com/$REPO/releases/download/${LATEST_TAG}/${DMG_NAME}"
TMP_DMG="/tmp/${DMG_NAME}"

echo "==> 最新版本: $LATEST_TAG"
echo "==> 正在下载 $DMG_NAME ..."
curl -fSL "$DMG_URL" -o "$TMP_DMG"

echo "==> 正在挂载 DMG..."
MOUNT_POINT=$(hdiutil attach "$TMP_DMG" -nobrowse -noautoopen 2>/dev/null | grep "/Volumes" | awk -F'\t' '{print $NF}')

if [ -z "$MOUNT_POINT" ]; then
    echo "❌ DMG 挂载失败"
    rm -f "$TMP_DMG"
    exit 1
fi

echo "==> 正在安装到 $INSTALL_DIR ..."
# 关闭正在运行的 SimpleClip
killall SimpleClip 2>/dev/null || true
sleep 1

# 删除旧版本
rm -rf "$INSTALL_DIR/$APP_NAME.app"

# 复制新版本
cp -R "$MOUNT_POINT/$APP_NAME.app" "$INSTALL_DIR/"

echo "==> 正在处理安全设置..."
xattr -cr "$INSTALL_DIR/$APP_NAME.app"

echo "==> 正在清理..."
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
rm -f "$TMP_DMG"

echo ""
echo "✅ $APP_NAME $LATEST_TAG 安装成功！"
echo ""
echo "==> 正在启动 $APP_NAME ..."
open "$INSTALL_DIR/$APP_NAME.app"
