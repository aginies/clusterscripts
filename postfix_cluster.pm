package postfix_cluster;

# GPL like
# aginies@mandrakesoft.com
# version 0.3

use strict;
use cluster_serverconf;
use cluster_fonction_common;
use MDK::Common;


our @ISA = qw(Exporter);
our @EXPORT = qw(set_config set_postfix help_postfix main_postfix);


# print info of wath todo
sub print_info() {
    system("clear");
    print "
 Setting up POSTFIX server with this configuration

 |-----------------------------------------------------------
 | Postfix server        | " . cluster_commonconf::mysystem()->{HOSTNAME} . "
 |-----------------------------------------------------------
 | Postfix Domain        | " . cluster_commonconf::mysystem()->{DOMAINNAME} . "
 |-----------------------------------------------------------
 | Postfix myorigin      | " . cluster_serverconf::postfix_data()->{ORIGIN} . "
 |-----------------------------------------------------------

";
}
# end printinfo

sub set_config() {
    my $h = cluster_commonconf::mysystem()->{HOSTNAME};
    my $d = cluster_commonconf::mysystem()->{DOMAINNAME};
    my $o = cluster_serverconf::postfix_data()->{ORIGIN};
    print " - Setting configuration " . cluster_serverconf::postfix_data()->{CFG} . " file for Postfix server\n";
    save_config(cluster_serverconf::postfix_data()->{CFG});
    substInFile {
	s/myhostname.*/myhostname = $h/g;
	s/mydomain.*/mydomain = $d/g;
	s/^myorigin.*|^#myorigin.*/myorigin = $o/g;
	s/inet_interfaces.*/inet_interfaces = $h,localhost/g;
    } cluster_serverconf::postfix_data()->{CFG};
}


sub set_postfix() {
  print_info();
  set_config();
  service_do('postfix', 'restart');
}

sub help_postfix() {
    print "
 HELP:
 |------------------------------------|
 | set    set the configuration       |
 | info   print info of configuration |
 |------------------------------------|

";
}

sub main_postfix() {
    my %opts = (
		'' => \&help_postfix,
		set => \&set_postfix,
		info => \&print_info,
		);

    if (my $f = $opts{$ARGV[0]}) {
	$f->();
    } else {
	print " ** Dont know what todo ** \n";
    }
}

1;
