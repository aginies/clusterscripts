package nis_cluster;

# version 0.6
# GPL like
# aginies _at_ mandriva.com

use strict;
use MDK::Common;
use cluster_serverconf;
use server_cluster;
use cluster_fonction_common;

our @ISA = qw(Exporter);
our @EXPORT = qw(update_network set_nisdomain set_nis_server
		 configure_autofs4 adjust_makefile make_yp needed_service
                 set_nis_client help_nis main_nis get_nis_users add_user_admin);


# print info of wath todo
sub print_info_n() {
    system("clear");
    print "

 Setting up NIS server with this configuration, and LDAP conf

 |-----------------------------------------------------------
 | NIS server            | " . cluster_serverconf::nis_data()->{NISSERVER} . "
 |-----------------------------------------------------------
 | Domainname            | " . cluster_serverconf::dns_data()->{DOMAINNAME} . "
 |-----------------------------------------------------------
 | Nis Domain            | " . cluster_serverconf::nis_data()->{NISDOMAIN} . "
 |-----------------------------------------------------------
 | NIS home directory    | " . cluster_serverconf::cluster_data()->{HOMEDIR} . "
 |-----------------------------------------------------------
 | NIS DIR makefile      | " . cluster_serverconf::nis_data()->{NIS_DIRMAKEFILE} . "
 |-----------------------------------------------------------
 | NFS server            | " . cluster_serverconf::nis_data()->{NFSSERVER} . "
 |-----------------------------------------------------------
 | LDAP configuration    | " . cluster_serverconf::ldap_data()->{LDAPCONF} . "
 |-----------------------------------------------------------
 | LDAP domain           | " . cluster_serverconf::ldap_data()->{LDAPDOMAIN} . "
 |-----------------------------------------------------------

";
}
# end printinfo

# update /etc/sysconfig/network
sub update_network() {
  my $nd = cluster_serverconf::nis_data()->{NISDOMAIN};
  save_config(cluster_commonconf::system_network()->{NETWORKFILE});
  print " - Set nisdomain to: $nd\n";
  if (any { /NISDOMAIN/ } cat_(cluster_commonconf::system_network()->{NETWORKFILE})) {
    substInFile { s/NISDOMAIN.*/NISDOMAIN=$nd/g } cluster_commonconf::system_network()->{NETWORKFILE};
  } else {
    append_to_file(cluster_commonconf::system_network()->{NETWORKFILE}, "NISDOMAIN=$nd\n");
  }
}

# Setting nisdomainname
sub set_nisdomain() {
  my $nd = cluster_serverconf::nis_data()->{NISDOMAIN};
  print " - Running nisdomainname $nd\n";
  sys("nisdomainname $nd");
}


# configure /etc/auto.*
sub configure_autofs4() {
  my $nser = cluster_serverconf::nis_data()->{NISSERVER};
  my $hnis = cluster_serverconf::cluster_data()->{HOMEDIR};
  my $amast = cluster_serverconf::nis_data()->{AUTOMASTER};
  my $ah = cluster_serverconf::nis_data()->{AUTOHOME};
  save_config($amast);
  print " - Adjusting $amast\n";
  output($amast, <<EOF);
$hnis auto.home     --timeout=60
EOF

  save_config($ah);
  print " - Permission for all user to go in $ah\n";
  output($ah, <<EOF);
* -rw,nfs,soft,intr,nosuid,rsize=8192,wsize=8192       $nser:$hnis/&
EOF
}

sub adjust_makefile() {
# Makefile parameter
  print " - Updating " . cluster_serverconf::nis_data()->{NIS_DIRMAKEFILE} . " to add autofs\n";
  mkdir_p('/etc/mail');
  sys('touch /etc/mail/aliases');
  substInFile {
    s!^ALIASES!#ALIASES=/etc/aliases!g;
    s/^all.*/all:  passwd group hosts rpc services netid protocols/g;
  } cluster_serverconf::nis_data()->{NIS_DIRMAKEFILE} . '/Makefile';
  print " - You can add a user or remove it with:\n";
  print "   deluserNis.pl and adduserNis.pl command\n";
}

# create yp base
sub make_yp() {
  my $nmk = cluster_serverconf::nis_data()->{NIS_DIRMAKEFILE};
  #print " - Initialising YP base\n";
  #system('/usr/lib/yp/ypinit', ' -m', "\n");
  print " - do make " . cluster_serverconf::nis_data()->{NIS_DIRMAKEFILE} . "/Makefile\n";
  sys("make -C $nmk");
}

sub needed_service() {
  # restart service
  service_do('ypserv', 'restart');
  service_do('ypbind', 'restart');
  # reload nfs
  service_do('nfs-server', 'reload');
}

sub get_nis_users() {
  my @unwanted = qw(install maui nobody mpi);
  my @users;
  local *PASS;
  open(PASS, "/usr/bin/ypcat passwd|") or !$::testing and die " cant exec ypcat passwd!";
  while (<PASS>) {
    my ($login) = split(':');
    if (!member($login, @unwanted)) {
      push(@users, $login);
    }
  }
  close(PASS);
  [ @users ];
}

sub add_user_admin {
  print "add user admin (smartd and pbs)\n";
  system("adduserNis.pl -l admin -p \$1\$pNpuzDnO\$iZIgCN/LNI41GhqY9son50");
}

sub set_nis_server() {
  print_info_n();
  test_nisdomain(cluster_serverconf::nis_data()->{NISDOMAIN});
  # configure autofs to fit nis
  configure_autofs4();
  # set correct nis
  set_nisdomain();
  # create all make file needed
  adjust_makefile();
  make_yp();
  # update client conf file (also on server)
  update_yp(cluster_serverconf::nis_data()->{NISDOMAIN}, cluster_serverconf::nis_data()->{NISSERVER});
  # update conf file
  update_network();
  # update nsswitch.conf
  update_nsswitch();
  # update nfs to fit nis
  server_cluster::nfs_home();
  # restart all needed services
  needed_service();
#  add_user_admin();
}

sub set_nis_client() {
  test_nisdomain(cluster_serverconf::nis_data()->{NISDOMAIN});
  # set correct nis
  set_nisdomain();
  # update client conf file (also on server)
  update_yp(cluster_serverconf::nis_data()->{NISDOMAIN}, cluster_serverconf::nis_data()->{NISSERVER});
  # update conf file
  update_network();
  service_do('ypbind', 'restart');
}

sub help_nis() {
    print "
 HELP:
 |------------------------------------------------------|
 | set_server     configure a NIS server                |
 | set_client     configure a NIS client                |
 | nis_users      display list of nis users             |
 | info           print info of futur configuration     |
 | makeyp         rebuild map for nis server            |
 | set_nisdom     set a correct nisdomain               |
 | test_nisdom    test if NISdomain is correct          |
 | update_yp      update the client configuration file  |
 |------------------------------------------------------|

";
}

sub main_nis() {
    my %opts = (
                '' => \&help_nis,
		set_server => \&set_nis_server,
		set_client => \&set_nis_client,
		nis_users => \&get_nis_users,
		info => \&print_info_n,
		makeyp => \&make_yp,
		set_nisdom => \&set_nisdomain,
		test_nisdom => sub { test_nisdomain(cluster_serverconf::nis_data()->{NISDOMAIN}) },
		update_yp => sub { update_yp(cluster_serverconf::nis_data()->{NISDOMAIN}, cluster_serverconf::nis_data()->{NISSERVER}) },
		);
    if (my $f = $opts{$ARGV[0]}) {
        $f->();
    } else {
	print " ** Dont know what todo ** \n";
    }
}



1;
