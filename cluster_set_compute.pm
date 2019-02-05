package cluster_set_compute;

# version 0.9
# GPL like
# aginies -at- mandrakesoft.com

use strict;
use MDK::Common;
use cluster_serverconf;
use cluster_commonconf;
use cluster_fonction_common;
use maui_cluster;
use server_cluster;

our @ISA = qw(Exporter);
our @EXPORT = qw(get_info_on_node pbs_nodes_file distcc_host mpi_lam set_compute help_comp main_comp test_nodesfile drak_ar_compute node_ad_compute mpi2);


sub print_info_c {
  system('clear');
  print "
 Setting up Cluster server with this configuration

 |-----------------------------------------------------------
 | Hostname               | " . cluster_commonconf::mysystem()->{HOSTNAME} . "
 |-----------------------------------------------------------
 | IP of DNS server       | " . cluster_serverconf::system_network()->{IPSERVER} . "
 |-----------------------------------------------------------
 | Domain                 | " . cluster_serverconf::dns_data()->{DOMAINNAME} . "
 |-----------------------------------------------------------
 | Nodesfile              | " . cluster_serverconf::cluster_data()->{NODESFILE} . "
 |-----------------------------------------------------------
 | Lam                    | " . cluster_commonconf::lam_data()->{LAM_NODES_FILE} . "
 |-----------------------------------------------------------
 | Mpi                    | " . cluster_commonconf::mpich_data()->{MPI_NODES_FILE} . "
 |-----------------------------------------------------------

";
}

sub value_set_c {
    my ($par) = @_;
    join(' ', map { s/([^: \t\n]*):\d:(\w):\w:\S*/$par $1/; if ($2 =~ /A/) { chomp_($_) } } cat_(cluster_serverconf::cluster_data()->{NODESFILE}));
}


sub test_nodesfile {
  if (!-f cluster_serverconf::cluster_data()->{NODESFILE}) {
    die ' - There is no ' . cluster_serverconf::cluster_data()->{NODESFILE} . ", exiting !\n";
  }
}

sub set_value_in_file {
    my ($file, $paracpu) = @_;
    output($file, map { s/([^: \t\n]*):(\d):(\w):\w:\S*:/$1$paracpu$2/; if ($3 =~ /A/) { $_ } } cat_(cluster_serverconf::cluster_data()->{NODESFILE}));
}

sub set_nodes_mpd {
    my ($file) = @_;
    output($file, map { s/([^: \t\n]*):\d:\w:\w:\S*:/$1/; if ($3 =~ /A/) { $_ } } cat_(cluster_serverconf::cluster_data()->{NODESFILE}));
}


# nodes file pbs
sub pbs_nodes_file {
  print " - Configuring Pbs node list\n";
  set_value_in_file(cluster_commonconf::pbs_data()->{PBS_HOME} . '/server_priv/nodes', " np=");
}


sub get_info_on_node {
  my ($node) = @_;
  my $nfile = cluster_serverconf::cluster_data()->{NODESFILE};
  print " - Information on node: $node
  (information from $nfile, not directly from node)";
  if (any { /$node/ } cat_($nfile)) {
    my @t = grep { /$node/ } cat_($nfile);
    my @l = $t[0] =~ /([^: \t\n]*):(\d*):(\w):(\w):(\S*):/;
    print "Compute node name: $l[0]
Number of cpu: $l[1]
Status compute: $l[2]
Status admin: $l[3]
Urpmi group: $l[4]
";
  } else {
    print " Node not Present in $nfile :-(\n
(Mispell ?)
You must enter complete compute_node_name with domainname
";
  }
}

sub node_ad_compute {
  my ($node, $status) = @_;
  my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
  print "$node, $status \n";
  if ($status == "D") {
    substInFile { s/($node.$domainname:\d:)\w(:\w:\S*:\n)/$1D$2/g; } cluster_serverconf::cluster_data()->{NODESFILE};
  } else { substInFile { s/($node.$domainname:\d:)\w(:\w:\S*:\n)/$1D$2/g; } cluster_serverconf::cluster_data()->{NODESFILE} }
  cluster_set_compute::drak_ar_compute();
}


# distcc
sub distcc_host {
  print " - Setting Distcc\n";
  my $a = value_set_c('');
  if (any { /DISTCC_HOSTS/ } cat_(cluster_commonconf::mysystem()->{PROFILE})) {
      substInFile { s/export DISTCC_HOSTS.*/export DISTCC_HOSTS="$a"/ } cluster_commonconf::mysystem()->{PROFILE};
  } else {
      append_to_file(cluster_commonconf::mysystem()->{PROFILE}, "export DISTCC_HOSTS=\"$a\"" . "\n");
  }
  create_profile_csh;
}

# mpi lam
sub mpi_lam {
  print " - Configure Mpi\n";
  save_config(cluster_commonconf::mpich_data()->{MPI_NODES_FILE});
  set_value_in_file(cluster_commonconf::mpich_data()->{MPI_NODES_FILE}, ":");
  print " - Configuring Lam\n";
  save_config(cluster_commonconf::lam_data()->{LAM_NODES_FILE});
  set_value_in_file(cluster_commonconf::lam_data()->{LAM_NODES_FILE}, " cpu=");
  append_to_file(cluster_commonconf::lam_data()->{LAM_NODES_FILE}, cluster_commonconf::mysystem()->{SHORTHOSTNAME} . '.' . cluster_serverconf::dns_data()->{DOMAINNAME});
}


sub mpi2 {
  print " - Configure Mpich2\n";
  save_config(cluster_commonconf::mpich_data()->{MPDHOSTS});
  set_nodes_mpd(cluster_commonconf::mpich_data()->{MPDHOSTS});
}

# to set in auto mode
sub set_compute {
  cluster_set_compute::print_info_c();
  test_nodesfile();
  save_config(cluster_serverconf::cluster_data()->{NODESFILE});
  save_config(cluster_commonconf::mysystem()->{PROFILE});
  save_config(cluster_commonconf::mysystem()->{PROFILECSH});
#  pbs_nodes_file();
#  maui_node();
  distcc_host();
  mpi_lam();
  set_mpd_conf();
  mpi2();

  server_cluster::cp_current_conf();
}

sub drak_ar_compute {
  save_config(cluster_serverconf::cluster_data()->{NODESFILE});
  save_config(cluster_commonconf::mysystem()->{PROFILE});
  save_config(cluster_commonconf::mysystem()->{PROFILECSH});
#  pbs_nodes_file();
  distcc_host();
  mpi_lam();
  mpi2();
#  maui_node();
  #service_do('maui', 'restart');
  server_cluster::cp_current_conf();
}

sub help_comp {
    print "
 HELP:
 |-----------------------------------------------------------------|
 | info               display info on configuration                |
 | distcc             set distcc environement (based on gexec env) |
 | mpi_lam            configure Mpi and Lam node configuration     |
 | doall              do all above                                 |
 |-----------------------------------------------------------------|

";
}

sub main_comp {
    my %opts = (
		'' => \&help_comp,
		info => \&cluster_set_compute::print_info_c,
		distcc => \&distcc_host,
		mpi_lam => \&mpi_lam,
		doall => \&set_compute,
		);

    if (my $f = $opts{$ARGV[0]}) {
        $f->();
    } else { 
	print " ** Dont know what todo ** \n";
    }
}

1;
