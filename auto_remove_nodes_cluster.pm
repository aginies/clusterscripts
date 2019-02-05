package auto_remove_nodes_cluster;
# Author : Daniel Viard <dviard@mandrakesoft.com>
# Version 0.2
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
use wakeup_node_cluster;
use Getopt::Std;
use server_cluster;

sub usage {
  die "usage: $0 [-h] -d NodeNameToRemove [-a] [-c]
    -h          : this (help) message
    -d NodeName : full name of the node to remove
    -a          : auto (no enter key pause)
    -c          : color mode

    EXAMPLE: $0 -c -d node5.cluster.com
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
  my ($opt, $col) = @_;
  if ($opt->{c}) {
    print color('reset');
    print color getColors()->{$col};
  }
}

sub clear {
  print `clear` , "\n";
}

sub enter_key {
  print("\n\n (press ENTER key to continue)\n");
  <STDIN>;
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

sub main {
  my %opt;
  getopts("d:ach", \%opt) or usage();

  $opt{d} or usage();
  $opt{h} and usage();

  my $nodeName = $opt{d};

  # Print info
  clear();
  set_color(\%opt, 'INFO');
  print "|--------------------------------|\n";
  print "|        REMOVING NODE(S)        |\n";
  print "|--------------------------------|\n";
  print "\n";
  set_color(\%opt, 'NORMAL');

  set_color(\%opt, 'INFO');
  print "---------------------------------------------------------\n";
  print " - Removing $nodeName\n";
  print "---------------------------------------------------------\n";
  print "\n";
  set_color(\%opt, 'NORMAL');
  set_color(\%opt, 'WARNING');
  print "Press (Enter) to continue, Ctrl+C to abort...\n";
  set_color(\%opt, 'NORMAL');
  $opt{a} or enter_key();

  set_color(\%opt, 'INFO');
  print "---------------------------------------------------------\n";
  print " - Removing $nodeName from the node list\n";
  print "---------------------------------------------------------\n";
  print "\n";
  set_color(\%opt, 'NORMAL');
  remove_node_in_admin($nodeName);
  remove_node_in_compute($nodeName);

  set_color(\%opt, 'INFO');
  print "---------------------------------------------------------\n";
  print " - Removing $nodeName from the dhcp\n";
  print "---------------------------------------------------------\n";
  print "\n";
  set_color(\%opt, 'NORMAL');
  dhcpnode_cluster::remove_node_in_dhcp($nodeName);
  server_cluster::need_after_ar_node();

}

1;
