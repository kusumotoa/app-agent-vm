packer {
  required_plugins {
    tart = {
      source  = "github.com/cirruslabs/tart"
      version = ">= 1.12.0"
    }
  }
}

variable "vm_name" {
  type        = string
  default     = "app-agent-vm"
  description = "作る VM の名前"
}

variable "base_image" {
  type        = string
  description = "元にするイメージ。config.sh の BASE_IMAGE から渡す"
}

variable "cpu_count" {
  type    = number
  default = 8
}

variable "memory_gb" {
  type    = number
  default = 16
}

source "tart-cli" "vm" {
  vm_base_name = var.base_image
  vm_name      = var.vm_name
  cpu_count    = var.cpu_count
  memory_gb    = var.memory_gb
  ssh_username = "admin"
  ssh_password = "admin"
  ssh_timeout  = "300s"
  headless     = true
}

build {
  sources = ["source.tart-cli.vm"]

  provisioner "file" {
    sources     = ["vm/mise.toml", "vm/config.toml"]
    destination = "/tmp/"
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash -l -e"
    inline = [
      "mkdir -p ~/setup ~/.config/mise",
      "mv /tmp/mise.toml ~/setup/mise.toml",
      "mv /tmp/config.toml ~/.config/mise/config.toml",
      "cd ~/setup && mise trust && mise bootstrap",
    ]
  }
}
