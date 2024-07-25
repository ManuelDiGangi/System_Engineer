variable "pm_user" 	{
      description  = "proxmox user"
	  default		= "root@pam"
	}
	
variable "pm_password" {
	  description = "Proxmox password"
	  default     = "Pa$$w0rd"
	}

variable "pm_api_url" {
  description = "Proxmox API URL"
  default     = "https://192.168.3.99:8006/api2/json"
}


variable "new_vm_name" {
  default     = ["W10Pro-1", "W10Pro-2"]
  #default     = ["W10Pro-1"]
}

variable "vm_ips" {
  description = "IP addresses of the new VMs"
  #default     = ["192.168.1.105", "192.168.1.106"]
  default     = ["192.168.1.105"]
}

variable "gateway_ip" {
  default     = "192.168.1.2"
}

variable "vm_storage" {
  description = "Storage location for the new VMs"
  default     = "local-lvm"
}

variable "vm_cpu" {
  default     = 1
}

variable "vm_memory" {
  default     = 2048
}

variable "vm_disk_size" {
  description = "Disk size for the new VMs"
  default     = "50G"
}


###variabili per connessioni winrm
variable "admin_password" {
	  default     = "Pa$$w0rd"
	}
###variabili post crazione
variable "hostname" {
	  default = "win10proviX3"
	}
variable "ip_address" {
	  default = "192.168.3.103"
	}
variable "gateway" {
	  default = "192.168.3.2"
	}
variable "dns1" {
	  default = "8.8.8.8"
	}
variable "dns2" {
	  default = "192.168.3.2"
	}	

