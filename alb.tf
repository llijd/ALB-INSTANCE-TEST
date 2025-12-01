variable "pay_type" {
	type                       = string
}
variable "pay_period_unit" {
	type                       = string
}
variable "pay_period" {
	type                       = number
}
variable "zone_id" {
	type                       = string
}
variable "vpc_cidr_block" {
	type                       = string
}
variable "vswitch_cidr_block" {
	type                       = string
} 
variable "instance_type" {
	type                       = string
}
variable "system_disk_category" {
	type                       = string
}
variable "system_disk_size" {
	type                       = number
}
variable "data_disk_category" {
	type                       = string
}
variable "data_disk_size" {
	type                       = number
} 
variable "instance_password" {
	type                       = string
}
# 默认资源名称
locals {
  production_name            = "nginx"
  new_scg_name 							 = "sg-for-${local.production_name}"
  new_host_name						   = "app-for-${local.production_name}"
}

resource "alicloud_vpc" "vpc" {
  cidr_block 								 = var.vpc_cidr_block
}

resource "alicloud_vswitch" "vsw" {
  vpc_id     								 = alicloud_vpc.vpc.id
  cidr_block 								 = var.vswitch_cidr_block
  zone_id    								 = var.zone_id
}

# 安全组基本信息配置
resource "alicloud_security_group" "security_group" {
  name        							 = local.new_scg_name
  description 							 = "nginx scg"
  vpc_id 										 =  alicloud_vpc.vpc.id
}

# 安全组入口端1
resource "alicloud_security_group_rule" "allow_ssh" {
  security_group_id 				 = alicloud_security_group.security_group.id
  type										   = "ingress"
  cidr_ip										 = "0.0.0.0/0"
  policy 							 		   = "accept"
  ip_protocol					 			 = "tcp"
  port_range							   = "22/22"
  priority								 	 = 1
}

# 安全组入口端2
resource "alicloud_security_group_rule" "allow_web" {
  security_group_id 			 	 = alicloud_security_group.security_group.id
  type											 = "ingress"
  cidr_ip										 = "0.0.0.0/0"
  policy									 	 = "accept"
  ip_protocol								 = "tcp"
  port_range								 = "80/443"
  priority									 = 1
}

# 安全组出口端
resource "alicloud_security_group_rule" "allow_egress" {
  security_group_id 				 = alicloud_security_group.security_group.id
  type 											 = "egress"
  cidr_ip										 = "0.0.0.0/0"
  policy										 = "accept"
  ip_protocol								 = "tcp"
  port_range								 = "1/65535"
  priority									 = 1
}

# 实例基本配置
resource "alicloud_instance" "instance" {
  availability_zone          = var.zone_id
  security_groups						 = [alicloud_security_group.security_group.id]
  # series III
  host_name 								 = local.new_host_name
  instance_type              = var.instance_type
  system_disk_size           = var.system_disk_size
  system_disk_category       = var.system_disk_category
  image_id                   = "centos_7_9_x64_20G_alibase_20210318.vhd"
  vswitch_id                 = alicloud_vswitch.vsw.id
  password                   = var.instance_password
  internet_charge_type			 = "PayByTraffic"
  internet_max_bandwidth_out = 30
  instance_charge_type			 = var.pay_type
  period										 = var.pay_period
  period_unit								 = var.pay_period_unit
  user_data									 = file("${path.cwd}/user-data.sh")
  data_disks {
    size       							 = var.data_disk_size
    category 							   = var.data_disk_category
  }
}
# 返回Nginx的IP地址
output "nginx_ip" {
  value										 	 = "http://${alicloud_instance.instance.public_ip}:8080"
}
