package ldap_cluster;

# version 0.1
# GPL2
# aginies _at_ mandriva.com

use strict;
use MDK::Common;
use cluster_serverconf;
use server_cluster;
use cluster_fonction_common;

our @ISA = qw(Exporter);
our @EXPORT = qw(set_ldap_server configure_autofs5 needed_service_ldap main_ldap);


# print info of wath todo
sub print_info_n() {
    system("clear");
    print "

 Setting up LDAP server with this configuration (autofs, USER account)

 |-----------------------------------------------------------
 | Domainname            | " . cluster_serverconf::dns_data()->{DOMAINNAME} . "
 |-----------------------------------------------------------
 | USER home directory   | " . cluster_serverconf::cluster_data()->{HOMEDIR} . "
 |-----------------------------------------------------------
 | NFS server            | " . cluster_serverconf::ldap_data()->{NFSSERVER} . "
 |-----------------------------------------------------------
 | LDAP server           | " . cluster_serverconf::ldap_data()->{LDAPSERVER} . "
 |-----------------------------------------------------------
 | LDAP configuration    | " . cluster_serverconf::ldap_data()->{LDAPCONF} . "
 |-----------------------------------------------------------
 | LDAP domain           | " . cluster_serverconf::ldap_data()->{LDAPDOMAIN} . "
 |-----------------------------------------------------------

";
}
# end printinfo

# configure /etc/auto.*
sub configure_autofs5() {
  my $ip = cluster_serverconf::system_network()->{IPSERVER};
  my $hnis = cluster_serverconf::ldap_data()->{HOMEDIR};
  my $ldapserver = cluster_serverconf::ldap_data()->{LDAPSERVER};
  my $ldapbase = cluster_serverconf::ldap_data()->{LDAPBASE};
  my $ldapconfbase = cluster_serverconf::ldap_data()->{LDAPCONFBASE};
  my $ldapconf = cluster_serverconf::ldap_data()->{LDAPCONF};
  my $ldapdomain = cluster_serverconf::ldap_data()->{LDAPDOMAIN};
  print " - Using a good LDAP conf";
  save_config($ldapconf);
  system("cp -avf $ldapconfbase $ldapconf");

  print " - Add user NFS automount conf in ldap\n";
  system("service ldap restart");
  system("ldapadd -x -f $ldapbase -W -D cn=admin,$ldapdomain");
}

sub needed_service_ldap() {
  # restart ldap service
  service_do('ldap', 'reload');
  # reload nfs
  service_do('nfs-server', 'reload');
}

sub set_ldap_server() {
  print_info_n();
  # configure autofs to fit nis
  configure_autofs5();
  # update nsswitch.conf
  update_nsswitch();
  # update nfs to fit nis
  nfs_home();
  # restart all needed services
  needed_service_ldap();
}

sub help_ldap() {
    print "
 HELP:
 |------------------------------------------------------|
 | set_server     configure a LDAP server               |
 | info           print info of futur configuration     |
 |------------------------------------------------------|

";
}

sub main_ldap() {
    my %opts = (
                '' => \&help_ldap,
		set_server => \&set_ldap_server,
		info => \&print_info_n,
		);
    if (my $f = $opts{$ARGV[0]}) {
        $f->();
    } else {
	print " ** Dont know what todo ** \n";
    }
}



1;
