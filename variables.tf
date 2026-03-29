variable "project" {}

variable "region" {
  default = "us-east4"
}

variable "zone" {
  default = "us-east4-a"
}

variable "allowed_ssh_ip" {
  description = "IP address allowed to SSH into the VM"
  type        = string
}
