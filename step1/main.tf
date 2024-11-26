###  Adding vCenter Server as Compute Manager to NSX
resource "nsxt_compute_manager" "NSXT-Sup" {
  description            = "NSX-T Compute Manager"
  display_name           = "NSXT-Sup"
  create_service_account = "true"
  access_level_for_oidc  = "FULL"
  set_as_oidc_provider   = "true"
  server                 = var.vsphere_server

  credential {
    username_password_login {
      username   = var.vsphere_user
      password   = var.vsphere_password
      thumbprint = var.certificate_thumbprint
    }
  }
  origin_type = "vCenter"
}

data "nsxt_compute_manager_realization" "NSXT-Sup_realization" {
  id      = nsxt_compute_manager.NSXT-Sup.id
  timeout = 1200
}

###  Creation of Overlay Transport Zone
resource "time_sleep" "wait_240_seconds" {
  create_duration = "240s"
}

resource "nsxt_policy_transport_zone" "overlay_transport_zone" {
  display_name   = "supervisor_transport_zone"
  transport_type = "OVERLAY_BACKED"
  depends_on     = [time_sleep.wait_240_seconds]
}

### Creation of Default Uplink Host Switch Profile
resource "nsxt_policy_uplink_host_switch_profile" "uplink_host_switch_profile" {
  description  = "Uplink host switch profile for Supervisor"
  display_name = "uplink_host_switch_profile"

  transport_vlan = 0
  overlay_encap  = "GENEVE"
  teaming {
    active {
      uplink_name = "uplink-1"
      uplink_type = "PNIC"
    }
    active {
      uplink_name = "uplink-2"
      uplink_type = "PNIC"
    }
    policy = "LOADBALANCE_SRCID"
  }
  named_teaming {
    active {
      uplink_name = "uplink-1"
      uplink_type = "PNIC"
    }
    standby {
      uplink_name = "uplink-2"
      uplink_type = "PNIC"
    }
    policy = "FAILOVER_ORDER"
    name   = "uplink-1-failover_order"
  }
  named_teaming {
    active {
      uplink_name = "uplink-2"
      uplink_type = "PNIC"
    }
    standby {
      uplink_name = "uplink-1"
      uplink_type = "PNIC"
    }
    policy = "FAILOVER_ORDER"
    name   = "uplink-2-failover_order"
  }
  named_teaming {
    active {
      uplink_name = "uplink-2"
      uplink_type = "PNIC"
    }
    policy = "FAILOVER_ORDER"
    name   = "uplink-2"
  }
  named_teaming {
    active {
      uplink_name = "uplink-1"
      uplink_type = "PNIC"
    }
    policy = "FAILOVER_ORDER"
    name   = "uplink-1"
  }
}

### Creation of Edge Uplink Host Switch Profile
resource "nsxt_policy_uplink_host_switch_profile" "nsx_edge_uplink_profile_1" {
  description  = "nsx_edge_uplink_profile_1"
  display_name = "nsx_edge_uplink_profile_1"

  transport_vlan = 102
  mtu            = 9000
  teaming {
    active {
      uplink_name = "uplink-1"
      uplink_type = "PNIC"
    }
    active {
      uplink_name = "uplink-2"
      uplink_type = "PNIC"
    }
    policy = "LOADBALANCE_SRCID"
  }
  named_teaming {
    active {
      uplink_name = "uplink-1"
      uplink_type = "PNIC"
    }
    policy = "FAILOVER_ORDER"
    name   = "uplink-1-edge"
  }
  named_teaming {
    active {
      uplink_name = "uplink-2"
      uplink_type = "PNIC"
    }
    policy = "FAILOVER_ORDER"
    name   = "uplink-2-edge"
  }
}

### Creation of Edge VLAN Transport Zones
resource "nsxt_policy_transport_zone" "edge_vlan_transport_zone" {
  display_name                = "edge_vlan_transport_zone"
  description                 = "edge_vlan_transport_zone"
  transport_type              = "VLAN_BACKED"
  uplink_teaming_policy_names = ["uplink-1-edge", "uplink-2-edge"]
  site_path                   = "/infra/sites/default"
  enforcement_point           = "default"
}

### Creation of Transport Node Profile
resource "time_sleep" "wait_300_seconds" {
  create_duration = "300s"
}

data "vsphere_datacenter" "datacenter" {
  name = "Datacenter"
}

data "vsphere_distributed_virtual_switch" "distributed_virtual_switch" {
  name          = "Pacific-VDS"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

resource "nsxt_policy_host_transport_node_profile" "TNP" {
  display_name = "supervisor-transport-node-profile"

  standard_host_switch {
    host_switch_id   = data.vsphere_distributed_virtual_switch.distributed_virtual_switch.id
    host_switch_mode = "STANDARD"
    ip_assignment {
      assigned_by_dhcp = true
    }
    transport_zone_endpoint {
      transport_zone = nsxt_policy_transport_zone.overlay_transport_zone.path
    }
    host_switch_profile = [nsxt_policy_uplink_host_switch_profile.uplink_host_switch_profile.path]
    is_migrate_pnics    = false
    uplink {
      uplink_name     = "uplink-1"
      vds_uplink_name = "uplink1"
    }
    uplink {
      uplink_name     = "uplink-2"
      vds_uplink_name = "uplink2"
    }
  }
  depends_on = [time_sleep.wait_300_seconds]
}

### Prepare Host Cluster by attaching TNP Profile
data "vsphere_compute_cluster" "venv_compute_cluster" {
  name          = "Cluster"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "nsxt_compute_collection" "compute_cluster_collection" {
  display_name = data.vsphere_compute_cluster.venv_compute_cluster.name
  origin_id    = data.nsxt_compute_manager_realization.NSXT-Sup_realization.id
}

resource "nsxt_policy_host_transport_node_collection" "sup-tnp-c" {
  display_name                = "sup-tnp-c"
  compute_collection_id       = data.nsxt_compute_collection.compute_cluster_collection.id
  transport_node_profile_path = nsxt_policy_host_transport_node_profile.TNP.path
  remove_nsx_on_destroy       = true
  depends_on                  = [data.nsxt_compute_manager_realization.NSXT-Sup_realization]
}