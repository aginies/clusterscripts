package dhcpdconf_server_cluster;

# Author : Daniel Viard <dviard@mandrakesoft.com>
# Version 0.1
# please report bug to: cooker@mandrakesoft.com

use strict;
use Term::ANSIColor;
use MDK::Common;
use cluster_serverconf;
use cluster_commonconf;
use cluster_fonction_common;
use dns_cluster;

sub clear {
  print `clear` , "\n";
}

sub printinfo {
  my $ip_adm = cluster_serverconf::system_network()->{IPSERVER};
  my $NORMIPADM = dns_cluster::get_spe_ip('ipnorm', $ip_adm);
  clear();
  print "Setting up dhcpd.conf with this configuration:

|---------------------------------------------------------
| admin domain name     | " . cluster_serverconf::dns_data()->{DOMAINNAME} . "
|---------------------------------------------------------
| admin server ip       | $ip_adm
|---------------------------------------------------------
| DHCP range ip         | $NORMIPADM." . cluster_serverconf::cluster_data()->{STARTNODE} . " - $NORMIPADM." . cluster_serverconf::cluster_data()->{FINISHNODE} . "
|---------------------------------------------------------
| TFTPSERVER            | " . cluster_serverconf::tftp_server_data()->{TFTPSERVER} . "
|---------------------------------------------------------

";
}

sub check_tftp_server {

  if (!cluster_serverconf::tftp_server_data()->{TFTPSERVER}) {
	print "\n";
	print "TFTPSERVER is null !\n";
	print "Edit /etc/cluster_serverconf.pm and add an IP\n";
	exit 1;
      }
}


sub set_dhcpd_cnf {
  my $dhcpd_conf=cluster_serverconf::dhcpd_data()->{DHCPDCONF};

  cp_af("$dhcpd_conf.cluster", $dhcpd_conf);

  print " - Setting dhcpd.conf\n";
  print " - tftpserver\n";
  substInFile {
    my $TFTPSERVER = cluster_serverconf::tftp_server_data()->{TFTPSERVER};
    s/next-server.*/next-server $TFTPSERVER;/;
  } $dhcpd_conf;

  my $conf = cat_($dhcpd_conf) . "#EndOfFile";

  my ($conf_beg, $admin_bloc, $conf_mid, $compute_bloc, $conf_end) = $conf =~ /(.*?# TAG: MY_ADMIN_BEGIN)(.*?)(# TAG: MY_ADMIN_END.*?# TAG: MY_COMPUTE_BEGIN)(.*?)(# TAG: MY_COMPUTE_END.*?)\n#EndOfFile/s or die "unable to find MY_ADMIN and MY_COMPUTE sections in $dhcpd_conf";
# Set the MY_ADMIN section

  my $ip = cluster_serverconf::system_network()->{IPSERVER};
  my $NORMIP = dns_cluster::get_spe_ip('ipnorm', $ip);
  my $DOMAINNAME = cluster_serverconf::dns_data()->{DOMAINNAME};
  my $IPSERVER = cluster_serverconf::system_network()->{IPSERVER};
  my $STARTNODE = cluster_serverconf::cluster_data()->{STARTNODE};
  my $FINISHNODE = cluster_serverconf::cluster_data()->{FINISHNODE};

  print " - admin bloc :\n";
  print "    - subnet\n" if $admin_bloc =~ s/^\s+subnet .*/subnet $NORMIP.0 netmask 255.255.255.0 {/gm;
  print "    - option routers\n" if $admin_bloc =~ s/^\s+option routers.*/  option routers $ip;/gm;
  print "    - option domain-name\n" if $admin_bloc =~ s/^\s+option domain-name .*/  option domain-name "$DOMAINNAME";/gm;
  print "    - option domain-name-servers\n" if $admin_bloc =~ s/^\s+option domain-name-servers.*/  option domain-name-servers $IPSERVER;/gm;
  print "    - range\n" if $admin_bloc =~ s/^\s+range.*/  range $NORMIP.$STARTNODE $NORMIP.$FINISHNODE;/gm;

  # Write modifications in /etc/dhcpd.conf
  output($dhcpd_conf, join("\n", $conf_beg, $admin_bloc, $conf_mid, $compute_bloc, $conf_end));
}

sub restart_service {
  # start dhcp service
  service_do('dhcpd', 'stop');
  output('/var/lib/dhcp/dhcpd.leases', '');
  service_do('dhcpd', 'start');
  print "\n";
}

sub do_all {
  printinfo();
  check_tftp_server();
  save_config(cluster_serverconf::dhcpd_data()->{DHCPDCONF});
  set_dhcpd_cnf();
  restart_service();
}

sub help {
    print "
 HELP:
 |---------------------------------------------------------|
 | info            display info of configuration           |
 | check_tftp      check tftp server                       |
 | save_config     backup dhcpd configuration file         |
 | set_conf        set dhcpd conf                          |
 | restart         restart dhcpd                           |
 | doall           do all above                            |
 |---------------------------------------------------------|

";
}

sub main {
    my %opts = (
		'' => \&help,
		info => \&printinfo,
		check_tftp => \&check_tftp_server,
		save_config => sub { save_config(cluster_serverconf::dhcpd_data()->{DHCPDCONF}) },
		set_conf => \&set_dhcpd_cnf,
		restart => \&restart_service,
		doall => \&do_all,
		);

    if (my $f = $opts{$ARGV[0]}) {
	$f->();
    } else { 
	print " ** Dont know what todo ** \n";
    }
}

1;
