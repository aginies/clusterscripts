package dhcpnode_cluster;
# Author : Daniel Viard <dviard@mandrakesoft.com>
# Version 0.1
# very light script to add node(s).
# please report bug to: cooker@mandrakesoft.com

use strict;
use MDK::Common;
use cluster_serverconf;
use cluster_fonction_common;
use Getopt::Std;
use wakeup_node_cluster;


our @ISA = qw(Exporter);
our @EXPORT = qw(remove_node_in_dhcp);

sub beep($$) {
    my $esc = chr(27);
    my $freq = shift;
    my $ms   = shift;

    if ($freq < 1) {
        $freq = 1;
    }

    if ($freq > 20000) {    #20 khz
        $freq = 20000;
    }
    if ($ms < 1) {
        $ms = 1;
    }
    if ($ms > 10000) {      #10 sec
        $ms = 10000;
    }

    print($esc . "[10;" . $freq . "]",    #set freq
      $esc . "[11;" . $ms . "]",          #set delay
      chr(7),                             #beep (ascii bell)
      $esc, "[10]",                       #reset freq
      $esc, "[11]");                      #reset delay

    select(undef, undef, undef, ($ms / 1000));
}

sub get_nodes_bloc {
  my ($conf, $compute) = @_;

  my $tag = 'NODE_LIST_ADMIN';
  my ($nodes_bloc) = $conf =~ /# TAG: ${tag}_BEGIN(.*?)# TAG: ${tag}_END/s or die "unable to find NODE_LIST_ADMIN section";
  $nodes_bloc;
}


sub extract_nodelist_bloc {
  my ($conf, $opt, $mac_addr, $compute) = @_;

  my $nodename = cluster_serverconf::cluster_data()->{NODENAME};

  # extract the NODE_LIST_ADMIN bloc
  my $nodes_bloc = get_nodes_bloc($conf, $compute);

  # extract nodes blocs
  my @nodes = $nodes_bloc =~ /(host $nodename\S+\s*\{.*?\s*\})/gs;

  # parse nodes blocs
  foreach my $node (@nodes) {
    my ($node_num, $node_mac) = $node =~ /host $nodename(\d*)\s*\{.*?ethernet (.*?)\s*;\s*.*fixed-address (.*?);/s;
    next if $opt->{d} && $node_mac eq $opt->{d};    ## to del a node

    #I put every char in lower case
    $mac_addr->{$node_num} = lc $node_mac;
  }

}

sub  test_valid_mac {
    my ($opt) = @_;

  # Test the new adress if it's a valid MAC address

  if ($opt->{a} && $opt->{a} !~ /\S:\S\S:\S\S:\S\S:\S\S:\S\S/) {
      die "$opt->{a} is NOT a valide MAC addresse !";
  }
}

sub  test_mac {
  my ($opt, $mac_addr) = @_;
  # if it's already exist in $mac_addr
  if ($opt->{a}) {
    foreach my $node_num (sort keys %$mac_addr) {
	if ($mac_addr->{$node_num} eq $opt->{a}) {
	    $opt->{a} = undef;
	}
    }
  }
}

sub add_node {
    my ($opt, $mac_addr) = @_;
  # to add a node
  if ($opt->{a}) {
    my $i;

    for ($i = cluster_serverconf::cluster_data()->{STARTNODE}; exists $mac_addr->{$i}; $i++) {}
    if ($i > cluster_serverconf::cluster_data()->{FINISHNODE}) {
      print "No more node name available...\n";
      exit $i;
    } else {
      $mac_addr->{$i} = $opt->{a};
    }
  }
}

sub add_node_compute {
    my ($opt, $mac_addr) = @_;
  # to add a node
    if ($opt->{a}) {
	$mac_addr->{$opt->{c}} = $opt->{a};
    }
}

sub remove_node_in_dhcp {
    my ($node) = @_;
    my $node_name = cluster_serverconf::cluster_data()->{NODENAME};
    # admin
    my $MAC = wakeup_node_cluster::find_node_MAC($node, 'ADMIN');
    system("dhcpnode -d $MAC -s");
}

sub print_list_nodes {
  my ($mac_addr) = @_;
  my $node_name = cluster_serverconf::cluster_data()->{NODENAME};
  # nodes list
  print "Node        MAC\n----------------------------\n";
  foreach my $node_num (sort keys %$mac_addr) {
    print sprintf("%s%d       %s \n", $node_name, $node_num, $mac_addr->{$node_num});
  }
}

sub list_nodes {
  my ($opt, $mac_addr) = @_;

  if ($opt->{l}) {
    print_list_nodes($mac_addr);
  }
}

sub write_nodes_bloc {
  my ($nodename, $mac_addr) = @_;

  my $nodes_bloc = join('', map {
    <<EOF
host $nodename$_ \{
    hardware ethernet $mac_addr->{$_};
    fixed-address $nodename$_;
}
EOF
  } sort keys %$mac_addr);

  return $nodes_bloc;
}

sub save_modif {
  my ($opt, $conf_file, $conf, $mac_addr) = @_;

  my $nodename = cluster_serverconf::cluster_data()->{NODENAME};

  my $nodes_bloc = get_nodes_bloc($conf, 0);

  # save modifs if -a or -d
  if ($opt->{a} || $opt->{d}) {
    $nodes_bloc = write_nodes_bloc($nodename, $mac_addr);

    $conf =~
      s/# TAG: NODE_LIST_ADMIN_BEGIN.*?# TAG: NODE_LIST_ADMIN_END/# TAG: NODE_LIST_ADMIN_BEGIN\n$nodes_bloc# TAG: NODE_LIST_ADMIN_END/s;

    #print $conf; exit;
    output($conf_file, $conf) if $opt->{s};
    1;

    if ($opt->{b}) {
        local $| = 1;

      foreach my $n (0 .. 200) {
	beep($n * 5, 10);
      }
    }
  }
}

sub usage {
  my $conf = cluster_serverconf::dhcpd_data()->{DHCPDCONF};

  die "$0 [-h] [-C conffile] [-l | -a MAC | -d MAC] [-c nodenumber] [-s] [-b]
    -h            : this help
    -l            : nodes list
    -a MAC        : add the node MAC
    -d MAC        : del the node MAC
    -C conffile   : specify the conf file (default $conf)
    -s            : backup modifications
    -b	  	  : beep mode engaged ! Don't work very well with X
    ";
}

sub main {
  my %opt;

  getopts("C:la:d:sbh", \%opt) or usage();
  $opt{h} and usage();

  my $conf_file = $opt{C} || cluster_serverconf::dhcpd_data()->{DHCPDCONF};

  # put every char in lower case
  if (defined $opt{a}) {
      $opt{a} = lc $opt{a};
  }
  if (defined $opt{d}) {
      $opt{d} = lc $opt{d};
  }

  my $conf = cat_($conf_file);

  my %mac_addr;

  extract_nodelist_bloc($conf, \%opt, \%mac_addr, 0);

  test_valid_mac(\%opt);
  test_mac(\%opt, \%mac_addr);

  add_node(\%opt, \%mac_addr);

  list_nodes(\%opt, \%mac_addr);

  save_modif(\%opt, $conf_file, $conf, \%mac_addr);

}

1;
