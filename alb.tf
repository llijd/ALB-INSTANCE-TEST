# ==============================
# 1. Terraform 版本与 Provider 约束
# ==============================
terraform {
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = ">= 1.200.0"
    }
  }
}

# ==============================
# 2. 阿里云 Provider 配置
# ==============================
provider "alicloud" {
  region = "cn-beijing"  # 按需修改地域
  
  # PowerShell: $env:ALICLOUD_ACCESS_KEY="你的AK"; $env:ALICLOUD_SECRET_KEY="你的SK"
}

# ==============================
# 3. 自定义变量（修复变量名+补充缺失变量）
# ==============================
variable "ecs_login_password" {
  type        = string
  default     = "Admin@123456"  # 符合阿里云密码规范（大写+小写+数字+特殊符）
  description = "ECS 登录密码"
}

variable "name_prefix" {
  type        = string
  default     = "test"
  description = "所有资源的名称前缀"
}

variable "instance_type" {
  type        = string
  default     = "ecs.e-c1m1.large"
  description = "ECS 实例规格（确保当前地域支持该规格）"
}

# 修复1：变量名统一为复数（target_zone_ids），与引用一致
variable "target_zone_ids" {
  type        = list(string)
  default     = ["cn-beijing-a", "cn-beijing-c"]  # 两个不同可用区
  description = "可用区列表（每个可用区部署1个子网+1台ECS）"
}

# 修复2：补充 vpc_cidr 变量（子网网段计算需要）
variable "vpc_cidr" {
  type        = string
  default     = "172.16.0.0/12"
  description = "VPC 主网段（子网从该网段拆分）"
}

variable "image_id" {
  type        = string
  default     = "ubuntu_22_04_x64_20G_alibase_20251103.vhd"
  description = "ECS 镜像 ID（Ubuntu 22.04 官方镜像，确保地域支持）"
}

# ==============================
# 4. 基础资源：VPC
# ==============================
resource "alicloud_vpc" "main" {
  vpc_name   = "${var.name_prefix}-vpc"
  cidr_block = var.vpc_cidr  # 引用变量（与子网计算逻辑一致）
  tags = {
    Name = "${var.name_prefix}-vpc"
    Env  = "test"
  }
}

# ==============================
# 5. 双可用区子网（循环创建两个子网，引用修复后的变量）
# ==============================
resource "alicloud_vswitch" "main" {
  count = length(var.target_zone_ids)  # 循环次数=可用区数量（2次）

  vpc_id     = alicloud_vpc.main.id
  # 子网网段：基于 VPC 网段自动拆分，无冲突（0→172.16.0.0/21，1→172.16.8.0/21）
  cidr_block = cidrsubnet(var.vpc_cidr, 9, count.index)
  zone_id    = var.target_zone_ids[count.index]  # 引用修复后的复数变量
  vswitch_name = "${var.name_prefix}-vsw-${var.target_zone_ids[count.index]}"  # 复数变量

  tags = {
    Name        = "${var.name_prefix}-vsw-${var.target_zone_ids[count.index]}"  # 复数变量
    Env         = "test"
    ZoneId      = var.target_zone_ids[count.index]  # 复数变量
    SubnetIndex = count.index
  }
}

# ==============================
# 6. 安全组（放行内网 SSH/HTTP/HTTPS）
# ==============================
resource "alicloud_security_group" "main" {
  security_group_name = "${var.name_prefix}-sg"
  vpc_id              = alicloud_vpc.main.id
  tags = {
    Name = "${var.name_prefix}-sg"
    Env  = "test"
  }
}

# 规则1：放行内网 SSH（22端口，仅VPC内访问）
resource "alicloud_security_group_rule" "allow_intranet_ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = 0.0.0.0/0
}

# 规则2：放行内网 HTTP（80端口）
resource "alicloud_security_group_rule" "allow_intranet_http" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 2
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = 0.0.0.0/0
}

# 规则3：放行内网 HTTPS（443端口）
resource "alicloud_security_group_rule" "allow_intranet_https" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "443/443"
  priority          = 3
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = 0.0.0.0/0
}

# 规则4：放行内网出方向流量
resource "alicloud_security_group_rule" "allow_intranet_egress" {
  type              = "egress"
  ip_protocol       = "all"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "-1/-1"
  priority          = 1
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = "0.0.0.0/0"
}

# ==============================
# 7. 多可用区 ECS 实例（每个子网1台）
# ==============================
resource "alicloud_instance" "main" {
  count = length(alicloud_vswitch.main)  # ECS数量=子网数量（2台）

  # ECS名称：拼接序号+可用区，避免冲突
  instance_name = "${var.name_prefix}-instance-${count.index}-${var.target_zone_ids[count.index]}"  # 复数变量
  availability_zone = var.target_zone_ids[count.index]  # 复数变量
  instance_type = var.instance_type

  # 系统盘配置
  system_disk_category = "cloud_essd_entry"
  system_disk_size     = 40

  # 网络配置：绑定对应子网
  vswitch_id                 = alicloud_vswitch.main[count.index].id
  security_groups            = [alicloud_security_group.main.id]
  internet_max_bandwidth_out = 0  # 无公网IP
  internet_charge_type       = "PayByTraffic"

  # 镜像与登录配置
  image_id = var.image_id
  password = var.ecs_login_password
  password_inherit = false

  # 计费与保护
  instance_charge_type = "PostPaid"  # 按量付费
  deletion_protection  = false       # 按需开启（true=禁止误删）
  user_data            = file("${path.cwd}/user-data.sh")
}  # 修复：添加缺失的闭合大括号

# ==============================
# 8. 输出信息（部署后查看）
# ==============================
# 修复：删除无效的 nginx_ip 输出（原引用错误且ECS无公网IP）
# 如需访问Nginx，可通过VPC内网或后续配置ALB实现

output "ecs_instances_info" {
  value = [
    for idx, instance in alicloud_instance.main : {
      ecs_id        = instance.id
      name          = instance.instance_name
      zone_id       = instance.availability_zone
      vswitch_id    = instance.vswitch_id
      private_ip    = instance.private_ip
      login_user    = "root"  # Ubuntu 默认用户名也是 root
      login_password = var.ecs_login_password
      login_command = "ssh root@${instance.private_ip}"
    }
  ]
  description = "所有 ECS 实例的登录信息和网络配置"
}

output "vpc_info" {
  value = {
    vpc_id     = alicloud_vpc.main.id
    vpc_cidr   = alicloud_vpc.main.cidr_block
    subnets    = [for subnet in alicloud_vswitch.main : {
      subnet_id   = subnet.id
      subnet_cidr = subnet.cidr_block
      zone_id     = subnet.zone_id
    }]
  }
  description = "VPC 和子网信息"
}
