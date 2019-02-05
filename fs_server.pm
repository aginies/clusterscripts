package fs_server;

#version 0.1
# GPL like
# aginies@mandriva.com

use strict;
use MDK::Common;
use cluster_serverconf;
use cluster_fonction_common;

our @ISA = qw(Exporter);
our @EXPORT = qw(coda_server coda_client gfs_server generate_clusterconf gfs_node);

sub coda_server() {
  my $vice = "/usr/sbin/vice-setup";
  if (-e $vice) {
    print " - Set a CODA server\n";
    my $SIZE = cluster_serverconf::fs()->{CODASIZE};
    load_module("coda");
    service_do("venus", "stop");
    system("rm -rf /vice*");
    system("rm -rf /rvm*");
    mkdir_p("/rvm");
    map { system("touch /rvm/$_") } qw(LOG DATA);
    map { system("killall -9 $_") } qw(updatesrv updateclnt);
    system("rm -rf /vice*");
    local *F;
    open(F, "|/usr/sbin/vice-setup\n");
    print F "

yes
yes
/vice
y
cluster
cluster2
cluster3
0
12345
codaroot
yes
/rvm/LOG
20M
/rvm/DATA
$SIZE
y
/vicepa
y
2M
y

";
  close F;

  }
}

sub coda_client() {
  my $venus = "/usr/sbin/venus-setup";
  if (-e $venus) {
    load_module("coda");
    service_do("venus", "stop");
    my $codasrv = chomp_(cluster_serverconf::fs()->{CODASRV});
    my $cache = chomp_(cluster_commonconf::fs()->{CODACACHE});
    system("$venus $codasrv $cache");
    service_do("venus", "start");
  }
}

sub gfs_server() {
  map { load_module($_) } qw(cman gnbd gfs dlm dm-mod);
  service_do("ccsd", "stop");
  my $CCSSYS = cluster_commonconf::fs()->{CCSSYS};
  my $CCSNAME = cluster_commonconf::fs()->{CCSNAME};
  if (any { /CCSD_OPTS/ } cat_($CCSSYS)) {
    substInFile { s/CCSD_OPTS.*/CCSD_OPTS=$CCSNAME/ } $CCSSYS;
  } else {
    output($CCSSYS, "CCSD_OPTS=$CCSNAME");
  }
  generate_clusterconf();
  # remove cman service
  disable_all_cluster_service();
  service_do("ccsd", "start");
}

sub generate_clusterconf() {
  my $conf = cluster_commonconf::fs()->{CCSCONF};
  my $CCSNAME = cluster_commonconf::fs()->{CCSNAME};
  my $HOSTNAME = cluster_commonconf::mysystem()->{HOSTNAME};
  print " - Generate $conf\n";
  save_config($conf);
  mkdir_p("/etc/cluster");
  output($conf, <<EOF);
  <cluster name="$CCSNAME" config_version="1">
<clusternodes>
  <clusternode name="$HOSTNAME">
    <fence>
      <method name="human">
      <device name="last_resort" ipaddr="$HOSTNAME"/>
      </method>
    </fence>
  </clusternode>

EOF

  my $IPADD;
  append_to_file($conf, map { s|(\S*):\d:\w:(\w):\S*|\t<clusternode name="$1">\n\t<fence>\n\t<method name="human">\n\t\t<device name="last_resort" ipaddr="$1"/>\n\t</method>\n\t</fence>\n\t</clusternode>|; if ($2 =~ /A/) { $_ } } cat_(cluster_serverconf::cluster_data()->{NODESFILE}));

  # resolv ip for node:
  my $IPADD;
  foreach my $line (cat_($conf)) {
    my ($nodes) = $line =~ /ipaddr="(.*)"/;
    if ($nodes) {
      $IPADD = resolv_name($nodes);
      substInFile { s|ipaddr="$nodes"|ipaddr="$IPADD"| } $conf;
    }
  }

  append_to_file($conf, <<EOF);
</clusternodes>
<fencedevice name="last_resort" agent="fence_manual"/>
</cluster>
EOF

}

1;
