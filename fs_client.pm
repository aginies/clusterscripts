package fs_client;


use strict;
use MDK::Common;
use cluster_fonction_common;

our @ISA = qw(Exporter);
our @EXPORT = qw(gfs_client coda_client_node);


sub coda_client_node() {
  # base codasrv on ipcomp
  my $venus = "/usr/sbin/venus-setup";
  if (-e $venus) {
    load_module("coda");
    service_do("venus", "stop");
    my $cache = chomp_(cluster_commonconf::fs()->{CODACACHE});
    my $codasrv = chomp_(resolv_ip(get_ipcomp()));
    system("$venus $codasrv $cache");
    service_do("venus", "start");
  }
}

sub gfs_client() {
  map { load_module($_) } qw(cman gnbd gfs dlm);
  service_do("ccsd", "stop");
  my $CCSSYS = cluster_commonconf::fs()->{CCSSYS};
  my $CCSNAME = cluster_commonconf::fs()->{CCSNAME};
  if (any { /CCSD_OPTS/ } cat_($CCSSYS)) {
    substInFile { s/CCSD_OPTS.*/CCSD_OPTS=$CCSNAME/ } $CCSSYS;
  } else {
    output($CCSSYS, "CCSD_OPTS=$CCSNAME");
  }
  mkdir_p("/etc/cluster/");
  disable_all_cluster_service();
  map { system("chkconfig --del $_"); } qw(ccsd cman gfs fenced rgmanager);
#  system("ccsd $CCSNAME");
#  service_do("ccsd", "start");
}

1;
