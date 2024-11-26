data "nsxt_compute_manager" "NSXT-Sup" {
  display_name = "NSXT-Sup"
}

data "vsphere_datacenter" "datacenter" {
  name = "Datacenter"
}

data "vsphere_compute_cluster" "venv_compute_cluster" {
  name          = "Cluster"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_datastore" "datastore" {
  name          = "vsanDatastore"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "mgmt-network" {
  name          = "DVPG-Management-network"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "edge-datapath-network1" {
  name          = "edge-uplink-1"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "edge-datapath-network2" {
  name          = "edge-uplink-2"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "nsxt_policy_transport_zone" "overlay_transport_zone" {
  display_name = "supervisor_transport_zone"
}

data "nsxt_policy_transport_zone" "vlan_transport_zone" {
  display_name   = "edge_vlan_transport_zone"
  transport_type = "VLAN_BACKED"
}

data "nsxt_policy_uplink_host_switch_profile" "uplink_host_switch_profile" {
  display_name = "nsx_edge_uplink_profile_1"
}

resource "nsxt_edge_transport_node" "edge-1" {

  display_name = "edge-1"

  standard_host_switch {
    ip_assignment {
      static_ip {
        ip_addresses    = ["192.168.102.10", "192.168.102.11"]
        subnet_mask     = "255.255.254.0"
        default_gateway = "192.168.102.1"
      }
    }
    transport_zone_endpoint {
      transport_zone = data.nsxt_policy_transport_zone.vlan_transport_zone.path
    }
    transport_zone_endpoint {
      transport_zone = data.nsxt_policy_transport_zone.overlay_transport_zone.path
    }
    host_switch_profile = [data.nsxt_policy_uplink_host_switch_profile.uplink_host_switch_profile.path]
    pnic {
      device_name = "fp-eth0"
      uplink_name = "uplink-1"
    }
    pnic {
      device_name = "fp-eth1"
      uplink_name = "uplink-2"
    }
  }

  deployment_config {
    form_factor = "SMALL"
    node_user_settings {
      cli_username   = "admin"
      cli_password   = "VMware1!VMware1!"
      root_password  = "VMware1!VMware1!"
      audit_username = "audit"
      audit_password = "VMware1!VMware1!"
    }
    vm_deployment_config {
      management_network_id   = data.vsphere_network.mgmt-network.id
      data_network_ids        = [data.vsphere_network.edge-datapath-network1.id, data.vsphere_network.edge-datapath-network2.id]
      compute_id              = data.vsphere_compute_cluster.venv_compute_cluster.id
      storage_id              = data.vsphere_datastore.datastore.id
      vc_id                   = data.nsxt_compute_manager.NSXT-Sup.id
      default_gateway_address = ["192.168.100.1"]
      management_port_subnet {
        ip_addresses  = ["192.168.100.71"]
        prefix_length = 23
      }
    }
  }

  node_settings {
    enable_upt_mode      = false
    hostname             = "edge-1.env1.lab.test"
    allow_ssh_root_login = true
    enable_ssh           = true
    dns_servers          = ["192.168.100.1"]
    search_domains       = ["env1.lab.test"]
    ntp_servers          = ["129.6.15.28"]
  }
}