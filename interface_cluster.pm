package interface_cluster;

# Author : Daniel Viard <dviard@mandrakesoft.com>
# Version 0.1
# please report bug to: clic-public-dev@mandrakesoft.com

use strict;
use MDK::Common;
use cluster_fonction_common;
use cluster_serverconf;
use cluster_set_admin;
use cluster_set_compute;
use server_cluster;
use maui_cluster;


sub get_node_list() {
  my %nodes;
  my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
  foreach my $line (cat_(cluster_serverconf::cluster_data()->{NODESFILE})) {
    my ($name, $cpu, $activec, $active, $group) = $line =~ /(\S+)\.$domainname:(\d):(\w):(\w):(\S+):/;
    $nodes{$name} = { name => $name, cpu => $cpu, compute => $activec eq 'A' ? 1 : 0, admin => $active eq 'A' ? 1 : 0, group => $group };
}
  \%nodes;
}

sub get_number_of_nodes() {
    my $nodes = get_node_list();
    int(keys %$nodes);
}

sub get_partition_list() {
  maui_cluster::partitions_list();
}

sub get_group_list() {
  my $urpmi_conf = cluster_serverconf::urpmi_data()->{URPMICFG};

  my @group = cat_($urpmi_conf) =~ /(\S+):\S+:/g;
  [ uniq(@group) ];
}

sub get_users_list() {
  my %users = (
      map {
	  $_ => { map { $_ => 1 } @{maui_cluster::partitions_of_user($_)} };
#      } @{maui_cluster::get_maui_users()}
      } @{nis_cluster::get_nis_users()}
  );
  \%users;
}

our @ISA = qw(Exporter);
our @EXPORT = qw(get_loadavg get_oar_node_state get_oar_state get_node_in_dhcp);

sub get_loadavg {
  my ($node) = @_;
  # node3.guibland.com     1 (    0/   59) [  0.03,  0.13,  0.04] [   0.0,   0.0,   0.1,  97.9] OFF
  my @cmd = `gstat -a -l -1`;
  foreach (grep { /$node/ } @cmd) {
    (my ($load1, $load5, $load15, $u, $s, $idle) = /$node\s+\d\s\(.*\)\s\[\s+(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+\.\d+)\]\s+\[\s+(\d+\.\d+),\s+\d+\.\d+,\s+(\d+\.\d+),\s+(\d+\.\d+).*\]/);
    my $all = "[ $load1 | $load5 | $load15 ]  [ $u | $s | $idle ]";
    return $all;
  }
}

sub get_node_in {
    my ($nodes, $what) = @_;
    my $line;
    my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
    # if 'oar' laucnh oarnodes, if dhcp, launch dhcpnode
    if ($what =~ /oar/) {
    $line = `oarnodes -l`;
    } else {
    $line = `dhcpnode -l`;
    }
    map {
         $_ => $line =~ /$_(\.$domainname|\s)/ ? 1 : -1;
    } keys %$nodes; # 1 is here, 0 is unknown
}

sub get_states {
    my ($nodes) = @_;
    my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
    my $line = `gstat -a -l`;
    map {
      $_ => $line =~ /$_\.$domainname/ ? 1 : -1;
    } keys %$nodes; # -1 is down, 0 is unknown, 1 is up
}

sub get_oar_node_state {
    my ($nodes) = @_;
    my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
    my $line = `oarnodes -s`;
    map {
	   my ($state) = $line =~ /$_\.$domainname\s-->\s(\w+)/;
	   $_ => $state;
    } keys %$nodes;
}

sub get_oar_node_alive {
    my ($nodes) = @_;
    my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
    my $line = `oarnodes -s | grep Alive | cut -d ' ' -f 1`;
    map {
      $_ => $line =~ /$_\.$domainname/ ? 1 : -1;
    } keys %$nodes; # -1 is down, 0 is unknown, 1 is up
}


sub chg_node_active_admin {
  my ($node, $new_active) = @_;
  my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
  $new_active = $new_active ? 'A' : 'D';
  substInFile {
    s/($node\.$domainname:\d:\w:)\w(:.*)/$1$new_active$2/g;
  } cluster_serverconf::cluster_data()->{NODESFILE};
  cluster_set_admin::drak_ar_admin();
  urpmipp_ar_change("$node.$domainname");
}

sub chg_node_active_compute {
  my ($node, $new_active) = @_;
  $new_active = $new_active ? 'A' : 'D';
  my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
  substInFile {
    s/($node\.$domainname:\d:)\w(:\w:\S+:\n)/$1$new_active$2/g;
  } cluster_serverconf::cluster_data()->{NODESFILE};
  cluster_set_compute::drak_ar_compute();
}

# no more used
sub chg_node_part {
    my ($node, $new_part) = @_;
    my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
    substInFile {
	s/($node\.$domainname:\d:\w:\w)\S*(:\d+:\d+\n)/$1$new_part$2/g;
    } cluster_serverconf::cluster_data()->{NODESFILE};
    change_partition_of_node("$node.$domainname", $new_part);
}

sub chg_user_part {
  my ($partition, $user, $new_val) = @_;

  if ($new_val == 1) {
    maui_cluster::add_user_in_partition($user, $partition);
  } else {
    maui_cluster::remove_user_from_partition($user, $partition);
  }
}

sub cmd_to_exec {
  my ($mode, $selection, $verbose, $cmd) = @_;

  $verbose = $verbose == 1 ? ' -v' : '';

  my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};

  my $gexec_svrs = $ENV{GEXEC_SVRS};
  my $node_list = join(" ", map { "$_->{name}.$domainname" } @$selection);
  my $pt = "/usr/bin";
  if ($mode eq 'gexec') {
      "cd /tmp; export GEXEC_SVRS=\" $node_list\"; $pt/${mode}_wrap -n 0$verbose $cmd; export GEXEC_SVRS=\"$gexec_svrs\"";
  } elsif ($mode eq 'rshp') {
      "$pt/${mode}_wrap -c ssh$verbose -m " . join(" -m ", map { $_->{name} } @$selection) . " -- $cmd";
  } elsif ($mode eq 'rshp2') {
      "$pt/${mode} -c ssh$verbose -m " . join(" -m ", map { $_->{name} } @$selection) . " -- $cmd";
  }
}

sub cmd_poweron {
  my ($node) = @_;
  eval { sys("wakeup_node.pl -n $node") };
}

sub cmd_poweroff {
  my ($nodes) = @_;
  eval { sys("dssh $nodes -f -e halt") };
}

sub cmd_reboot {
  my ($nodes) = @_;
  eval { sys("dssh $nodes -f -e reboot") };
}

sub cmd_install_pkg {
  my ($groups, $pkgs) = @_;

  join(';', map { "urpmi --no-verify-rpm --parallel $_ --auto -a $pkgs " } @$groups);
}

sub cmd_remove_pkg {
  my ($groups, $pkgs) = @_;

  join(';', map { "urpme --parallel $_ --auto $pkgs " } @$groups);
}

sub add_nodes {
    my ($nb, $golden, $dev, $skip) = @_;
    "setup_auto_add_nodes.pl -a -g $golden -n $nb -p $dev $skip";
}

sub change_oar_state {
    # state could be Alive, Dead, Suspected, Absent
    my ($nodes, $state) = @_;
    my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
    join(" ; ", map { system("oarnodesetting -h $_.$domainname -s $state") } @$nodes);
}

sub remove_nodes_in_oar {
    my ($nodes) = @_;
    my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
    join(" ; ", map { system("oarnodesetting -h $_.$domainname -s Dead") } @$nodes);
    join(" ; ", map { system("oarremovenode $_.$domainname") } @$nodes);
}


sub remove_nodes {
    my ($nodes) = @_;
    map { remove_node($_) } @$nodes;
    map { dhcpnode_cluster::remove_node_in_dhcp($_) } @$nodes;
    remove_nodes_in_oar($nodes);
    server_cluster::need_after_ar_node();
#    join(" ; ", map { "setup_auto_remove_nodes.pl -a -d $_.$domainname" } @$nodes);
}

1;
