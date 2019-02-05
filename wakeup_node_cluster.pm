package wakeup_node_cluster;
# Author : Daniel Viard <dviard@mandrakesoft.com>
# Version 0.1
# very light script to add node(s).
# please report bug to: cooker@mandrakesoft.com

use strict;
use Term::ANSIColor;
use MDK::Common;
use cluster_serverconf;
use cluster_fonction_common;
use Getopt::Std;


#
sub usage {
  die "usage: $0 [-h] -n nodeName
    -h                : this (help) message
    -n nodeName  : name of the node to wake up (without domain name)

    EXAMPLE: $0 -n node1
    ";
}

sub getColors {
  {
    'NORMAL' => 'green',
    'SUCCESS' => 'bold green',
    'INFO' => 'blue',
    'WARNING' => 'bold yellow',
    'WHITE' => 'white'
  };
}

sub set_color {
  my ($col) = @_;
  print color('reset');
  print color getColors()->{$col};
}


# Find in the DHCP's configuration the MAC address of a node
# $interface must be 'ADMIN'
sub find_node_MAC {
  my ($node_name, $interface) = @_;

  my $DHCPDCONF = cluster_serverconf::dhcpd_data()->{DHCPDCONF};
  my $nodesname = cluster_serverconf::cluster_data()->{NODENAME};
  # extract the NODE_LIST bloc
  my ($nodes_bloc) = cat_($DHCPDCONF) =~ /# TAG: NODE_LIST_$interface\_BEGIN(.*?)# TAG: NODE_LIST\_$interface\_END/s
      or die "unable to find NODE_LIST_$interface section";

  # extract nodes blocs
  my %nodes = $nodes_bloc =~ /host ($nodesname\S+)\s*\{(.*?)\s*\}/gs;
  my $s = $nodes{$node_name} or warn "Node '$node_name' not found in $DHCPDCONF.";
  my ($mac_addr) = $s =~ /hardware \s+ ethernet \s+ (.*?) \s*;
                            \s* .*? fixed-address \s+ $node_name/x or warn "hardware ethernet address not found";
  lc $mac_addr;
}

sub main {

  my %opt;
  getopts("n::h", \%opt) or usage();

  $opt{n} or usage();
  $opt{h} and usage();

  my $node_name = $opt{n};

#  set_color('INFO');
#  print "|--------------------------------|\n";
#  print "|          Wake up Node          |\n";
#  print "|--------------------------------|\n";
#  print "\n";
#  set_color('NORMAL');

#  set_color('INFO');
  print " - Searching '$node_name' MAC address...\n";
#  set_color('NORMAL');
  my $mac_addr = find_node_MAC($node_name, 'ADMIN');

#  set_color('INFO');
  print " - Wake up '$node_name' ($mac_addr)...\n";
#  set_color('NORMAL');

  sys("ether-wake $mac_addr");

}



1;
