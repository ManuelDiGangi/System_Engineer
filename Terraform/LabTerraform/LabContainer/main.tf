terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "2.9.11"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

resource "proxmox_lxc" "my_container" {
  target_node  = "fata99"
  hostname     = "lxc-basic"
  ostemplate   = "local:vztmpl/ubuntu-23.04-standard_23.04-1_amd64.tar.zst"
  password     = "BasicLXCContainer"
  unprivileged = true
  start        = true

  // Terraform will crash without rootfs defined
  rootfs {
    storage = "local-lvm"
    size    = "8G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = var.ip_addresses_linux
  }
  
    memory = 1024
    cores  = 2
  
}

resource "proxmox_vm_qemu" "cloned_vms" {
	#count       = 

  name        = "W10Clone03" 
  target_node = "fata99"
  clone       = "W10Template"
  os_type     = "win10"
  cores       = 2
  sockets     = 1
  cpu         = "host"
  memory      = 2048
  scsihw      = "virtio-scsi-pci"
  bootdisk    = "scsi0"
  
  
  network {
    model           = "virtio"
    bridge          = "vmbr0"
  }

 		
}	