#!/bin/bash
# macOS 初始化配置脚本（安全、常用项）

echo "配置 macOS 系统偏好..."

# 显示完整 POSIX 路径
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# 禁用 Dashboard
defaults write com.apple.dashboard mcx-disabled -bool true

# 调整 Dock 自动隐藏延迟
defaults write com.apple.Dock autohide-delay -float 0

# Finder 显示状态栏和路径栏
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true

# 重启 Finder 生效
killall Finder

echo "配置完成。部分设置需重启应用生效。"