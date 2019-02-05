package cluster_clientconf;
# GPL like
# aginies @ mandriva.com, nvigier @ mandriva.com



use strict;
use cluster_commonconf;
use cluster_fonction_common;
use MDK::Common;

sub node_config() {
    {
	CLUSTERNODE_CONFIG => '/etc/clusternode.conf',
    }
}

sub dhclient_conf() {
    my $conf_file = '/var/lib/dhcp/dhclient-' . system_network()->{INTERFACE} . '.leases';
    my %conf = {};
    return 0 if (! -f $conf_file);
    foreach (cat_($conf_file)) {
	if (m/^\s*fixed-address\s+(.*)\s?;/) {
	    $conf{IPADDR} = $1;
	} elsif (m/^\s*option\s+domain-name\s+\"(.*)\"\s?;/) {
	    $conf{DOMAIN} = $1;
	} elsif (m/^\s*option\s+dhcp-server-identifier\s+(.*)\s?;/) {
	    $conf{DHCPSIADDR} = $1;
	}
    }
    %conf;
}

sub catch_dhcp() {
    my $conf_file = '/etc/dhcpc/dhcpcd-' . system_network()->{INTERFACE} . '.info';
    my %conf = getVarsFromSh($conf_file);
    if (!%conf) {
	    %conf = dhclient_conf();
    }
    if (!%conf) {
	    sleep 5;
	    %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    }

    my $next_server_ip = $conf{DHCPSIADDR};
    my $next_server = resolv_ip($next_server_ip);
    {
	DOMAIN => $conf{DOMAIN},
	NEXT_SERVERIP => $next_server_ip,
	NEXT_SERVER => $next_server,
	IPOFCLIENT => $conf{IPADDR},
	};
}


sub system_network() {
    {
	INTERFACE => 'eth0',
    };
}

sub ib_network() {
    my $conf_file = '/etc/clusternode.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    {
            IB_INTERFACE => $conf{IB_INTERFACE},
            IB_NETWORK => $conf{IB_NETWORK},
    };
}

sub ldap() {
    my $conf_file = '/etc/clusternode.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    {
	LDAPSERVER => $conf{LDAPSERVER},
    }
}

sub nis() {
    my $conf_file = '/etc/clusternode.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    {
	NISSERVER => $conf{NISSERVER},
	NISDOMAIN => $conf{NISDOMAIN},
    }
}

sub ntp() {
    my $conf_file = '/etc/clusternode.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    {
	NTPSERVER => $conf{NTPSERVER},
	NTPSTEPTICKERS => '/etc/ntp/step-tickers',
	NTPCONF => '/etc/ntp.conf',
    };
}


1;
