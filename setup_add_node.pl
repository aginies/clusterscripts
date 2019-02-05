#!/usr/bin/perl 
# please report bug to: cooker@mandriva.com

use add_nodes_to_dhcp_cluster;
use cluster_serverconf;
use cluster_fonction_common;
use MDK::Common;

my $DHCPDCONF = cluster_serverconf::dhcpd_data()->{DHCPDCONF};
my $DHCPDCONF_SAV = cluster_fonction_common::save_config($DHCPDCONF);

my (@dhcpd_conf_bak) = cat_($DHCPDCONF_SAV) =~ /^host\s+(\S+)\s*\{/mg or die "err1";
my (@dhcpd_conf) = cat_($DHCPDCONF) =~ /^host\s+(\S+)\s*\{/mg or die "err2";

foreach my $host (difference2(\@dhcpd_conf, \@dhcpd_conf_bak)) {
  my $DOMAINNAME = cluster_serverconf::dns_data()->{DOMAINNAME};
  if (!member($host, cat_(cluster_serverconf::cluster_data()->{NODESFILE}))) {
    server_cluster::add_node_nodeadmin("$host.$DOMAINNAME");
      print("Host $host.$DOMAINNAME added in administration nodes list.\n");
  } else {
      print("Host $host.$DOMAINNAME already in administration nodes list.\n");
      }
}
