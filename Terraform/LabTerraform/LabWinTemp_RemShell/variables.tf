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
variable "hostnames" {
	  default = "Win10Clone0"
	}
variable "ip_addresses" {
	  default = "10.0.0.5"
	}
variable "gateway" {
	  default = "10.0.0.59"
	}
variable "dns1" {
	  default = "8.8.8.8"
	}
variable "dns2" {
	  default = "8.8.4.4"
	}	

variable "cont" {
	  default = "0"
	}	
