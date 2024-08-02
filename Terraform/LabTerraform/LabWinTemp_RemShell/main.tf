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




resource "proxmox_vm_qemu" "cloned_vms" {
	count       = 3

  name        = "W10Clone0${count.index}" 
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

# Dummy null_resource that depends on the creation of all VMs
resource "null_resource" "run_once0" {
   # Dipende dalla creazione di tutte le VM
  depends_on = [proxmox_vm_qemu.cloned_vms]
  count       = 10

  provisioner "remote-exec" { 
  connection {
    type         = "winrm"
    host         = "10.0.0.10${count.index}"  # Use the VM's IP address or DNS name
    user         = "utente"  # Ensure this user has permissions to run the script
    password     = "Pa$$w0rd"
    port         = 5985  # Default WinRM port for HTTP
    use_ntlm     = true
    https        = false  # Set to `true` if using HTTPS for WinRM
    insecure     = true  # Set to `false` if using a valid SSL certificate
    timeout      = "3m"
  }
	
  inline = [
    "powershell -ExecutionPolicy Bypass -File C:\\script\\post-create-config.ps1 -NewHostname ${var.hostnames}${count.index} -IPAddress ${var.ip_addresses}${count.index} -Gateway ${var.gateway} -DNS1 ${var.dns1} -DNS2 ${var.dns2}"
  ]
  }
}


