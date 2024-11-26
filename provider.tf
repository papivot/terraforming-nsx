terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
    }
    vsphere = {
      source = "hashicorp/vsphere"
    }
  }
}

###  vSphere Configuration
provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
  api_timeout          = 10
}

###  NSX Configuration
provider "nsxt" {
  host                 = var.nsx_server
  username             = var.nsx_username
  password             = var.nsx_password
  allow_unverified_ssl = true
  max_retries          = 2
}