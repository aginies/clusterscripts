package server_cluster;

# version 0.7
# GPL like
# aginies @ mandriva.com

use strict;
use MDK::Common;
use cluster_serverconf;
use nis_cluster;
use ldap_cluster;
use dns_cluster;
use cluster_fonction_common;
use user_common_cluster;
use cluster_set_admin;
use cluster_set_compute;
use fs_server;


our @ISA = qw(Exporter);
our @EXPORT = qw(update_tftpdir cp_in_workdir cp_in_gooddir regenerate_conf need_after_ar_node
		 generate_ssh_key generate_newauth ganglia save_dir reload_configuration_client
		 adjust_config_cpu recup_cpu main_server help_server cptftp config_shorewall update_pbs add_node
		 remove_node list_alive_node nfs_home);



sub print_info_s {
    system("clear");
    print "

 Setting up a Cluster server with this configuration

 |-----------------------------------------------------------
 | Hostname              | " . cluster_commonconf::mysystem()->{HOSTNAME} . "
 |-----------------------------------------------------------
 | Domainname            | " . cluster_serverconf::dns_data()->{DOMAINNAME} . "
 |-----------------------------------------------------------
 | Nis domain            | " . cluster_serverconf::nis_data()->{NISDOMAIN} . "
 |-----------------------------------------------------------
 | Nis Server            | " . cluster_serverconf::nis_data()->{NISSERVER} . "
 |-----------------------------------------------------------
 | NFS server            | " . cluster_serverconf::nis_data()->{NFSSERVER} . "
 |-----------------------------------------------------------
 | USER home directory   | " . cluster_serverconf::cluster_data()->{HOMEDIR} . "
 |-----------------------------------------------------------
 | User SSH dir          | " . cluster_commonconf::key_auth_ssh()->{USER_SSH_DIR} . "
 |-----------------------------------------------------------
 | Nodesfile             | " . cluster_serverconf::cluster_data()->{NODESFILE} . "
 |-----------------------------------------------------------
 | UrpmiGroup            | " . cluster_serverconf::urpmi_data()->{URPMIGROUP} . "
 |-----------------------------------------------------------
 | Range For node         | " . cluster_serverconf::cluster_data()->{STARTNODE} . ' - ' . cluster_serverconf::cluster_data()->{FINISHNODE} . "
 |-----------------------------------------------------------

";
}

sub nfs_home() {
  # test directory
  my $hnis = cluster_serverconf::cluster_data()->{HOMEDIR};
  if (-d $hnis) {
    print " - $hnis directory exist\n";
  } else {
    print " - Creating $hnis directory\n";
    mkdir_p($hnis);
  }

  # check nis home
  if (any { /$hnis/ } cat_(cluster_serverconf::system_network()->{NFSEXPORTS})) {
    print " - " . cluster_serverconf::system_network()->{NFSEXPORTS} . " ready\n";
  } else {
    print " - Adjusting " . cluster_serverconf::system_network()->{NFSEXPORTS} . "\n";
    append_to_file(cluster_serverconf::system_network()->{NFSEXPORTS}, "$hnis         *(async,rw,no_root_squash,no_subtree_check)\n");
    service_do('nfs-server', 'restart');
  }
}

sub nodesfile {
  # generate full node_list or not
  my ($full) = @_;
  # syntax in nodesfiles:
  # nodename:cpu:status:status:urpmi group
  my $nfile = cluster_serverconf::cluster_data()->{NODESFILE};
  my $n = cluster_serverconf::cluster_data()->{NODENAME};

  save_config($nfile);

  # define range for node list
  my $startnode = cluster_serverconf::cluster_data()->{STARTNODE};
  print " - Generating nodes list\n";
  my $nend = cluster_serverconf::cluster_data()->{STARTNODE};
  if ($full =~ /y/) { $nend = cluster_serverconf::cluster_data()->{FINISHNODE} }
  output($nfile, map { "$n$_." . cluster_serverconf::dns_data()->{DOMAINNAME} . ":1:A:A" . ':' . cluster_serverconf::urpmi_data()->{URPMIGROUP} . ":\n" } $startnode .. $nend);
}

sub add_node {
  my ($newn) = @_;
  my $nfile = cluster_serverconf::cluster_data()->{NODESFILE};
  if (! any { /$newn/ } cat_($nfile)) {
    append_to_file($nfile, $newn . ":1" . ":A:A:" . cluster_serverconf::urpmi_data()->{URPMIGROUP} . ":\n");
  }
}

sub add_fping_oar {
  if (! any { /^FPING/ } cat_(cluster_commonconf::oar_data()->{OAR_CONF})) {
      print " - Add fping in oar.conf\n";
      append_to_file(cluster_commonconf::oar_data()->{OAR_CONF}, "FPING_COMMAND=/bin/fping -q\n");
      }
}

sub add_prologue_oar {
  if (! any { /^PROLOGUE_EPILOGUE_TIMEOUT/ } cat_(cluster_commonconf::oar_data()->{OAR_CONF})) {
      print " - Add prologue/epilogue timeout in oar.conf\n";
      append_to_file(cluster_commonconf::oar_data()->{OAR_CONF}, "PROLOGUE_EPILOGUE_TIMEOUT=60\n");
    }
}

sub remove_node {
    my ($node) = @_;
    my $nfile = cluster_serverconf::cluster_data()->{NODESFILE};
    my $dc = cluster_serverconf::dns_data()->{DOMAINNAME};
    print " - Remove $node from list\n";
    substInFile {
	s/$node\.$dc:.*//;
	s/^\s*//;
    } cluster_serverconf::cluster_data()->{NODESFILE};
}

# modify number of cpu for a node in node_list
sub recup_cpu {
    my ($node) = @_;
    my $nfile = cluster_serverconf::cluster_data()->{NODESFILE};
    my $nbcpu = get_nb_cpu($node);
    substInFile { s/$node:\d:(.*)/$node:$nbcpu:$1/ } $nfile; 
}

sub adjust_config_cpu {
  foreach my $node (map { /([^: \t\n]*):\d:\S+:A:\S+:/ } cat_(cluster_serverconf::cluster_data()->{NODESFILE})) {
    server_cluster::recup_cpu($node);
  }
  cluster_set_compute::set_compute();
  cp_current_conf();
  reload_configuration_client();
}

sub node_present {
  my ($node, $f) = @_;
  if (!any { /$node/ } cat_($f)) { die "  ** node $node not present in $f! **" }
}

sub ask_number {
    while (<STDIN>) {
	if (!/^\d+$/) {
	    warn " ? please enter a number ! \n";
	} else { return $_ }
    }
}

# copying latest config in tftpserver dir
sub update_tftpdir {
    my $mcomp = cluster_commonconf::mpich_data()->{MPI_COMPUTER};
    my $lam = cluster_commonconf::lam_data()->{LAM_NODE};
    my $ka = cluster_commonconf::key_auth_ssh()->{KEY_AUTH};
    my $tftpd = cluster_serverconf::tftp_server_data()->{TFTPDIR};
    my $oardir = cluster_commonconf::oar_data()->{OAR_DIR};
    my $ksshp = cluster_commonconf::key_auth_ssh()->{KEY_SSH_PUB};
    my $oarsshp = cluster_commonconf::key_auth_ssh()->{OAR_KEY_SSH_PUB};
    my $wd = cluster_serverconf::cluster_data()->{WDIR};
    my $res = cluster_commonconf::ka_data()->{RESCUECLP};
    my $localtime = cluster_commonconf::tftp_data()->{LOCALTIME};
    my $inst = cluster_commonconf::install_data()->{INSTALLDIR};
    my $nodeconf = cluster_commonconf::tftp_data()->{CLUSTERNODE_CONFIG};
    print " - Updating $tftpd files\n";
    foreach (split(", ", qq($ka, $mcomp, $lam, $ksshp, $oarsshp, $localtime, $nodeconf))) { cp_af("$wd/$_", "$tftpd/$_") }
#    map { cp_af("$wd/$_", "$tftpd/$_") } $ka, $mcomp, $lam, $ksshp, $nisd, $domc, $ipcomp;
    cp_af($inst . '/install/stage2/' . $res, $tftpd);
}

sub cp_current_conf {
    my $wd = cluster_serverconf::cluster_data()->{WDIR};
    my $mpi = cluster_commonconf::mpich_data()->{MPI_COMPUTER};
    my $mpidir = cluster_commonconf::mpich_data()->{MPICH_DIR};
    my $lam = cluster_commonconf::lam_data()->{LAM_NODE};
    my $lamdir = cluster_commonconf::lam_data()->{LAM_DIR};
    my $ka = cluster_commonconf::key_auth_ssh()->{KEY_AUTH};
    my $tftpd = cluster_serverconf::tftp_server_data()->{TFTPDIR};
    my $ksshp = cluster_commonconf::key_auth_ssh()->{KEY_SSH_PUB};
    my $localtime = cluster_commonconf::tftp_data()->{LOCALTIME};
    my $nisd = 'nisdomain';
    my $domc = 'domcomp';
    print " - Copy current config in $tftpd directory\n";
    cp_af("/etc/$ka", "$tftpd/$ka");
    cp_af("/etc/$localtime", "$tftpd/$localtime");
    cp_af("/root/.ssh/$ksshp", "$tftpd/$ksshp");
    cp_af("$lamdir/$lam", "$tftpd/$lam");
    cp_af("$mpidir/$mpi", "$tftpd/$mpi");
    generate_nis();
    foreach (split(", ", qq($nisd))) { cp_af("$wd/$_", "$tftpd/$_") }
#    map { if (-f $_) { cp_af("$wd/$_", "$tftpd/$_") } } $nisd, $domc;
}


sub cp_oar_pubkey {
    my $oarsshp = cluster_commonconf::oar_data()->{OAR_KEY_SSH_PUB};
    my $oardir = cluster_commonconf::oar_data()->{OAR_DIR};
    my $tftpd = cluster_serverconf::tftp_server_data()->{TFTPDIR};
    print " - Copy $oardir/.ssh/id_dsa.pub in $tftpd directory\n";
    cp_af("$oardir/.ssh/id_dsa.pub", "$tftpd/$oarsshp");
}

sub reset_knowhosts {
  my $knowhosts = "/root/.ssh/known_hosts";
  unlink($knowhosts);
}


# copy existing mpi lam in Work dir
sub cp_in_workdir {
  my $wd = cluster_serverconf::cluster_data()->{WDIR};
  my $mcomp = cluster_commonconf::mpich_data()->{MPI_COMPUTER};
  my $lamn = cluster_commonconf::lam_data()->{LAM_NODE};
  my $lnode = cluster_commonconf::lam_data()->{LAM_NODES_FILE};
  my $mnode = cluster_commonconf::mpich_data()->{MPI_NODES_FILE};
  my $localtime = cluster_commonconf::tftp_data()->{LOCALTIME};
  my $nodeconfig = cluster_serverconf::cluster_data()->{CLUSTERNODE_CONFIG};
  my $nodeconf = cluster_commonconf::tftp_data()->{CLUSTERNODE_CONFIG};
  print " - Copying file in $wd\n";
  cp_af($mnode, "$wd/$mcomp");
  cp_af($lnode, "$wd/$lamn");
  cp_af("/etc/$localtime", "$wd/$localtime");
  cp_af($nodeconfig, "$wd/$nodeconf");
}

# copying key in their normal dir
sub cp_in_gooddir {
  my $wd = cluster_serverconf::cluster_data()->{WDIR};
  my $ka = cluster_commonconf::key_auth_ssh()->{KEY_AUTH};
  my $ks = cluster_commonconf::key_auth_ssh()->{KEY_SSH};
  my $ksshp = cluster_commonconf::key_auth_ssh()->{KEY_SSH_PUB};
  my $usshd = cluster_commonconf::key_auth_ssh()->{USER_SSH_DIR};
  print " - Copying file in normal dir\n";
  foreach (split(", ", qq($ka, auth_priv.pem))) { cp_af("$wd/$_" , "/etc/$_") }
#  map { cp_af("$wd/$_" , "/etc/$_") } $ka, 'auth_priv.pem';
  foreach (split(", ", qq($ksshp, $ks))) { cp_af("$wd/$_", "$usshd/$_") } 
#  map { cp_af("$wd/$_", "$usshd/$_") } $ksshp, $ks;
}

# generate user ssh key
sub generate_ssh_key {
  my $usshd = cluster_commonconf::key_auth_ssh()->{USER_SSH_DIR};
  my $bin = cluster_commonconf::mysystem()->{BIN_PATH};
  my $wd = cluster_serverconf::cluster_data()->{WDIR};
  my $ks = cluster_commonconf::key_auth_ssh()->{KEY_SSH};
  print " - Checking ssh dir for user\n";
  mkdir_p($usshd);
  print " - Generating New ssh key\n";
  system("ssh-keygen -t dsa -f  $wd/$ks -N ''");
}

sub server_ssh_auth {
  print " - Authorized key on root\n";
  my $ussh = "/root/.ssh";
  if (-d $ussh) {
    my $o = "$ussh/authorized_keys";
    my $ssh_pub = cluster_commonconf::key_auth_ssh()->{KEY_SSH_PUB};
    system("cat $ussh/$ssh_pub >> $o");
    system("chmod 600 $o");
  }
}

sub generate_nis {
  my $wd = cluster_serverconf::cluster_data()->{WDIR};
  set_nisdomain();
  print " - Generating nisdomain file for tftp \n";
  system("nisdomainname > $wd/nisdomain");
}

# generate authd key
sub generate_newauth {
  print " - Generating New auth key\n";
  my $wd = cluster_serverconf::cluster_data()->{WDIR};
  my $ka = cluster_commonconf::key_auth_ssh()->{KEY_AUTH};
  sys("openssl genrsa -rand /proc/urandom -out $wd/auth_priv.pem");
  sys("openssl rsa -in $wd/auth_priv.pem -pubout -out $wd/$ka");
}


sub ganglia {
  my $gmond = cluster_serverconf::ganglia_data()->{GMONDCONF};
  my $gmetad = cluster_serverconf::ganglia_data()->{GMETADCONF};
  my $clname = cluster_serverconf::ganglia_data()->{CLUSTER_NAME};
  my $ip = cluster_serverconf::system_network()->{IPSERVER};
  foreach (split(", ", qq(gmond, gmetad))) { if (! -f "/etc/$_.conf")  { die " - $_ seems to be not installed, exiting !!!!!\n" } }
#  map { if (! -f "/etc/$_.conf")  { die " - $_ seems to be not installed, exiting !!!!!\n" } } qw(gmond gmetad);

  print " - Setting basic conf for GMETAD and GMOND\n";
  my $was_there;
  substInFile { $was_there = 1 if  s/^name\s+.*\n/name $clname\n/ } $gmond;
  append_to_file($gmond, "name $clname\n") if !$was_there;
  $was_there = undef;
  substInFile { $was_there = 1 if  s/^data_source\s+.*\n/data_source "$clname" 127.0.0.1 $ip 8689\n/ } $gmetad;
  append_to_file($gmetad, "data_source $clname 127.0.0.1 $ip:8649") if !$was_there;
}


sub save_dir {
  my $bck = cluster_serverconf::cluster_data()->{REP_SAVE};
  print " - Creating $bck\n";
  mkdir_p($bck);
  system('chmod', '0755', $bck);
}

sub short_doc {
  my $inst = cluster_commonconf::install_data()->{INSTALLDIR};
  my $varh = cluster_serverconf::doc()->{VARHTML};
  my $hos = cluster_commonconf::mysystem()->{HOSTNAME};
  my $ip = cluster_serverconf::system_network()->{IPEXT};
  if (-d "$inst/doc/cluster") {
    print " - Link to doc\n";
    cp_af($inst . '/doc/cluster', $varh . '/doccluster');
    system('chown', '-R', 'apache.apache', $varh);
    cp_af($inst . '/doc/pxe', $varh . '/pxe');
  } else {
    print " - no $inst/doc/cluster found :-(\n";
  }
  substInFile { s/HOSTNAMESET/$ip/ } $varh . '/index.html';
}

sub tftp_blksize {
  # $o should be with W or not N
  my ($o) = @_;
  my $tftpd = cluster_serverconf::tftp_server_data()->{TFTPDIR};
  my $tftp = cluster_commonconf::xinetd_data()->{TFTP};
  my $xinetd = cluster_commonconf::xinetd_data()->{XINETDDIR};
  if ($o =~ /W/) {
    substInFile { s/server_args.*/server_args = -r blksize -s $tftpd/ } "$xinetd/$tftp";
  } else {
    substInFile { s/server_args.*/server_args = -s $tftpd/ } "$xinetd/$tftp";
  }
  service_do('xinetd', 'restart');
}

sub clean_key {
  print " - Cleaning Working Directory\n";
  my $wd =  cluster_serverconf::cluster_data()->{WDIR};
  if (-d $wd) { rm_rf($wd) }
  mkdir_p($wd);
}

sub add_user_maui {
  # create maui user if not exist
  if (!any { /pbs/ } cat_('/etc/group')) {
    print " - Creating pbs group\n";
    system('groupadd pbs');
  }
  if (!any { /maui/ } cat_('/etc/passwd')) {
    print " - Hmmm, maui user doesnt exist, Creating maui user\n";
    system('/usr/sbin/useradd -g pbs -d /var/spool/maui -s /bin/bash maui');
    print "    |- adjusting permission on files\n";
    system("chown -R maui /var/spool/maui");
  }
}

sub reset_server_first_node {
  print " - Now reseting server configuration to first node !\n";
  print "   are you sure ?\n";
  sleep(3);
  print " - Erasing old configuration\n";
  my $n = cluster_serverconf::cluster_data()->{NODENAME};
  add_node($n . "1" . '.' . cluster_serverconf::dns_data()->{DOMAINNAME}, cluster_serverconf::cluster_data()->{NODESFILE});
  cluster_set_admin::set_admin();
  cluster_set_compute::set_compute();
}

sub mysql_network {
	substInFile { 
		s/--skip-networking//g;
	} "/etc/sysconfig/mysqld";
	service_do("mysqld-max", "restart");
	if (-f "/etc/my.cnf") {
	  substInFile {
	    s/skip-networking//g;
	  } "/etc/my.cnf";
	}
}

sub set_server {
  profile_clustersh();
  fix_missing_dir();
  crea_wdir(cluster_serverconf::cluster_data()->{WDIR});
  create_mpi_dir();
  print_info_s();
  #add_user_maui();
  smartmon_conf();
  disable_gam_server();
  correct_root_bashrc(cluster_commonconf::mysystem()->{SHORTHOSTNAME});
  mysql_network();
  generate_ssh_key();
  generate_newauth();
  set_nisdomain();
  add_fping_oar();
  add_prologue_oar();
# gmond is auto configured
#  ganglia();
  save_dir();
  cp_in_workdir();
  cp_in_gooddir();
#  set_oar_servername(cluster_commonconf::mysystem()->{HOSTNAME}, cluster_serverconf::dns_data()->{DOMAINNAME});
  cp_oar_pubkey();
  update_tftpdir();
#  short_doc();
  clean_key();
  nodesfile('n');
  config_shorewall();
  config_dhclient();
}

sub cptftp {
    cp_in_workdir();
    update_tftpdir();
    print "
    NOW Reload configuration launch on client:
    clusterautosetup-client reload
    or you will lost all remote command on NODES !
";

    print "
         ###################
        # !!! WARNING !!! #
        ###################
        ARE YOU sure that client NODES have retrieve all needed key?

        launch on client:
        -----------------
        clusterautosetup-client reload

        Or you will lost all remote command on NODES !!!
        (be sure you know what you are doing)

        Have you update the client with the new key ?
        Last time to be sure (crtl+c to abort)
";
    sleep 4;
    print " - Updating Key on server\n";
}

sub need_after_ar_node {
  regenerate_conf();
  reload_configuration_client();
  regenerate_rhosts();
  urpmipp_default();
#  update_pbs();
  reset_knowhosts();
}

sub update_pbs {
  cluster_set_compute::pbs_nodes_file();
  system('gexec -n 0 service pbs_mom restart');
  service_do('openpbs', 'restart');
}


sub regenerate_conf {
  print "---------------------------------------------------------\n";
  print " - Regenerating configuration file\n";
  print "---------------------------------------------------------\n";
  cluster_set_admin::set_admin();
  cluster_set_compute::set_compute();
  print " - Copying configuration file in the tftp directory\n";
  cp_current_conf();
}

sub list_alive_node {
    my @nodesalive = `oarnodes -s | grep Alive | cut -d ' ' -f 1`;
    return @nodesalive;
}

sub reload_configuration_client {
    print " - Reload MPICH & LAM/MPI configuration filesfrom the server\n";
    my @nodesA = list_alive_node();
    my $rshparg;
    foreach (@nodesA) {
	    $rshparg = $rshparg . " -m " . $_;
	    chomp($rshparg);
    }
    my $cmd = "rshp2 $rshparg -- setup_client_cluster.pl ";
    print "   $cmd\n";
    map { system("$cmd $_") } qw(retrieve_mpi_lam update_mpi_lam);
#    foreach (split(", ", qq(retrieve_mpi_lam, update_mpi_lam))) { system("rshpn setup_client_cluster.pl $_") }
#  map { system("rshpn setup_client_cluster.pl $_") } qw(retrieve_mpi_lam update_mpi_lam);
}

sub config_dhclient {
  my $ext_interf = cluster_serverconf::system_network()->{EXTERNAL_INTERFACE};
  my $dhclient_config = "/etc/dhclient-$ext_interf.conf";
  my $domain_name = cluster_serverconf::dns_data()->{DOMAINNAME};
  if (! -f $dhclient_config) {
	print " - config_dhclient: creating $dhclient_config\n";
	output($dhclient_config, "prepend domain-name-servers 127.0.0.1;\n",
				 "prepend domain-name \"$domain_name \";\n");
  } else {
	print " - config_dhclient: file $dhclient_config aldready there\n";
  }
}

sub config_shorewall {
  my $interfaces = cluster_serverconf::shorewall_data()->{INTER};
  my $masq = cluster_serverconf::shorewall_data()->{MASQ};
  my $zones = cluster_serverconf::shorewall_data()->{ZONES};
  my $policy = cluster_serverconf::shorewall_data()->{POLICY};
  my $rules = cluster_serverconf::shorewall_data()->{RULES};
  my $admin = cluster_serverconf::system_network()->{ADMIN_INTERFACE};
  my $ext = cluster_serverconf::system_network()->{EXTERNAL_INTERFACE};
  my $ipext = cluster_serverconf::system_network()->{IPEXT};
  my $ipserver = cluster_serverconf::system_network()->{IPSERVER};
  my $network_config = '/etc/sysconfig/network';

  print " - Activate FORWARD_IPV4 in $network_config\n";
  substInFile { s/^FORWARD_IPV4=.*/FORWARD_IPV4=true/ } $network_config;
  system('sysctl -w net.ipv4.ip_forward=1');

  print " - First configuration of shorewall\n";
  print "   |- saving all default previous configuration\n";
  foreach (split(", ", qq($interfaces, $masq, $zones, $policy, $rules))) { save_config($_) }
#  map { save_config($_); $_ } $interfaces, $masq, $zones, $policy, $rules;
  print "   |- now configuration of $interfaces\n";
  output($interfaces, <<EOF);
admin   $admin  detect
ext     $ext    -          routefilter
ib      ib+     detect
EOF

    print "   |- Setting default $policy\n";
  print "      - cleaning previous default configuration\n";
  output($policy, <<EOF);
fw  ext  ACCEPT
fw  admin  ACCEPT
admin  ext  ACCEPT
admin  fw  ACCEPT
admin  ib ACCEPT
fw  ib ACCEPT
ext  all  DROP  info
all  all  REJECT  info
EOF

    print "   |- Setting default $rules (accept 22 and 80 on $ext)\n";
  output($rules, <<EOF);
#
# Accept SSH connections
#
ACCEPT   all    fw       tcp   22

# Accept Web
ACCEPT   all    fw   tcp   80

DNAT    ext:$ipext     admin:$ipserver

EOF

    print "   |- Configuration of $zones\n";
  output($zones, <<EOF);
ext    ipv4 	# External network
admin  ipv4 	# Administration network
ib     ipv4 	# Infiniband Network
fw     firewall
EOF

    print "   |- Setting default masquerade ($admin to $ext)\n";
  output($masq, <<EOF);
$ext $admin
EOF

  service_do('shorewall', 'restart');
}

sub add_server_in_cluster {
  my $DOMAINNAME = cluster_serverconf::dns_data()->{DOMAINNAME};
  my $node_name = cluster_serverconf::cluster_data()->{NODENAME};

  my $IFA = cluster_serverconf::system_network->{ADMIN_INTERFACE};
  my $IPA = interface_to_ip($IFA);
  my $IPEND = dns_cluster::get_spe_ip('ipend', $IPA);

  add_node("$node_name$IPEND.$DOMAINNAME");
  active_rsh();
  need_after_ar_node();
  server_ssh_auth();
}


sub help_server {
    print "
 HELP:
 |-------------------------------------------------------------------|
 | info          display info of what will be done                   |
 | resetssh      reset root ssh knowhosts                            |
 | doc           get documentation on http                           |
 | idesk         configure idesk                                     |
 | ganglia       configure gmetad and name of Metcluster             |
 | nisfile       generate nis file for tftp                          |
 | gennodeone    generate node list for auto_add_node                |
 | gennodefull   generate node list using full range                 |
 | activrsh      activate the service rsh                            |
 | genkey        regenerate key                                      |
 | service       adjust service on server                            |
 | smartmon      do smartmontools conf                               |
 | coda_srv      set a CODA server                                   |
 | coda_client   set a CODA client                                   |
 | gfs_srv       set a ccsd configuration and join it                |
 | cptftp        copy ssh, authd keys, machines.LINUX, NTP nisdomain |
 |               from Work dir to tfpdir                             |
 | shorewall     configure shorewall                                 |
 | dhclient      configure dhclient                                  |
 | cp_conf       copy current config to tftpdir                      |
 | updatefile    copy the key in their working dir                   |
 |               authd key in /etc/ , ssh key in user dir            |
 |               machines.LINUX in MPI directory                     |
 | With_blk      add blksize parameter to tftpserver                 |
 | NO_blksz      remove blksize parameter to tftpserver              |
 | reset         reset server to first node configuration (DANGEROUS)|
 | need_ar       adjust configuration after remove or add node       |
 | doall         do all above                                        |
 |-------------------------------------------------------------------|

";
}

sub main_server {
  my %opts = (
	      '' => \&help_server,
	      doc => \&short_doc,
	      info => \&print_info_s,
	      adjust_cpu => sub { adjust_config_cpu() },
	      activrsh => \&active_rsh,
	      gennodeone => sub { nodesfile('n') },
	      resetssh => \&reset_knowhosts,
	      gennodefull => sub { nodesfile('y') },
	      nisfile => \&generate_nis,
	      service => \&service_adjust,
	      smartmon => \&smartmon_conf,
	      With_blk => sub { tftp_blksize('W') },
	      NO_blksz => sub { tftp_blksize('N') },
	      ganglia => \&ganglia,
	      doall => \&set_server,
	      shorewall => \&config_shorewall,
	      dhclient => \&config_dhclient,
	      genkey => sub { clean_key(); generate_ssh_key(); generate_newauth() },
	      updatefile => \&cp_in_gooddir,
	      cptftp => \&cptftp,
	      cp_conf => \&cp_current_conf,
	      reset => \&reset_server_first_node,
	      need_ar => \&need_after_ar_node,
	      coda_srv => \&coda_srv,
	      coda_client => \&coda_client,
	      gfs_srv => \&gfs_server, #sub { generate_clusterconf(); gfs_server() },
	     );

    if (my $f = $opts{$ARGV[0]}) {
        $f->();
    } else {
	print " ** Dont know what todo ** \n";
    }
}


1;
