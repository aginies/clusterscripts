package cluster_commonconf;

# GPL like
# aginies@mandriva.com
# version 0.5

use strict;
use MDK::Common;

sub mysystem() {
    {
    	HOSTNAME => chomp_(`hostname`),
	SHORTHOSTNAME => chomp_(`hostname` =~ /([^.]*)/),
       	DOMAINNAME => chomp_(`dnsdomainname`),
	DATE => `date +%d-%m-20%y`,
	ARCH => arch(),
	INITRD => '/etc/rc.d/init.d',
	SBIN_PATH => '/usr/sbin',
	BIN_PATH => '/usr/bin',
	DESC => 'desc',
	PROFILE => '/etc/profile.d/cluster.sh',
	PROFILECSH => '/etc/profile.d/cluster.csh',
	};
}

sub system_network() {
    {
	NETWORKFILE => '/etc/sysconfig/network',
	};
}

sub pbs_data() {
   if (cluster_fonction_common::test_pbs_version() =~ /1/) {
     {
	 PBS_HOME => '/var/spool/PBS',
	 PBS_LIB => '/usr/pbs/lib',
	 PBS_EXEC => '/usr/pbs',
     }
  } else {
      {
	  PBS_HOME => '/var/spool/pbs',
	  PBS_LIB => '/usr/lib',
	  PBS_EXEC => '/usr',
      }
  }
}

sub nis_data() {
    {
	YPCONF => '/etc/yp.conf',
    };
}

sub smartmontools_data() {
  {
    SMARTCONF => '/etc/smartd.conf',
  };
}

sub install_data() {
  my $install_dir = '/var/install/cluster';
    {
	INSTALLDIR => $install_dir,
	WWWINSTALLDIR => '/install/',
	MEDIA => 'cdrom',
	NB_MEDIA => '1',
	USER_INSTALL_LOGIN => 'install',
	USER_INSTALL_GROUP => 'install',
	USER_INSTALL_PASSWD => '',
	LOCK => "$install_dir/setup_hdlists.lock",
	BASE_DIR => "$install_dir/media/media_info",
	LOG_FILE => '/var/tmp/setup_hdlists.log',
	XTERM => 'TRUE',
	AUTO_INST_FILENAME => 'auto_inst.cfg.pl',
	};
}

sub xinetd_data() {
    {
	XINETDDIR => '/etc/xinetd.d',
	RLOGIN => 'rlogin',
	REXEC => 'rexec',
	PCPD => 'pcpd',
	RSH => 'rsh',
	DISTCC => 'distcc',
	GEXEC => 'gexecd',
	TFTP => 'tftp',
	};
}

sub key_auth_ssh() {
    my $user_ssh_dir = "/root/.ssh";
    my $key_ssh = 'id_dsa';
    {
	KEY_SSH => $key_ssh,
	KEY_AUTH => 'auth_pub.pem',
	USER_SSH_DIR => $user_ssh_dir,
	SSH_KEY_DIR => $user_ssh_dir . '/' . $key_ssh,
	KEY_SSH_PUB => 'id_dsa.pub',
	};
}

sub ka_data() {
  my $rescue = 'rescue';
    {
	RESCUE => $rescue,
	RESCUECLP => "$rescue.sqfs",
	KA_MNT => '/mnt/ka',
	KA_TEMP => '/tmp/ka',
	WORK_DIR => '/var/lib/',
	};
}

sub oar_data() {
 {
	 OAR_DIR => "/var/lib/oar",
	 OAR_KEY_SSH_PUB => "id_dsa.pub.oar",
	 OAR_CONF => "/etc/oar.conf",
 }
}

# mpich need
sub mpich_data() {
  my $mpich_dir = '/usr/share/mpich';
  my $mpi_computer = 'machines.LINUX';
    {
	MPICH_DIR => $mpich_dir,
	MPI_COMPUTER => $mpi_computer,
	MPI_NODES_FILE => $mpich_dir . '/' . $mpi_computer,
	MPDHOSTS => "/etc/mpd.hosts",
	MPDCONF => "/etc/mpd.conf",
	};
}

# lam need
sub lam_data() {
  my $lam_dir = '/etc/lam';
  my $lam_node = 'lam-bhost.def';
    {
	LAM_DIR => $lam_dir,
	LAM_NODE => $lam_node,
	LAM_NODES_FILE => "$lam_dir/$lam_node",
	};
}

# X configuration
sub xconfig() {
    {
	PAMDXSERVER => '/etc/pam.d/xserver',
	XDMCFG => '/etc/X11/xdm',
	};
}

sub tftp_data() {
    {
	WDIR => '/tmp/tftptmp',
	LOCALTIME => 'localtime',
	CLUSTERNODE_CONFIG => 'clusternode.conf',
    };
}

sub fs() {
  {
    CODACACHE => '20000',
    CCSSYS => '/etc/sysconfig/cluster',
    CCSCONF => '/etc/cluster/cluster.conf',
    CCSNAME => 'clusterv',
  },
}

1;
