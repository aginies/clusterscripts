package add_nodes_to_dhcp_cluster;
# Author : Daniel Viard <dviard@mandrakesoft.com>
# Version 0.2
# very light script to add node(s).
# please report bug to: cooker@mandriva.com

use strict;
use Getopt::Std;
use Term::ANSIColor;
use MDK::Common;
use cluster_fonction_common;
use cluster_serverconf;

sub set_compute_interface {
  my $compute_interface = cluster_commonconf::system_network()->{COMPUTE_INTERFACE_NODE};

#  sys('rshp $NKA -v -- \'echo -ne "DEVICE=' . $compute_interface . '\nBOOTPROTO=dhcp\nONBOOT=yes\n">/etc/sysconfig/network-scripts/ifcfg-' . $compute_interface . '\'');
#  sys('rshp $NKA -v -- ifup ' . $compute_interface);

  my $ifcfg = "ifcfg-$compute_interface";
  output($ifcfg,
"DEVICE=$compute_interface
BOOTPROTO=dhcp
ONBOOT=yes
");
  print "\nStopping computing network interface ($compute_interface) on nodes\n";
  system("rshpn ifdown $compute_interface");
  print "Creating network configuration files for $ifcfg on all nodes...\n";
  system("mputn $ifcfg /etc/sysconfig/network-scripts/$ifcfg");
  print "\n";
  rm_rf($ifcfg);
  print "\nRemoving dhcp's cache on nodes...\n";
  system("rshpn rm -vf /etc/dhcpc/*");
  print "Erasing server's dhcp leases\n";
  leave();
  print "\nStarting computing interface ($compute_interface) on nodes...\n";
  system("rshpn service network restart");
}

sub log_scan {
  my ($opt, $mac_in_dhcp) = @_;

  my $syslog    = "/var/log/syslog";
  my $dhcpdconf = cluster_serverconf::dhcpd_data->{DHCPDCONF};
  my $dhcpnode  = cluster_commonconf::mysystem()->{BIN_PATH} . '/dhcpnode';

  open(my $MESSAGE, $syslog) or die "Can't open /var/log/messages !!!\n";
  seek($MESSAGE, 0, 2);

  my @macs;
  local $_;
  for (;;) {
    sleep 1;
    while (<$MESSAGE>) {
      if (my ($new_mac) = /DHCPACK on \S+ to (\S+) via \S+/) {
	if (!is_it_my_MAC($new_mac)) {
	  if (!member($new_mac, @$mac_in_dhcp)) {
	    if (!member($new_mac, @macs)) {
	      push @macs, $new_mac;
	      print "DHCP REQUEST FROM A NEW NODE : $new_mac";
	      if ($opt->{n}) {
		print '     [ ' . int(@macs) . " / $opt->{n} ]";
	      }
	      print "\n";
	      my $beep = $opt->{b} ? ' -b' : '';
	      system "$dhcpnode -C $dhcpdconf.add_nodes -a $new_mac$beep -s";
	    } else {
	      print "dhcp request ignored from a registred node : $new_mac\n";
	    }
	  } else {
	    print "dhcp request from a node that is already in $dhcpdconf : $new_mac\n";
	  }
	}
	# I test if we have enough addresses
	should_i_leave($opt, \@macs, $MESSAGE);
	sleep 1;
      }
    }
  }
}

sub my_MAC {
# Get the MAC addresses of the dhcp server
  map { if_(/^eth.*HWaddr\s+(\S+)/, lc $1) } `/sbin/ifconfig`;
}

sub is_it_my_MAC {
  my ($mac_test) = @_;
  any { $_ eq "0$mac_test" } my_MAC();
}

sub read_mac_from_dhcpd {
  my $cmd = cluster_commonconf::mysystem()->{BIN_PATH} . '/dhcpnode -l';
  my @mac_in_dhcp = map { if_(/\S+\s+(\S\S:\S\S:\S\S:\S\S:\S\S:\S\S)/, $1) } `$cmd`;
  $? == 0 or die "$cmd failed\n";
  @mac_in_dhcp;
}

sub leave {
  my $dhcpdconf = cluster_serverconf::dhcpd_data->{DHCPDCONF};

  print "Backuping dhcpd.conf\n";
  system("mv $dhcpdconf /root/");
  print "Installing the newest $dhcpdconf";
  system("mv $dhcpdconf.add_nodes $dhcpdconf");
  print "Erasing server's leases (DHCP)\n";
  output('/var/lib/dhcp/dhcpd.leases', '');
  system "/etc/init.d/dhcpd", "restart";
  print "DHCP daemon is now restarted.\n";
}

sub should_i_leave {
  my ($opt, $mac, $MESSAGE) = @_;
# I test if we have enough addresses
  if (@$mac >= $opt->{n}) {
    close $MESSAGE;
    leave();
    die " done";
  }
}

sub check_files {
  my ($opt) = @_;

  my $dhcpdconf = cluster_serverconf::dhcpd_data->{DHCPDCONF};
  my $dhcpnode  = cluster_commonconf::mysystem()->{BIN_PATH} . '/dhcpnode';

  if ($opt->{n}) {
    if ($opt->{n} < 1) {
      print "You can't install less than 1 node !\n";
      usage();
    }
  }

  if (!-f $dhcpnode) {
    die "$dhcpnode doesn't exist please change the \$dhcpnode location\n";
  }

  if (!-f $dhcpdconf) {
    die "$dhcpdconf doesn't exist\n";
  }
}

sub usage {
  my $dhcpdconf = cluster_serverconf::dhcpd_data->{DHCPDCONF};

  die "$0 [-h] [-n Number_of_Nodes] [-b]
    -h                 : this help
    -b	  	       : beep mode engaged ! Don't work very well with X
    -n Number_of_Nodes : number of nodes to add, \n!!!this option changes the original $dhcpdconf file!!!.

    EXAMPLES: $0 -b -n 3
              $0 -b -c
    ";
}

sub main {

  my $dhcpdconf = cluster_serverconf::dhcpd_data->{DHCPDCONF};
  my %opt;

  getopts("n:bh", \%opt) or usage();
  $opt{n} or usage();
  $opt{h} and usage();

  check_files(\%opt);

#  copy $dhcpdconf , $dhcpdconf . "\.add_nodes";
  cp_af($dhcpdconf , $dhcpdconf . '.add_nodes');

  print "This script works on a backup version of $dhcpdconf\n";
  print "It can be found in  $dhcpdconf.add_nodes\n";

#  my $profile = cluster_commonconf::mysystem()->{PROFILE};

  if ($opt{n}) {
    print "\nThe server is now collecting the MAC addresses.\n";
    print "\nPlease bootup your nodes, PXE must be the first boot entry in your bioses.\n";
    print "\nWhen the nodes will make theirs PXE requests, they will be detected.\n";
    print "\nWaiting for $opt{n} node(s)...\n";
  } else {
      print "\nMove $dhcpdconf.add_nodes to $dhcpdconf and do a
    /etc/init.d/dhcpd restart
after to valid the changes.\n";
      print "\nWaiting for dhcp request\n\n";
      print "Press Ctrl+C for stopping MAC addresses collecting\n";
  }

  my @mac_in_dhcp = read_mac_from_dhcpd();
  log_scan(\%opt, \@mac_in_dhcp);

}

1;
