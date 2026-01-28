#!/bin/bash

# 配置备份目录 (默认在用户主目录下的 github_backups)
BACKUP_DIR="$HOME/github_backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

echo "🛡️  开始 GitHub 全量备份..."
echo "📂 备份目录: $BACKUP_DIR"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 检查 gh 登录状态
if ! gh auth status &> /dev/null; then
    echo "❌ 错误: GitHub CLI 未登录，请先运行 'gh auth login'"
    exit 1
fi

# 获取所有仓库列表 (包括私有)
echo "🔍 正在获取仓库列表..."
# 使用 sshUrl 以确保可以使用 SSH 密钥进行克隆（无需每次输入密码）
# 如果偏好 HTTPS，可以将 sshUrl 改为 url
REPOS=$(gh repo list --limit 1000 --json sshUrl,name,isPrivate --template '{{range .}}{{print .sshUrl}} {{print .name}} {{if .isPrivate}}[Private]{{else}}[Public]{{end}}{{"\n"}}{{end}}')

if [ -z "$REPOS" ]; then
    echo "⚠️  未找到任何仓库。"
    exit 0
fi

# 切换到备份目录
cd "$BACKUP_DIR" || exit

# 遍历处理每个仓库
echo "$REPOS" | while read -r repo_url repo_name repo_type; do
    if [ -z "$repo_name" ]; then continue; fi

    echo "---------------------------------------------------"
    echo "📦 处理仓库: $repo_name $repo_type"
    
    # 检查是否已存在镜像
    if [ -d "$repo_name.git" ]; then
        echo "🔄 更新现有镜像..."
        cd "$repo_name.git" || continue
        # 使用 git remote update 来拉取所有分支和标签
        if git remote update; then
            echo "✅ 更新成功"
        else
            echo "❌ 更新失败"
        fi
        cd ..
    else
        echo "⬇️  克隆新镜像 (Mirror Mode)..."
        # 使用 --mirror 选项确保备份所有分支、标签和 Git 数据
        if git clone --mirror "$repo_url"; then
            echo "✅ 克隆成功"
        else
            echo "❌ 克隆失败"
        fi
    fi
done

echo "---------------------------------------------------"
echo "🎉 备份完成！所有仓库已保存至 $BACKUP_DIR"
echo "💡 提示：你可以将此脚本添加到 crontab 实现每日自动备份"
