#!/bin/bash

# 定义路径
OLD_CONTAINER="$HOME/Library/Containers/-431.SimpleClip"
NEW_CONTAINER="$HOME/Library/Containers/com.hequbing.SimpleClip"

OLD_DATA_PATH="$OLD_CONTAINER/Data/Library/Application Support"
NEW_DATA_PATH="$NEW_CONTAINER/Data/Library/Application Support"

# 检查旧数据是否存在
if [ ! -d "$OLD_DATA_PATH" ]; then
    echo "❌ 错误：未找到旧数据目录：$OLD_DATA_PATH"
    echo "请确认之前是否运行过 Bundle ID 为 -431.SimpleClip 的版本。"
    exit 1
fi

# 检查新容器是否存在
if [ ! -d "$NEW_CONTAINER" ]; then
    echo "❌ 错误：未找到新 App 的容器目录。"
    echo "⚠️ 请先运行一次新的 SimpleClip Pro (com.hequbing.SimpleClip)，让系统自动创建容器目录。"
    exit 1
fi

# 确保新数据目录存在
mkdir -p "$NEW_DATA_PATH"

echo "📦 正在迁移数据..."
echo "从: $OLD_DATA_PATH"
echo "到: $NEW_DATA_PATH"

# 复制数据库文件
cp "$OLD_DATA_PATH/default.store"* "$NEW_DATA_PATH/" 2>/dev/null
echo "✅ 数据库文件已复制"

# 复制图片和其他资源 (如果存在 SimpleClip 子目录)
if [ -d "$OLD_DATA_PATH/SimpleClip" ]; then
    cp -R "$OLD_DATA_PATH/SimpleClip" "$NEW_DATA_PATH/"
    echo "✅ 图片资源已复制"
fi

echo "🎉 迁移成功！请重新启动 SimpleClip Pro，你应该能看到旧数据了。"
