#!/bin/bash
set -e

# 1. 更新源 + 安装 Nginx
apt update -y
apt install nginx -y

# 2. 启动 Nginx 并设为开机自启
systemctl start nginx
systemctl enable nginx

# 3. 直接放行 22(SSH)、80(HTTP)、443(HTTPS) 端口（ufw 防火墙）
apt install ufw -y  # 确保 ufw 已安装
ufw enable -y       # 启用防火墙（-y 自动确认）
ufw allow 22/tcp    # 放行 SSH
ufw allow 80/tcp    # 放行 HTTP
ufw allow 443/tcp   # 放行 HTTPS

# 验证结果（可选，查看端口放行状态）
echo "防火墙放行端口状态："
ufw status
echo "Nginx 状态：$(systemctl is-active nginx)"
