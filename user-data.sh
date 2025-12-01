#!/bin/bash
# 确保脚本以 root 权限执行
set -e  # 遇到错误立即退出，避免后续无效执行

# 1. 更新 apt 源（Ubuntu 必须先更新，否则可能找不到最新包）
apt update -y

# 2. 安装 Nginx（Ubuntu 22.04 官方源直接支持）
apt install nginx -y

# 3. 启动 Nginx 并设置开机自启
systemctl start nginx
systemctl enable nginx

# 4. 验证 Nginx 状态（可选，方便后续排查）
if systemctl is-active --quiet nginx; then
  echo "Nginx 安装并启动成功" >> /var/log/nginx_install.log
else
  echo "Nginx 启动失败" >> /var/log/nginx_install.log
fi
