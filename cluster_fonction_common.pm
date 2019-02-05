package cluster_fonction_common;

# GPL like
# aginies@mandiva.com
# version 0.4

use strict;
use MDK::Common;
use cluster_commonconf;
use Socket;

our @ISA = qw(Exporter);
our @EXPORT = qw(interface_to_ip crea_wdir is_ip resolv_ip resolv_name AmIRoot service_adjust service_stop_them_now update_yp service_do active_rsh sys pamd_X fix_alternatives save_config get_nb_cpu update_network_nisdomain test_nisdomain set_pbs_servername test_pbs_version pbspro_common_config crea_dir_chmod correct_root_bashrc set_pbs_var profile_clustersh add_bg_xdm update_nsswitch enable_smart_on_disk smartmon_conf adjust_icewm_theme create_mpi_dir set_mpd_conf fix_missing_dir disable_gam_server load_module generate_ex_dolly_conf set_oar_servername disable_all_cluster_service create_profile_csh);

sub interface_to_ip {
    my ($interface) = @_;
    my ($ip) = `/sbin/ip addr show dev $interface` =~ /^\s*inet\s+(\d+\.\d+\.\d+\.\d+)/m;
    $ip;
}

sub load_module {
  my ($module) = @_;
  print " - load $module kernel module\n";
  system("modprobe $module");
}

sub crea_wdir {
  my ($w) = @_;
  print " - Creating Working temp Directory\n";
  if (-e $w) {
      rm_rf($w);
  }
    mkdir_p($w);
}

my $ip_regexp = qr/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
sub is_ip {
    my ($ip) = @_;
    my @fields = $ip =~ $ip_regexp or return;
    every { 0 <= $_ && $_ <= 255 } @fields or return;
    @fields;
}

sub resolv_ip {
  my ($ip) = @_;
  gethostbyaddr(Socket::inet_aton($ip), Socket::AF_INET());
}

sub resolv_name {
  my ($name) = @_;
  join(".", unpack "C4", (gethostbyname $name)[4]);
}

sub AmIRoot() {
  unless ($> == 0) {
    die "You are not root Exiting\n";
  }
}

sub profile_clustersh() {
  my $profd = cluster_commonconf::mysystem()->{PROFILE};
  system("touch $profd");
  chmod(0755, $profd);
}

our @unwanted = qw(alsa fam netfs atd dm crond kheader partmon sound harddrake);

# removing some anoying service on a server node
sub service_adjust() {
  print " - Stopping anoying services\n";
  foreach (@unwanted) {
    system('chkconfig', '--level', '2345', $_, 'off');
  }
}

sub create_profile_csh {
  my $profile = cluster_commonconf::mysystem()->{PROFILE};
  my $profilecsh = cluster_commonconf::mysystem()->{PROFILECSH};
  #print "- Adjust CSH env ($profilecsh)\n";
  cp_af($profile, $profilecsh);
  substInFile {
    s/^\s*export\s+([A-Za-z_0-9]+)=(.*)/setenv $1 $2/
  } $profilecsh;
}

sub service_stop_them_now() {
  print " - Stopping now, annoying services\n";
  foreach (@unwanted) {
    service_do('$_', 'stop');
  }
}

sub update_yp {
  my ($nd, $yps) = @_;
  save_config(cluster_commonconf::nis_data()->{YPCONF});
  print " - Updating " . cluster_commonconf::nis_data()->{YPCONF} . "\n";
  output(cluster_commonconf::nis_data()->{YPCONF}, <<EOF);
# /etc/yp.conf - ypbind configuration file
#domain NISDOMAIN server HOSTNAME
#	Use server HOSTNAME for the domain NISDOMAIN.
#
#domain NISDOMAIN broadcast
#	Use  broadcast  on  the local net for domain NISDOMAIN
#
#ypserver HOSTNAME
#	Use server HOSTNAME for the  local  domain.  The
#	IP-address of server must be listed in /etc/hosts.
domain $nd server $yps
EOF
}

sub save_config {
  my ($old) = @_;

  my $DATE = chomp_(`date +%d-%m-20%y`);
  if (-f $old) {
    print " - Backup of $old configuration\n";
    cp_af($old, $old . '.' . $DATE);
  }
  return($old . '.' . $DATE);
}

# update /etc/sysconfig/network
sub update_network_nisdomain {
  my ($nd) = @_;
  my $nf = cluster_commonconf::system_network()->{NETWORKFILE};
  my %conf = getVarsFromSh($nf);
  save_config($nf);
  print " - Set correct NISDOMAIN\n";
  setVarsInSh($nf, { %conf, NISDOMAIN => $nd });
}

# very simple fonction to call service
sub service_do {
  my ($name, $sdo) = @_;
  print " - service $name $sdo\n";
  if (-e "/etc/rc.d/init.d/" . $name) {
    system("/sbin/service $name $sdo");
  }
}

sub disable_all_cluster_service {
  map { system("chkconfig --del $_"); } qw(ccsd cman gfs fenced rgmanager);
}

sub set_oar_servername {
  my ($srv, $domc) = @_;
  print " - Setting OAR servername and DB hostname\n";
  my $oarconf = cluster_commonconf::oar_data()->{OAR_CONF};
  substInFile {
	  s/DB_HOSTNAME.*/DB_HOSTNAME=$srv/;
	  s/SERVER_HOSTNAME.*/SERVER_HOSTNAME=$srv/;
  } $oarconf;
}

sub set_pbs_servername {
  my ($srvpbs, $domc) = @_;
  print " - Setting servername\n";
  output(cluster_commonconf::pbs_data()->{PBS_HOME} . '/server_name', $srvpbs);
  save_config(cluster_commonconf::pbs_data()->{PBS_HOME} . '/mom_priv/config');
  output(cluster_commonconf::pbs_data()->{PBS_HOME} . '/mom_priv/config', <<EOF);
# MOM server configuration file
# if more than one value, separate it by comma.
## rule is defined by the name
# \$ideal_load 2.0
# \$max_load 3.5
## host allowed to connect to Mom server on unprivileged port
#\$restricted *.$domc
## log event :
# 0x1ff log all events + debug events
# 0x0ff just all events
\$logevent 0x0ff
## host allowed to connect to mom server on privileged port
\$clienthost $srvpbs
## alarm if the script hang or take very long time to execute (sec)
\$prologalarm 30
EOF

  if (-e cluster_commonconf::mysystem()->{PROFILE}) {
    if (!any { /PBS_SERVER/ } cat_(cluster_commonconf::mysystem()->{PROFILE})) {
      print " - Adjusting PBS_SERVER var\n";
      append_to_file(cluster_commonconf::mysystem()->{PROFILE}, <<EOF);
export PBS_SERVER=$srvpbs
EOF
    }
  }

  create_profile_csh;
  if (!any { /PBS_SERVER/ } cat_('/etc/pbs.conf')) {
    print " - Adjusting PBS_SERVER in pbs.conf\n";
    append_to_file('/etc/pbs.conf', "PBS_SERVER=$srvpbs");
  }
}


# active rsh service
sub active_rsh() {
  print " - Enable RSH\n";
  substInFile { s/disable.*/disable = no/ } cluster_commonconf::xinetd_data()->{XINETDDIR} . "/" . cluster_commonconf::xinetd_data()->{RSH};
  service_do('xinetd', 'restart');
}

sub sys {
    system(@_) == 0 or !$::testing and die "@_ Failed\n";
}

sub pamd_X() {
  output(cluster_commonconf::xconfig()->{PAMDXSERVER}, <<EOF);
#%PAM-1.0
auth       sufficient   /lib/security/pam_rootok.so
auth       required     /lib/security/pam_permit.so
account    required     /lib/security/pam_permit.so
EOF
}


# fix alternatives entries
# Done due to strange alternative bug
sub fix_alternatives() {
  system("update-alternatives --auto cpp");
}

sub test_nisdomain {
  my ($nd) = @_;
    print " - Testing NISdomain value\n";
    if (member($nd, qw(localdomain (none)))) {
    die "
No NISdomain set !
VALUE of NISDOMAIN:
" . $nd . "
please set a nisdomain in " . cluster_commonconf::system_network()->{NETWORKFILE} . "
or with nisdomainname command.
";
    }
}

sub test_pbs_version() {
  if (any { /pbspro/ } system("rpm -qa pbs")) {
    return 1;
  } else {
    return 0;
  }
}

sub crea_dir_chmod {
  my ($dir, $mod) = @_;
  mkdir_p($dir);
  system("chmod $mod $dir");
}

sub pbspro_common_config() {
  print " - PBSpro version installed adjusting PATH\n";
  set_pbs_var();
  append_to_file(cluster_commonconf::mysystem()->{PROFILE}, "export PATH=\$PATH:/usr/pbs/bin:/usr/pbs/sbin\n");
  create_profile_csh;
  my $ph = cluster_commonconf::pbs_data()->{PBS_HOME};
  print " - Creating Needed directory\n";
  map { crea_dir_chmod("$ph/$_", '0755'); $_ } qw(aux mom_logs);
  crea_dir_chmod("$ph/checkpoint", '0700');
  map { crea_dir_chmod("$ph/$_", '0751'); $_ } qw(mom_priv mom_priv/jobs);
  map { crea_dir_chmod("$ph/$_", '1777'); $_ } qw(spool undelivered);
  output("$ph/pbs_environment", <<EOF);
PATH=/usr/pbs/bin:/usr/pbs/sbin
EOF
}

sub generate_ex_dolly_conf() {
  my $f = "/etc/dolly_conf.cfg";
  print " - Creating $f\n";
  my $d = cluster_commonconf::mysystem()->{DOMAINNAME};
  output($f, <<EOF);
infile /dev/sda6
outfile /dev/sda6
server node23.$d
firstclient node23.$d
lastclient node21.$d
clients 3
node23.$d
node22.$d
node21.$d
endconfig
EOF
}

sub create_mpi_dir() {
    print "- Create mpich dir to avoid some pb";
    mkdir_p("/usr/share/mpich");
}

sub set_pbs_var() {
  my $ph = cluster_commonconf::pbs_data()->{PBS_HOME};
  my $pl = cluster_commonconf::pbs_data()->{PBS_LIB};
  my $pe = cluster_commonconf::pbs_data()->{PBS_EXEC};
  print " - Adjusting PBS_EXEC PBS_HOME\n";
  substInFile { s/PBS_LIB.*/PBS_LIB=>'$pl'/;
		s/PBS_EXEC.*/PBS_EXEC=>'$pe'/;
		s/PBS_HOME.*/PBS_HOME=>'$ph'/;
		} cluster_commonconf::mysystem()->{PROFILE};
  create_profile_csh;
}

sub enable_smart_on_disk() {
  my %drive;
  print " - Searching devices where SMART could be activated\n";
  foreach (cat_("/proc/partitions")) {
    if (/[s|h]d[a-z][1-99]/) {
        my ($hd) = /.*([s|h]d[a-z])[1-99]/;
        $drive{$hd} = "need to be activated";
    }
  }
  foreach my $disk (keys %drive) {
         print "        Activating SMART on /dev/$disk drive \n";
         system("smartctl --smart=on --offlineauto=on --saveauto=on /dev/$disk >/dev/null");
  }
}

sub smartmon_conf() {
  print " - Configure Smartmontools\n";
  my $d = cluster_commonconf::mysystem()->{DOMAINNAME};
  my $conf = cluster_commonconf::smartmontools_data()->{SMARTCONF};
  if (!any { /DEVICESCAN -H -l error -l selftest -t -I 194 -m admin\@$d/ } cat_($conf)) {
    output($conf, "DEVICESCAN -H -l error -l selftest -t -I 194 -s L/../../6/03 -m admin\@$d\n");
    service_do('smartd', 'restart');
  }
}

sub correct_root_bashrc {
  my ($pbssrv) = @_;
  if (! any { /\/usr\/pbs/ } cat_('/root/.bashrc')) {
  append_to_file('/root/.bashrc', <<EOF);
export PATH=\$PATH:/usr/pbs/bin:/usr/pbs/sbin
EOF
  substInFile { s/export PBS_SERVER.*/PBS_SERVER=$pbssrv/ } '/root/.bashrc';
  }
}

sub add_bg_xdm() {
  if (-d cluster_commonconf::xconfig()->{XDMCFG}) {
    if (!any { /\#TEST/ } cat_(cluster_commonconf::xconfig()->{XDMCFG} . '/Xsetup_0')) {
      print " - Configuring XDM background\n";
#      append_to_file(cluster_commonconf::xconfig()->{XDMCFG} . '/Xresources', "xlogin*geometry: 300x200-30-430");
      append_to_file(cluster_commonconf::xconfig()->{XDMCFG} . '/Xsetup_0', <<EOF);
qiv -z /usr/share/mdk/backgrounds/default.png
#TEST
EOF

my $BCK="/etc/X11/xinit.d/bck";
      if (! -f $BCK) {
	  print "add a default background";
	  output($BCK, <<EOF);
#!/bin/sh                                                                                                                                        qiv -z /etc/X11/CLUSTER-1024.jpg
EOF
    
    system("chmod 755 $BCK");
      }

    }
  } else {
    print " It seems there is no xdm server installed\n";
  }
}

sub adjust_icewm_theme() {
    my $icewmt = "/usr/X11R6/lib/X11/icewm/";
    if (! -f "$icewmt/theme") {
        output("$icewmt/theme", <<EOF);
Theme="microGUI/complex.theme"
EOF
append_to_file("$icewmt/themes/microGUI/complex.theme", "DesktopBackgroundImage='/etc/X11/CLUSTER-1024.jpg'");
    }
}


#Update the automount field in /etc/nsswitch.conf
sub update_nsswitch() {
    my $nisserver = cluster_serverconf::nis_data()->{NISSERVER};
    my $ldapserver = cluster_serverconf::ldap_data()->{LDAPSERVER};
    my $nssopt = ($nisserver ? "nis nisplus " : "")
    		. ($ldapserver ? "ldap" : "");
    if ($nssopt) {
	print " - update /etc/nisswitch.conf with $nssopt\n";
	substInFile {
	    s/passwd:.*/passwd: files $nssopt/g;
	    s/shadow:.*/shadow: files $nssopt/g;
	    s/group:.*/group: files $nssopt/g;
	    s/automount:.*/automount: $nssopt files/g;
	    if ($nisserver) {
		#FIXME: ldap for hosts ?
		s/hosts.*/hosts:      dns nis files/;
	    }
	} '/etc/nsswitch.conf';
    }
}

sub set_mpd_conf() {
  print " - Configure Mpd.conf\n";
  if (! -e cluster_commonconf::mpich_data()->{MPDCONF}) {
    output(cluster_commonconf::mpich_data()->{MPDCONF}, "secretword=guiblandcluster\n");
  }
}

# recup number of cpu on a particular node
sub get_nb_cpu {
  my ($node) = @_;
  print " - Getting number of cpu for node: $node\n";
  my $nbcpu = `ssh $node getconf _NPROCESSORS_ONLN`;
  chomp_($nbcpu);
}

sub fix_missing_dir() {
  print " - fix missing files/directory (mpi and lam)\n";
  my $ldir = cluster_commonconf::lam_data()->{LAM_DIR};
  my $mdir = cluster_commonconf::mpich_data()->{MPICH_DIR};
  my $lnode = cluster_commonconf::lam_data()->{LAM_NODES_FILE};
  my $mnode = cluster_commonconf::mpich_data()->{MPI_NODES_FILE};
  map { mkdir_p($_) } $mdir, $ldir;
  system("touch $mnode");
  system("touch $lnode");
}

sub disable_gam_server() {
  print " - kill anoying gam_server\n";
  my $gam = "/usr/lib/gam_server";
  if (-e $gam) {
    system("chmod -x /usr/lib/gam_server");
    system("killall -9 $gam");
  }
}

1;
