package cluster_serverconf;

# GPL like
# aginies@mandriva.com
# version 0.8

use strict;
use cluster_commonconf;
use cluster_fonction_common;
use MDK::Common;


# var relative to network on server
sub system_network() {
    my $conf_file = '/etc/clusterserver.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    my $ip_server = interface_to_ip($conf{ADMIN_INTERFACE});
    my $ip_ext = interface_to_ip($conf{EXTERNAL_INTERFACE});
    {
	IPSERVER => $ip_server,
	IPEXT => $ip_ext,
	ADMIN_INTERFACE => $conf{ADMIN_INTERFACE},
	EXTERNAL_INTERFACE => $conf{EXTERNAL_INTERFACE},
	NTPSERVER => $conf{NTPSERVER},
	NFSEXPORTS => '/etc/exports',
	};
}

sub shorewall_data() {
  my $WDIR = '/etc/shorewall';
  {
    INTER => $WDIR . '/interfaces',
    RULES => $WDIR . '/rules',
    POLICY => $WDIR . '/policy',
    MASQ => $WDIR . '/masq',
    ZONES => $WDIR . '/zones',
  }
}

# specific to dhcp server
sub dhcpd_data() {
    {
	WDIR => '/tmp/dhcp',
	DHCPDCONF => '/etc/dhcpd.conf',
	};
}

# specific to cluster
sub cluster_data() {
    my $conf_file = '/etc/clusterserver.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    {
	CLUSTERNODE_CONFIG => '/etc/clusternode.conf',
	WDIR => '/tmp/server',
	NODENAME => $conf{NODENAME},
	STARTNODE => $conf{STARTNODE},
	FINISHNODE => $conf{FINISHNODE},
	NODESFILE => '/etc/nodes_list',
	REP_SAVE => '/home/backup',
        CDROM => $conf{CDROM},
	PARTV => 'partition1',
	HOMEDIR => '/home/nis',
	GROUP => '/etc/group',
	};
}

###
# set VAR for DNS
sub dns_data() {
    my $conf_file = '/etc/clusterserver.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    {
	DOMAINNAME => $conf{DOMAINNAME},
	WDIR => '/tmp/dnssetup',
	IPOFFORWARDER => $conf{IPOFFORWARDER},
	TEXTINFO => 'IGGI_dns_server',
	NAMED_DIR => '/var/lib/named/',
	ZONE_DIR => '/var/lib/named/var/named/zone',
	DNSKEY => $conf{DNSKEY},
	SERIAL => '111',
	ADDSEARCH => $conf{ADDSEARCH},
    };
}
# end set dns VAR

# set VAR for nis
sub nis_data() {
    my $conf_file = '/etc/clusterserver.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    {
	NISSERVER => cluster_commonconf::mysystem()->{HOSTNAME},
	NIS_DIRMAKEFILE => '/var/yp',
	NISDOMAIN => $conf{NISDOMAINNAME},
	NFSSERVER => cluster_commonconf::mysystem()->{HOSTNAME},
	AUTOHOME => '/etc/auto.home',
	AUTOMASTER => '/etc/auto.master',
    };
}

sub ldap_data() {
    my $conf_file = '/etc/clusterserver.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    {
	LDAPSERVER => $conf{LDAPSERVER},
	LDAPDOMAIN => $conf{LDAPDOMAIN},
	NFSSERVER => cluster_commonconf::mysystem()->{HOSTNAME},
	LDAPCONF => '/etc/openldap/sldap.conf',
	LDAPBASE => '/usr/share/doc/clusterscripts-server/ldap_base.ldif',
	LDAPCONFBASE => '/usr/share/doc/clusterscripts-server/sldap_cluster.conf',
    };

}

# tftp on server
sub tftp_server_data() {
    my $conf_file = '/etc/clusterserver.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    {
	TFTPSERVER => system_network()->{IPSERVER},
	TFTPDIR => '/var/lib/tftpboot',
	ETHDHCP_CLIENT => $conf{ETHDHCP_CLIENT},
    };
}

# config for Ganglia monitor
sub ganglia_data() {
    {
	CLUSTER_NAME => 'Mercury',
	GMETADCONF => '/etc/gmetad.conf',
	GMONDCONF => '/etc/gmond.conf',
	};
}

sub wulfstat_data() {
  {
    WULFCONF => '/etc/wulfhosts',
  };
}

# data for OpenPBS server
sub pbs_data() {
    my $conf_file = '/etc/clusterserver.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    {
	WDIR => '/tmp/pbs',
	VERSION => '5.3.3',
	USERADMIN => $conf{USERADMIN},
      };
}

# maui data
sub maui_data() {
  my $maui_home = '/var/spool/maui';
    {
	MAUI_HOME => $maui_home,
	MAUICFG => "$maui_home/maui.cfg",
	};
}

# to set the postfix server
sub postfix_data() {
    my $conf_file = '/etc/clusterserver.conf';
    my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
    {
	CFG => '/etc/postfix/main.cf',
	ORIGIN => $conf{ORIGIN},
    };
}

###
# set VAR for PXE
sub pxe_data() {
  my $ia64_path = 'IA64PC';
  my $full64 = tftp_server_data()->{TFTPDIR} . '/' . $ia64_path . '/linux';
  my $img_path64 = "$full64/images";
  my $temp_dir = '/tmp';
  my $conf_file = '/etc/clusterserver.conf';
  my %conf = getVarsFromSh($conf_file) or die "cannot open file: $!";
#  my $tftpdir = "/var/lib/tftpboot/X86PC/linux/images";

    {
	IA64PATH => $ia64_path,
	FULLCOM => tftp_server_data()->{TFTPDIR} . '/X86PC/linux',
	FULL64 => $full64,
	REPODIR => $conf{REPODIR},
	IMGPATH64 => $img_path64,
	NET64 => "$img_path64/net",
	KA64 => "$img_path64/ka",
	TEMPDIR => $temp_dir,
	PXEDEFAULT => 'pxelinux.cfg/default',
	PXEDEFAULT64 => 'linux.1',
	PXEMENU => "$temp_dir/default.cluster.pxe",
	PXEMESSAGE => "$temp_dir/message.cluster.pxe",
	FREEDOSIMAGE => cluster_commonconf::install_data()->{INSTALLDIR} . '/install/images/freedos.img',
#	KAIMAGE => cluster_commonconf::install_data()->{INSTALLDIR} . '/install/images/ka.img',
	ALLRDZ => cluster_commonconf::install_data()->{INSTALLDIR} . '/isolinux/alt0/all.rdz',
	ALLRDZ1 => cluster_commonconf::install_data()->{INSTALLDIR} . '/isolinux/alt1/all.rdz',
	VMLINUZ => cluster_commonconf::install_data()->{INSTALLDIR} . '/isolinux/alt0/vmlinuz',
	VMLINUZ1 => cluster_commonconf::install_data()->{INSTALLDIR} . '/isolinux/alt1/vmlinuz',
	MEMTEST => cluster_commonconf::install_data()->{INSTALLDIR} . '/isolinux/test/memtest.bin',
	SYSLINUXPATH => '/usr/lib/syslinux/',
	PXEHELP => "$temp_dir/help.txt.pxe",
	ELILO => '/boot/efi/elilo.efi',
	CONF => '/etc/pxe.conf',
	AUTO_INST => cluster_commonconf::install_data()->{INSTALLDIR} . '/install/stage2/' . cluster_commonconf::install_data()->{AUTO_INST_FILENAME},
    };
}

sub urpmi_data() {
    {
	URPMIGROUP => 'cluster',
	URPMICFG => '/etc/urpmi/parallel.cfg',
	URPMIREMOTECMD => 'rshp',
    };
}

sub doc() {
    {
	VARHTML => '/var/www/html',
	};
}

sub fs() {
  my $codasrv = `hostname`;
# CODA size: 22M, 44M, 90M, 130M, 200M, 315M, 500M, 1G
  {
    CODASRV => $codasrv,
    CODASIZE => '90M',
  },
}

sub remote_cmd_data() {
    {
	CLUSTER => '/etc/clusterit',
	RCMD_CMD => '/usr/bin/ssh',
	RCP_CMD => '/usr/bin/scp',
	TENTAKEL => '/etc/tentakel.conf',
    };
}


1;
