#!/bin/bash -v
# 挂盘到/disk1
cat >> /root/InitDataDisk.sh << "EOF"
#!/bin/bash
echo "p
n
p
w
" |  fdisk -u /dev/vdb
EOF
/bin/bash /root/InitDataDisk.sh
rm -f /root/InitDataDisk.sh
mkfs -t ext4 /dev/vdb1
cp /etc/fstab /etc/fstab.bak
mkdir /disk1
echo `blkid /dev/vdb1 | awk '{print $2}' | sed 's/\\\"//g'` /disk1 ext4 defaults 0 0 >> /etc/fstab
mount -a
# 这里配置安装脚本
apt-get install -y nginx
# 配置启动脚本
/usr/sbin/nginx
