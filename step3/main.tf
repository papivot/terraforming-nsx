data "nsxt_policy_edge_cluster" "sup-edge-cluster" {
  display_name = "sup-edge-cluster"
}

data "nsxt_policy_transport_zone" "vlan_tranport_zone" {
  display_name = "edge_vlan_transport_zone"
}

resource "nsxt_policy_tier0_gateway" "sup-t0-gw" {
  description              = "sup-t0-gw"
  display_name             = "sup-t0-gw"
  failover_mode            = "PREEMPTIVE"
  default_rule_logging     = false
  enable_firewall          = true
  ha_mode                  = "ACTIVE_ACTIVE"
  internal_transit_subnets = ["169.254.0.0/24"]
  transit_subnets          = ["100.64.0.0/16"]
  vrf_transit_subnets      = ["169.254.2.0/23"]
  edge_cluster_path        = data.nsxt_policy_edge_cluster.sup-edge-cluster.path

  bgp_config {
    local_as_num    = "65003"
    multipath_relax = true
    ecmp            = true
    inter_sr_ibgp   = true
  }
}

#data "nsxt_policy_edge_node" "edge-1" {
#  edge_cluster_path = data.nsxt_policy_edge_cluster.sup-edge-cluster.path
#  display_name      = "edge-1.env1.lab.test"
#}

resource "nsxt_edge_transport_node" "edge-1" {
  # (resource arguments)
}

# Create VLAN Segments
resource "nsxt_policy_vlan_segment" "vlan104" {
  display_name        = "VLAN104"
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_tranport_zone.path
  vlan_ids            = ["104"]
}

# Create Tier-0 Gateway Uplink Interfaces
resource "nsxt_policy_tier0_gateway_interface" "vrf_uplink1" {
  display_name   = "Uplink-01"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge-1.path
  gateway_path   = nsxt_policy_tier0_gateway.sup-t0-gw.path
  segment_path   = nsxt_policy_vlan_segment.vlan104.path
  subnets        = ["192.168.104.2/23"]
  mtu            = 9000
}

resource "time_sleep" "wait_240_seconds" {
  create_duration = "240s"
}

resource "nsxt_policy_bgp_neighbor" "ubuntu-router" {
  display_name     = "VLAN104-BGP"
  bgp_path         = nsxt_policy_tier0_gateway.sup-t0-gw.bgp_config.0.path
  neighbor_address = "192.168.104.1"
  password         = "vmware"
  remote_as_num    = "65001"
  allow_as_in       = false
  graceful_restart_mode = "HELPER_ONLY"
  hold_down_time        = 75
  keep_alive_time       = 25
  source_addresses      = nsxt_policy_tier0_gateway_interface.vrf_uplink1.ip_addresses
    bfd_config {
    enabled  = true
    interval = 1000
    multiple = 4
      }
     depends_on     = [time_sleep.wait_240_seconds]
}

resource "time_sleep" "wait_300_seconds" {
  create_duration = "300s"
}

# Create Tier-1 Gateway
resource "nsxt_policy_tier1_gateway" "tier1_gw" {
    display_name              = "sup-tier-1-01"
    edge_cluster_path         = data.nsxt_policy_edge_cluster.sup-edge-cluster.path
    failover_mode             = "NON_PREEMPTIVE"
    default_rule_logging      = "false"
    enable_firewall           = "true"
    enable_standby_relocation = "true"
    tier0_path                = nsxt_policy_tier0_gateway.sup-t0-gw.path
    route_advertisement_types = ["TIER1_STATIC_ROUTES", "TIER1_CONNECTED", "TIER1_NAT", "TIER1_LB_VIP", "TIER1_LB_SNAT", "TIER1_DNS_FORWARDER_IP", "TIER1_IPSEC_LOCAL_ENDPOINT"]
    pool_allocation           = "ROUTING"
    ha_mode                   = "ACTIVE_STANDBY"
    depends_on                = [time_sleep.wait_300_seconds]
}

data "nsxt_policy_transport_zone" "supervisor_transport_zone" {
  display_name = "supervisor_transport_zone"
}

# Create NSX-T Overlay Segment for Egress Traffic
resource "nsxt_policy_segment" "Ingress" {
    display_name        = "Ingress-Supervisor-Segment"
    transport_zone_path = data.nsxt_policy_transport_zone.supervisor_transport_zone.path
    connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw.path

    subnet {
        cidr        = "172.16.10.0/24"
           }
}

# Create NSX-T Overlay Segments for Egress Traffic
resource "nsxt_policy_segment" "Egress" {
    display_name        = "Egress-Supervisor-Segment"
    transport_zone_path = data.nsxt_policy_transport_zone.supervisor_transport_zone.path
    connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw.path

    subnet {
        cidr        = "172.16.20.0/24"
           }
}