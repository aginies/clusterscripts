package client_cluster;

# version 0.4
# GPL like
# aginies@mandriva.com

use strict;
use MDK::Common;
use cluster_clientconf;
use cluster_fonction_common;
use fs_client;

our @ISA = qw(Exporter);
our @EXPORT = qw(get_domcomp retrieve_key retrieve_mpi_lam update_authorized update_authdkey_client update_mpimachine_client hp_merdouille recup_domain recup_hostname sync_time pbs_client_set test_network set_client help_client main_client create_desc_file coda_client auto_home);

sub print_info() {
  system('clear');
  print "

Setting up Client cluster with this configuration

|-----------------------------------------------------------
| Hostname               | " . cluster_commonconf::mysystem()->{HOSTNAME} . "
|-----------------------------------------------------------
| TFTPSERVER             | " . cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP} . "
|-----------------------------------------------------------
| Working dir            | " . cluster_commonconf::tftp_data()->{WDIR} . "
|-----------------------------------------------------------
| auth key               | " . cluster_commonconf::key_auth_ssh()->{KEY_AUTH} . "
|-----------------------------------------------------------
| ssh key                | " . cluster_commonconf::key_auth_ssh()->{KEY_SSH} . '.pub' . "
|-----------------------------------------------------------
| mpi file               | " . cluster_commonconf::mpich_data()->{MPI_COMPUTER} . "
|-----------------------------------------------------------
| lam file               | " . cluster_commonconf::lam_data()->{LAM_NODE} . "
|-----------------------------------------------------------

";
}

# retrieve auth_pub.pem id_rsa.pub machines.LINUX from SERVER
sub retrieve_key() {
  my $wdir = cluster_commonconf::tftp_data()->{WDIR};
  my $ser = cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP};
  my $ka = cluster_commonconf::key_auth_ssh()->{KEY_AUTH};
  my $ks = cluster_commonconf::key_auth_ssh()->{KEY_SSH};
  my $oarsshp = cluster_commonconf::oar_data()->{OAR_KEY_SSH_PUB};
  print " - Getting Key $ka $ks $oarsshp\n";
  local *F;
  open(F, "|cd $wdir;tftp $ser\n");
  print F "
get $ka
get $ks.pub
get $oarsshp
quit
";
  close F;
}

# retrieve mpi key
sub retrieve_mpi_lam() {
  my $wdir = cluster_commonconf::tftp_data()->{WDIR};
  my $ser = cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP};
  my $mcomp = cluster_commonconf::mpich_data()->{MPI_COMPUTER};
  my $lam = cluster_commonconf::lam_data()->{LAM_NODE};
  print " - Getting $mcomp file for MPI\n";
  print "   and $lam for ...lam !\n";
  local *F;
  open(F, "|cd $wdir; tftp $ser\n");
  print F "
get $mcomp\n
get $lam\n
quit
";
  close F;
}



# test network
sub test_network() {
  if (cluster_clientconf::catch_dhcp()->{IPOFCLIENT} == undef) {
    die qq(
        ERROR !!!
	Network is not Set !
	Exiting !);
  }
}

# setup client pbs
sub pbs_client_set() {
  print " - Set the OpenPBS Client configuration\n";
  system("/usr/bin/setup_pbs_client", cluster_clientconf::catch_dhcp()->{NEXT_SERVER});
}


# updating ~/.ssh/authorized_keys on client nodes
sub update_authorized() {
  my $ussh = cluster_commonconf::key_auth_ssh()->{USER_SSH_DIR};
  my $oardir = cluster_commonconf::oar_data()->{OAR_DIR};
  my $o = "$ussh/authorized_keys";
  my $oar = "$oardir/.ssh/authorized_keys";
  print " - Checking ssh dir for user\n";
  mkdir_p($ussh);
  mkdir_p("$oardir/.ssh/");
  save_config($o);
  print " - Updating sshkey for user\n";
  unlink $o; system("touch $o");
  cp_af(cluster_commonconf::tftp_data()->{WDIR} . '/' . cluster_commonconf::key_auth_ssh()->{KEY_SSH_PUB}, $o);
  cp_af(cluster_commonconf::tftp_data()->{WDIR} . '/' . cluster_commonconf::oar_data()->{OAR_KEY_SSH_PUB}, $oar);
}

# replace auth_pub.pem key
sub update_authdkey_client() {
  my $ka = cluster_commonconf::key_auth_ssh()->{KEY_AUTH};
  my $wdir = cluster_commonconf::tftp_data()->{WDIR};
  save_config("/etc/$ka");
  print " - Updating $ka key\n";
  cp_af("$wdir/$ka", "/etc/$ka");
}

# replace with good machine.LINUX file
sub update_mpimachine_client() {
  my $wdir = cluster_commonconf::tftp_data()->{WDIR};
  my $mcomp = cluster_commonconf::mpich_data()->{MPI_COMPUTER};
  my $lcomp = cluster_commonconf::lam_data()->{LAM_NODE};
  my $mpinode = cluster_commonconf::mpich_data()->{MPI_NODES_FILE};
  my $lamnode = cluster_commonconf::lam_data()->{LAM_NODES_FILE};
  save_config($mpinode);
  save_config($lamnode);
  print " - Updating $mpinode and $lamnode list\n";
  cp_af("$wdir/$mcomp", $mpinode);
  cp_af("$wdir/$lcomp", $lamnode);
}


# IA64 proble with keyboard mouse HP switch
sub hp_merdouille() {
# but bruno rulez :-)
  if (cluster_commonconf::mysystem()->{ARCH} =~ /ia64/) {
    system('lsusb', '-v');
  }
}

# recup domain and hostname
sub recup_domain() {
  my $fs = cluster_commonconf::system_network()->{NETWORKFILE};
  my $d = cluster_commonconf::mysystem()->{DOMAINNAME};
  my %conf = getVarsFromSh($fs);
  save_config($fs);
  print " - Set correct DOMAINNAME\n";
  setVarsInSh($fs, { %conf, DOMAINNAME => $d });
# conflict with nisdomain ?
#  sys("dnsdomainname $d");
}

sub recup_hostname() {
    my $fs = cluster_commonconf::system_network()->{NETWORKFILE};
    my $IP = interface_to_ip(cluster_clientconf::system_network()->{INTERFACE});
    my $NAME = resolv_ip($IP);
    print " - Adjusting HOSTNAME in $fs\n";
    if (any { /HOSTNAME/ } cat_($fs)) { 
	substInFile { s/^HOSTNAME.*/HOSTNAME=$NAME\n/s } $fs;
    } else {
	append_to_file($fs, "HOSTNAME=$NAME\n");
    }
    system("hostname $NAME");
    system("rm -rf $fs-scripts/draknet_conf*");
}

sub setup_ipoib() {
    my $IB_INTERFACE = cluster_clientconf::ib_network()->{IB_INTERFACE};
    my $IB_NETWORK = cluster_clientconf::ib_network()->{IB_NETWORK};
    my $IB_NETWORK_ = $IB_NETWORK;
    $IB_NETWORK_ =~ s/\.\d*$//;
    my $IB_NETMASK = '255.255.255.0';
    my $IB_BROADCAST = "$IB_NETWORK_.255";
    if (system("/sbin/ifconfig $IB_INTERFACE > /dev/null 2>&1" == 0)) {
	my $IP = interface_to_ip(cluster_clientconf::system_network()->{INTERFACE});
	$IP =~ s/\d*\.\d*\.\d*\.(\d*)/$1/;
	my $IB_IP = "$IB_NETWORK_.$IP";
	system('ifconfig', $IB_INTERFACE, $IB_IP);
	my $conf_interf = "/etc/sysconfig/network-scripts/ifcfg-$IB_INTERFACE";
	if (-f $conf_interf && grep(/^/, cat_($conf_interf))) {
	    substInFile { 
		s/^(\s*IPADDR=)(.*)/$1$IB_IP/;
		s/^(\s*NETMASK=)(.*)/$1$IB_NETMASK/;
		s/^(\s*NETWORK=)(.*)/$1$IB_NETWORK/;
		s/^(\s*BROADCAST=)(.*)/$1$IB_BROADCAST/;
	    } $conf_interf;
	} else {
	    output($conf_interf, <<EOF);
DEVICE=$IB_INTERFACE
BOOTPROTO=static
IPADDR=$IB_IP
NETMASK=$IB_NETMASK
IB_NETWORK=$IB_NETWORK
BROADCAST=$IB_BROADCAST
ONBOOT=yes
MII_NOT_SUPPORTED=yes
USERCTL=no
EOF
	}
    }
}

sub retrieve_clusternode_conf() {
    my $ser = cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP};
    my $wdir = cluster_commonconf::tftp_data()->{WDIR};
    my $nodeconf = cluster_commonconf::tftp_data()->{CLUSTERNODE_CONFIG};
    my $node_configuration = cluster_clientconf::node_config()->{CLUSTERNODE_CONFIG};
    print " - Getting node configuration
    |- TFTP Server is: $ser\n";
    local *F;
    open(F, "|cd $wdir;tftp $ser\n");
    print F "
get $nodeconf
quit
";
    close F;
    cp_af("$wdir/$nodeconf", $node_configuration);
}

# recup ntp server conf
sub sync_time() {
    my $ser = cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP};
    my $wdir = cluster_commonconf::tftp_data()->{WDIR};
    my $ip_ntp = cluster_clientconf::ntp()->{NTPSERVER};
    my $localtime = cluster_commonconf::tftp_data()->{LOCALTIME};
    print " - Getting NTP server configuration
    |- TFTP Server is: $ser\n";
    local *F;
    open(F, "|cd $wdir;tftp $ser\n");
    print F "
get $localtime
quit
";
    close F;
    cp_af("$wdir/$localtime", "/etc/$localtime");
    output(cluster_clientconf::ntp()->{NTPSTEPTICKERS}, $ip_ntp);
    substInFile { s/^\s*server\s.*/server $ip_ntp/ } cluster_clientconf::ntp()->{NTPCONF};
    print " - Restarting ntpd\n";
    service_do('ntpd', 'restart');
}

# retrieve nis
sub adjust_nisd() {
    my $ser = cluster_clientconf::nis()->{NISSERVER};
    my $nisd = cluster_clientconf::nis()->{NISDOMAIN};
    return if !$ser;
    $ser = resolv_ip($ser);
    print " - Adjusting nisdomain with $nisd\n";
    system("nisdomainname $nisd");
    update_network_nisdomain($nisd);
    update_yp(chomp_($nisd), $ser);
}


sub adjust_ldap() {
    print " - adjusting ldap conf\n";
    my $ldapconf = '/etc/ldap.conf';
    my $ldapserver = resolv_ip(cluster_clientconf::ldap()->{LDAPSERVER});
    my $ldapdomain = cluster_clientconf::ldap()->{LDAPDOMAIN};
    substInFile {
	s/^\s*host\s*.*/host $ldapserver/;
	s/^\s*base\s*.*/base $ldapdomain/;
	s/^\s*nss_base_passwd\s.*/nss_base_passwd $ldapdomain?sub/;
	s/^\s*nss_base_shadow\s.*/nss_base_shadow $ldapdomain?sub/;
	s/^\s*nss_base_group\s.*/nss_base_group $ldapdomain?sub/;
    } $ldapconf;
    foreach my $line (("host $ldapserver", "base $ldapdomain", "nss_base_passwd $ldapdomain\?sub",
	    "nss_base_shadow $ldapdomain\?sub", "nss_base_group $ldapdomain\?sub")) {
	append_to_file($ldapconf, $line)
		unless (grep {/^$line/} cat_($ldapconf));
    }
}

sub adjust_ldap_conf() {
    print " - adjusting ldap conf\n";
    my $ldapconf = "/etc/openldap/ldap.conf";
    my $ldapserver = cluster_clientconf::ldap()->{LDAPSERVER};
    my $ldapdomain = cluster_clientconf::ldap()->{LDAPDOMAIN};
    output($ldapconf,<<EOF);
URI ldap://$ldapserver
BASE $ldapdomain
EOF
}

sub auto_home() {
   print " - creating /etc/auto.master file and /etc/openldap/ldapserver file\n";
   my $ldapserver = resolv_ip(cluster_clientconf::ldap()->{LDAPSERVER});
   my $ldapdomain = cluster_clientconf::ldap()->{LDAPDOMAIN};
#   output("/etc/openldap/ldapserver",<<EOF)
#cluster_clientconf::ldap()->{LDAPSERVER}
#EOF
   output("/etc/autofs/auto.master",<<EOF);
/home   ldap:ou=auto.home,ou=Mounts,$ldapdomain rw,nosuid,nodev,soft,intr,relatime,sec=sys
EOF

   output("/etc/sysconfig/auto.master", <<EOF);
# Define default options for autofs.
# DEFAULT_MASTER_MAP_NAME - default map name for the master map.
DEFAULT_MASTER_MAP_NAME="auto.master"
# DEFAULT_TIMEOUT - set the default mount timeout (default 600).
DEFAULT_TIMEOUT=300
# DEFAULT_BROWSE_MODE - maps are browsable by default.
DEFAULT_BROWSE_MODE="no"
# DEFAULT_LOGGING - set default log level "none", "verbose" or "debug"
DEFAULT_LOGGING="debug"
# Define the default LDAP schema to use for lookups
# System default
#DEFAULT_MAP_OBJECT_CLASS="nisMap"
#DEFAULT_ENTRY_OBJECT_CLASS="nisObject"
#DEFAULT_MAP_ATTRIBUTE="nisMapName"
#DEFAULT_ENTRY_ATTRIBUTE="cn"
#DEFAULT_VALUE_ATTRIBUTE="nisMapEntry"
#
# Other common LDAP nameing
#
DEFAULT_MAP_OBJECT_CLASS="automountMap"
DEFAULT_ENTRY_OBJECT_CLASS="automount"
DEFAULT_MAP_ATTRIBUTE="ou"
DEFAULT_ENTRY_ATTRIBUTE="cn"
DEFAULT_VALUE_ATTRIBUTE="automountInformation"
EOF
}

sub get_domcomp() {
  my $ser = cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP};
  my $wdir = cluster_commonconf::tftp_data()->{WDIR};
  print " - Getting Domcomp domain\n";
  local *F;
  open(F, "|cd $wdir;tftp $ser\n");
  print F "
get domcomp
quit
";
  close F;
  my @domc = cat_("$wdir/domcomp");
  return $domc[0];
}

sub get_ipcomp() {
  my $ser = cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP};
  my $wdir = cluster_commonconf::tftp_data()->{WDIR};
  print " - Getting Compute IP from server\n";
  local *F;
  open(F, "|cd $wdir;tftp $ser\n");
  print F "
get ipcomp
quit
";
  close F;
  my @ipcomp = cat_("$wdir/ipcomp");
  return $ipcomp[0];
}

sub coda_client {
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

sub crea_pbsconf() {
  print " - create pbs.conf default config file\n";
  if (test_pbs_version() =~ /1/) {
    pbspro_common_config();
    output('/etc/pbs.conf', <<EOF);
#!/bin/sh
# init of some var needed by pbs service
# config: /etc/pbs.conf
PBS_HOME=/var/spool/PBS
PBS_EXEC=/usr/pbs
# set 1 to start the service
start_server=0
start_sched=0
start_mom=1
EOF
  }
}

sub declare_node_alive {
    print " - OAR node alive\n";
    system("oarnodesetting -s Alive");
}

sub permit_root_ssh() {
    my $SSHD = "/etc/ssh/sshd_config";
    print " - permit root login on node\n";
    if (any { /^PermitRootLogin/ } cat_($SSHD)) {
	substInFile { s/PermitRootLogin.*/PermitRootLogin yes/	} $SSHD;
    } else {
	append_to_file($SSHD, "PermitRootLogin yes\n");
    }
}

sub remove_dhclient() {
    my $TESTF="/etc/sysconfig/dhclient";
    if (!-f $TESTF) {
	print "- removing anoying dhclient scripts\n";
	system("urpme dhcp-client");
	system("touch $TESTF");
    }
}

sub create_desc_file() {
  my $desc = '/root/desc';
  if (-f $desc) {
    print " - a desc file already exist\n";
    } else {
	print " - Creating a default desc file for ka\n";
	system("/usr/bin/fdisk_to_desc");
#      print " - Creating a default desc file for ka\n";
#      output($desc, <<EOF);
#swap 512
#extended fill
#logical linux fill
#EOF
    }
}

sub set_client() {
  print_info();
  remove_dhclient();
  create_mpi_dir();
  enable_smart_on_disk();
  correct_root_bashrc();
  create_desc_file();
  test_network();
#  crea_pbsconf();
  smartmon_conf();
  crea_wdir(cluster_commonconf::tftp_data()->{WDIR});
#  set_pbs_servername(resolv_ip(get_ipcomp()), get_domcomp());
#  service_do('pbs_mom', 'restart');
  service_adjust();
  active_rsh();
  set_mpd_conf();

  retrieve_clusternode_conf();
  update_nsswitch();
  adjust_nisd();
  adjust_ldap();
  auto_home();

  set_oar_servername(resolv_ip(resolv_ip(cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP})));
  sync_time();
  retrieve_key();
  fix_missing_dir();
  retrieve_mpi_lam();
# avoid strange pb of missing file......
  sleep(1);
  system('sync');
  permit_root_ssh();
#
  disable_gam_server();
  update_authorized();
  update_authdkey_client();
  update_mpimachine_client();
  hp_merdouille();
  recup_domain();
  recup_hostname();
  pamd_X();
  generate_ex_dolly_conf();
  declare_node_alive();
#  add_bg_xdm();
#  adjust_icewm_theme();
}


sub help_client() {
    print "
 HELP:
 |-----------------------------------------------------------------|
 | activrsh                active the rsh service on node          |
 | ssh_root                permit root login                       |
 | recup_domain            retrieve the domain name for node       |
 | sync_time               synchronize time with server            |
 | clusternode_conf        retrieve node configuration             |
 | retrieve_mpi_lam        get the machines.LINUX file from server |
 | enable_smart            enable smartmon on hard drive           |
 | smartmon                configure smartmontools                 |
 | update_mpi_lam          update the file on node                 |
 | retrieve_key            get ssh_key and authd_key from server   |
 | desc                    create a default desc file for ka       |
 | update_authdkey_client  update authd key on node                |
 | update_sshkey_client    update ssh key on node                  |
 | nis_config              configure node with nis domain          |
 | ldap_config             configure node with ldap server         |
 | recup_hostname          set hostname                            |
 | ipoib                   setup ip over infiniband                |
 | service_adjust          disable anoying on node                 |
 | pamd_X                  adjust pamd for X                       |
 | bg_xdm                  modify xdm background                   |
 | fixalter                fixalternatives problem                 |
 | oar                     set OAR server                          |
 | coda_client             set a CODA client                       |
 | gfs_client              set a CCS client                        |
 | dolly                   generate a ie of dolly configuration    |
 | reload_c                special mode to avoid problem of autofs |
 | info                    print info on current configuration     |
 | doall                   all above                               |
 |-----------------------------------------------------------------|

";
}

sub main_client() {
  my %opts = (
	      '' => \&help_client,
	      info => \&print_info,
	      doall => \&set_client,
	      activrsh => \&active_rsh,
	      desc => \&create_desc_file,
	      enable_smart => \&enable_smart_on_disk,
	      smartmon => \&smartmon_conf,
	      update_mpi_lam => \&update_mpimachine_client,
	      update_authdkey_client => \&update_authdkey_client,
	      update_sshkey_client => \&update_authorized,
	      nis_config => sub { adjust_nisd() },
	      ldap_config => \&adjust_ldap,
	      ssh_root => \&permit_root_ssh,
	      ipoib => \&setup_ipoib,
	      bg_xdm => \&add_bg_xdm,
	      coda_client => \&coda_client_node,
	      gfs_client => \&gfs_client,
	      dolly => \&generate_ex_dolly_conf,
	      fixalter => \&fix_alternatives,
	      clusternode_conf => \&retrieve_clusternode_conf,
	      oar => sub { set_oar_servername(resolv_ip(resolv_ip(cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP}))) },
	      reload_c => sub { test_network(); crea_wdir(cluster_commonconf::tftp_data()->{WDIR}); sync_time(); crea_pbsconf();
				retrieve_key(); retrieve_mpi_lam(); sleep(1); system('sync'); update_authorized();
				update_authdkey_client(); update_mpimachine_client(); recup_domain(); recup_hostname(); pamd_X();
				set_oar_servername(resolv_ip(cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP}));
			        },
	     );

  $opts{$_} = $client_cluster::{$_} foreach
    qw(retrieve_clusternode_conf retrieve_mpi_lam retrieve_key sync_time pamd_X recup_domain recup_hostname service_adjust);

  if (my $f = $opts{$ARGV[0]}) {
    $f->();
  } else {
    print " ** Dont know what todo ** \n";
  }
}


1;
