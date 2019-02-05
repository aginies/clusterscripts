package auto_add_nodes_cluster;
# Author : Daniel Viard <dviard@mandrakesoft.com>
# Version 0.1
# very light script to add node(s).
# please report bug to: cooker@mandrakesoft.com

use strict;
use Term::ANSIColor;
use MDK::Common;
use cluster_serverconf;
use cluster_fonction_common;
use cluster_commonconf;
use cluster_set_admin;
use cluster_set_compute;
use auto_remove_nodes_cluster;
use server_cluster;

use Getopt::Std;

our @ISA = qw(Exporter);
our @EXPORT = qw(add_node_in_nodes_list);

#
sub usage {
  die "usage: $0 [-h] -g <nameOfTheGoldenNode> -n <numberOfNodesToDuplicate> -p <deviceToDuplicate> [-c] [-a]
    -h                : this (help) message
    -g GoldenNodeName : the name of the olden node to duplicate
    -n numberOfNodes  : number of nodes to add
    -p device         : Use for example 'hda' for ide drive
                        or 'sda' for scsi drive
    -a                : auto (no pause)
    -c                : color mode
    -s                : skip add node in dhcpd.conf (special mode)

    EXAMPLE: $0 -c -g n1 -n 3 -p sda
    ";
}

sub clean_previous_add_dhcp {
  print " - kill all previous add_node on server\n";
  system("killall -9 setup_add_nodes_to_dhcp.pl ");
}


sub clean_previous_ka {
  my ($node) = @_;
  print " - kill old ka-d on golden node\n";
  system("ssh $node killall -9 ka-d.sh");
  system("ssh $node killall -9 ka-d-server");
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
  my ($opt, $col) = @_;
  if ($opt->{c}) {
    print color('reset');
    print color getColors()->{$col};
  }
}

sub clear {
  print `clear` , "\n";
}


sub launch_script {
  my ($opt, $cmd) = @_;

  clear();
  set_color($opt, 'INFO');
  print "\n";
  print "---------------------------------------------------------\n";
  print " - Launch : $cmd\n";
  print "---------------------------------------------------------\n";
  print "\n";
  sleep 2;
  set_color($opt, 'NORMAL');
  eval { sys($cmd) };
}


# Add the new node(s) in the /etc/nodes_list file
sub add_node_in_nodes_list {
  my ($DHCPDCONF, $DHCPDCONF_SAV, $opt) = @_;
  # Diff between the older DHCPDCONF.add_nodes and the new DHCPDCONF
  # to add the new node(s) in the /etc/nodes_list file

  my (@dhcpd_conf_bak) = cat_($DHCPDCONF_SAV) =~ /^host\s+(\S+)\s*\{/mg or die "err1";
  my (@dhcpd_conf) = cat_($DHCPDCONF) =~ /^host\s+(\S+)\s*\{/mg or die "err2";
  foreach my $host (difference2(\@dhcpd_conf, \@dhcpd_conf_bak)) {
    my $DOMAINNAME = cluster_serverconf::dns_data()->{DOMAINNAME};
    if (!member($host, cat_(cluster_serverconf::cluster_data()->{NODESFILE}))) {
      server_cluster::add_node("$host.$DOMAINNAME");
      print("Host $host.$DOMAINNAME added in administration nodes list.\n");
    } else {
      print("Host $host.$DOMAINNAME already in administration nodes list.\n");
    }
  }

  $opt->{a} or enter_key();
}

sub enter_key {
  print("\n\n (press ENTER key to continue)\n");
  <STDIN>;
  sys("clear");
}

sub check_golden_node {
  my ($opt, $golden_node) = @_;
  if (!eval { sys("ssh $golden_node \"exit\""); 1 }) {
    set_color($opt, 'WARNING');
    print "$golden_node is not reachable.\n";
    print "Please check your network connection.\n";
    set_color($opt, 'NORMAL');
    exit(1);
  } else {
    set_color($opt, 'SUCCESS');
    print "OK.\n";
    set_color($opt, 'NORMAL');
  }
}

sub check_desc {
  my ($opt, $golden_node) = @_;
  my $DESC = cluster_commonconf::mysystem()->{DESC};

  if (!eval { sys("ssh $golden_node \"cat desc\""); 1 }) {
    set_color($opt, 'WARNING');
    print "Can't find '$DESC' file on the golden node.\n";
    print "Please edit the '$DESC' file on the golden node.\n";
    set_color($opt, 'NORMAL');
    exit(1);
  } else {
    set_color($opt, 'SUCCESS');
    print "OK.\n";
    set_color($opt, 'NORMAL');
  }
}

sub main {
  my $DESC = cluster_commonconf::mysystem()->{DESC};
  my $PROFILE = cluster_commonconf::mysystem()->{PROFILE};
  my $PROFILECSH = cluster_commonconf::mysystem()->{PROFILECSH};

  my %opt;
  getopts("g:n:p:achs", \%opt) or usage();

  $opt{g} && $opt{n} && $opt{p} or usage();
  $opt{h} and usage();

  my $goldenNodeName = $opt{g};
  my $numberOfNodes = $opt{n};
  my $pdesc = basename($opt{p});

  # Print info
  clear();
  set_color(\%opt, 'INFO');
  print "|--------------------------------|\n";
  print "|          ADD NODE(S)           |\n";
  print "|--------------------------------|\n";
  print "\n";
  set_color(\%opt, 'NORMAL');
  clean_previous_add_dhcp();

  set_color(\%opt, 'INFO');
  print "---------------------------------------------------------\n";
  print " - Checking connection to $goldenNodeName\n";
  print "---------------------------------------------------------\n";
  print "\n";
  set_color(\%opt, 'NORMAL');
  check_golden_node(\%opt, $goldenNodeName);
  clean_previous_ka($goldenNodeName);

  set_color(\%opt, 'INFO');
  print "---------------------------------------------------------\n";
  print " - Checking '$DESC' file on $goldenNodeName\n";
  print "---------------------------------------------------------\n";
  set_color(\%opt, 'NORMAL');
  check_desc(\%opt, $goldenNodeName);
  $opt{a} or enter_key();

  # Launch setup_pxe_server setup ka on server
  print "\n";
  launch_script(\%opt, "setup_pxe_server.pl boot kamethod");
  $opt{a} or enter_key();


  if ($opt{s}) {
    set_color(\%opt, 'INFO');
    print "---------------------------------------------------------\n";
    print " - Node already in dhcpd conf, skipping detection \n";
    print "---------------------------------------------------------\n";
    set_color(\%opt, 'NORMAL');
  } else {
    # Backup /etc/dhcpd.conf
    my $DHCPDCONF = cluster_serverconf::dhcpd_data()->{DHCPDCONF};
    set_color(\%opt, 'INFO');
    print "---------------------------------------------------------\n";
    print " - Backuping  $DHCPDCONF\n";
    print "---------------------------------------------------------\n";
    set_color(\%opt, 'NORMAL');
    #  cp_af($DHCPDCONF, "$DHCPDCONF.bak_add");
    my $DHCPDCONF_SAV = cluster_fonction_common::save_config($DHCPDCONF);
    $opt{a} or enter_key();

    # Launch setup_add_nodes_to_dhcp.pl to collect the MAC adress of the new nodes
    launch_script(\%opt, "setup_add_nodes_to_dhcp.pl -n $numberOfNodes");
    $opt{a} or enter_key();

    set_color(\%opt, 'INFO');
    print "---------------------------------------------------------\n";
    print " - Adding the new node(s) in " . cluster_serverconf::cluster_data()->{NODESFILE} . "\n";
    print "---------------------------------------------------------\n";
    set_color(\%opt, 'NORMAL');

    # - Check domainname from dhcpd.conf
    # - Diff between the older $DHCPDCONF.date and the new $DHCPDCONF
    #   to add the new node(s) in the /etc/nodes_list file
    add_node_in_nodes_list($DHCPDCONF, $DHCPDCONF_SAV, \%opt);
  }

  set_color(\%opt, 'INFO');
  print "---------------------------------------------------------\n";
  print " - Backuping $PROFILE\n";
  print "---------------------------------------------------------\n";
  set_color(\%opt, 'NORMAL');
  cluster_fonction_common::save_config($PROFILE);
  cluster_fonction_common::save_config($PROFILECSH);
  $opt{a} or enter_key();

  # regenerate config file
  set_color(\%opt, 'INFO');
  print "---------------------------------------------------------\n";
  print " - Regenerating config file\n";
  print "---------------------------------------------------------\n";
  set_color(\%opt, 'NORMAL');
  auto_remove_nodes_cluster::regenerate_conf();
  # Launch 'set_list_node' on server to regenerate config file
#  print "\n";
#  launch_script(\%opt, "set_list_node.pl");
  $opt{a} or enter_key();

  # Set environnement

  # Launch 'setup_ka_deploy.pl' on golden node
  # Launch 'ka-d.sh -n numberOfNode -r lilo -p pdesc desc' on golden node
  set_color(\%opt, 'INFO');
  print "\n";
  print "---------------------------------------------------------\n";
  print " - Launching (on golden node): setup_ka_deploy.pl\n";
  print " - Launching (on golden node): ka-d.sh -n $numberOfNodes -r lilo -p $pdesc $DESC\n";
  print "---------------------------------------------------------\n";
  set_color(\%opt, 'NORMAL');
  sys("ssh root\@$goldenNodeName \"setup_ka_deploy.pl; ka-d.sh -n $numberOfNodes -r lilo -p $pdesc $DESC\"");
  $opt{a} or enter_key();

  # Launch 'setup_pxe_server setup local' on server
  print "\n";
  launch_script(\%opt, "setup_pxe_server.pl boot local");
  $opt{a} or enter_key();

  # print info
  print "\n";
  set_color(\%opt, 'INFO');
  print "---------------------------------------------------------\n";
  print " * * * * * * * * * * * * * * * * * * * * * * * * * * * * *\n";
  print " Procedure complete, please relog or launch \n";
  set_color(\%opt, 'WARNING');
  print "'source $PROFILE'";
  set_color(\%opt, 'INFO');
  print " to set the environement.\n";
  print "$PROFILECSH is available for CSH\n";
  set_color(\%opt, 'NORMAL');
  $opt{a} or enter_key();

  clear();

}


1;
