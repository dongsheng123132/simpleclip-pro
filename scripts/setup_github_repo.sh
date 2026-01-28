#!/bin/bash

# 检查 gh 是否安装
if ! command -v gh &> /dev/null; then
    echo "❌ 错误: 未检测到 GitHub CLI (gh)。"
    echo "请先安装 gh: brew install gh"
    exit 1
fi

# 检查登录状态
if ! gh auth status &> /dev/null; then
    echo "⚠️  检测到你尚未登录 GitHub CLI。"
    echo "请按提示完成登录（只需一次，后续永久免登）："
    gh auth login
fi

# 获取当前目录名作为默认仓库名
REPO_NAME=$(basename "$PWD")

echo "🚀 准备创建私有仓库: $REPO_NAME"

# 检查仓库是否已存在（避免重复创建报错）
if gh repo view "$REPO_NAME" &> /dev/null; then
    echo "⚠️  仓库 '$REPO_NAME' 已存在。"
    echo "正在推送最新代码..."
else
    echo "📦 正在 GitHub 上创建私有仓库..."
    # 创建私有仓库并直接关联本地代码
    gh repo create "$REPO_NAME" --private --source=. --remote=origin
fi

# 推送代码
echo "⬆️  正在推送到 origin/main..."
git push -u origin main

echo "✅ 完成！项目已托管至 GitHub。"
echo "🔗 仓库地址: $(gh repo view --json url -q .url)"
