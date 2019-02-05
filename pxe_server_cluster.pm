package pxe_server_cluster;

# Author : Daniel Viard <dviard@mandrakesoft.com>
# aginies
# Version 0.1
# please report bug to: cooker@mandrakesoft.com

use strict;
use Term::ANSIColor;
use MDK::Common;
use cluster_serverconf;
use cluster_commonconf;
use cluster_fonction_common;

our @ISA = qw(Exporter);
our @EXPORT = qw(display_change get_display);

my $repo_dir = cluster_serverconf::pxe_data->{REPODIR};
die ("$repo_dir not present, exiting...") if !(-e $repo_dir);

sub garbage {
    print " - Garbage collector in action\n";
    unlink qw(cluster_serverconf::pxe_data()->{PXEMESSAGE} cluster_serverconf::pxe_data()->{PXEMENU} cluster_serverconf::pxe_data()->{NETIMAGE} cluster_serverconf::pxe_data()->{NETIMAGE_NOFB} cluster_serverconf::pxe_data()->{PXEHELP});
}


sub prepare_pxeconf64 {
  print " - Preparing PXE network cards\n";
  my $pxe_conf = cluster_serverconf::pxe_data()->{CONF};
  save_config($pxe_conf);
  cp_af(cluster_serverconf::pxe_data()->{ELILO}, cluster_serverconf::pxe_data()->{FULL64});
  cp_af(cluster_serverconf::pxe_data()->{PXEMENU}, cluster_serverconf::pxe_data()->{FULL64} . '/linux.1');

  print "	- Setting $pxe_conf file\n";
  substInFile {
    my $interface = cluster_serverconf::dns_data->{INTERFACEDNS};
    my $ip_server = cluster_serverconf::system_network->{IPSERVER};
    my $domain = cluster_commonconf::mysystem->{DOMAINNAME};

    print "	- Interface\n" if s/interface=.*/interface=$interface/;
    print "	- address\n" if s/default_address.*/default_address=$ip_server/;
    print "	- MTFTP address\n" if s/mtftp_address.*/mtftp_address=$ip_server/;
    print "	- Name\n" if s/Mandrake/Cluster/;
    print "	- Domain\n" if s/domain.*/domain=$domain/;
  } $pxe_conf;

  print "	- Restart PXE service\n";
  sys('service pxe restart');
}

sub prepare_pxeconf {
  print " - Preparing PXE for cards\n";
  my $pxe_conf = cluster_serverconf::pxe_data()->{CONF};
  save_config($pxe_conf);

#  cp_af(cluster_serverconf::pxe_data()->{SYSLINUXPATH} . '/memdisk', cluster_serverconf::pxe_data()->{FULLCOM});
#  cp_af(cluster_serverconf::pxe_data()->{SYSLINUXPATH} . '/pxelinux.0', cluster_serverconf::pxe_data()->{FULLCOM});
#  cp_af(cluster_serverconf::pxe_data()->{SYSLINUXPATH} . '/pxelinux-graphic.0', cluster_serverconf::pxe_data()->{FULLCOM});
  cp_af(cluster_serverconf::pxe_data()->{PXEMESSAGE}, cluster_serverconf::pxe_data()->{FULLCOM} . '/messages');
  cp_af(cluster_serverconf::pxe_data()->{PXEHELP}, cluster_serverconf::pxe_data()->{FULLCOM} . '/help.txt');
  mkdir_p(cluster_serverconf::pxe_data()->{FULLCOM} . '/pxelinux.cfg');
  cp_af(cluster_serverconf::pxe_data()->{PXEMENU}, cluster_serverconf::pxe_data()->{FULLCOM} . '/pxelinux.cfg/default');

  print "	- Setting $pxe_conf file\n";
  my $interface = cluster_serverconf::system_network->{ADMIN_INTERFACE};
  my $ip_server = cluster_serverconf::system_network->{IPSERVER};
  my $domain = cluster_commonconf::mysystem->{DOMAINNAME};

  my $info;
  print "$pxe_conf\n";
  substInFile {
    $info .= "	- Interface\n" if s/interface=.*/interface=$interface/;
    $info .= "	- address\n" if s/default_address.*/default_address=$ip_server/;
    $info .= "	- MTFTP address\n" if s/mtftp_address.*/mtftp_address=$ip_server/;
    $info .= "	- Name\n" if s/Mandrake/Cluster/;
    $info .= "	- Domain\n" if s/domain.*/domain=$domain/;
  } $pxe_conf;

  print $info;
  print "	- Restart PXE service\n";
  system('service pxe restart');
}

sub cp_images {
    mkdir_p(cluster_serverconf::pxe_data()->{FULLCOM} . '/images');
    cp_af(cluster_serverconf::pxe_data()->{ALLRDZ}, cluster_serverconf::pxe_data()->{FULLCOM} . '/images/');
    cp_af(cluster_serverconf::pxe_data()->{VMLINUZ}, cluster_serverconf::pxe_data()->{FULLCOM} . '/images/');
    if ( -e cluster_serverconf::pxe_data()->{ALLRDZ1}) {
	    my $kernel_version = basename(glob(dirname(cluster_serverconf::pxe_data()->{ALLRDZ1}) . "/2*"));
	    cp_af(cluster_serverconf::pxe_data()->{ALLRDZ1}, cluster_serverconf::pxe_data()->{FULLCOM} . '/images/all' . $kernel_version . '.rdz');
	    cp_af(cluster_serverconf::pxe_data()->{VMLINUZ1}, cluster_serverconf::pxe_data()->{FULLCOM} . '/images/vmlinuz' . $kernel_version);
    }
#    cp_af(cluster_serverconf::pxe_data()->{KAIMAGE}, cluster_serverconf::pxe_data()->{FULLCOM} . '/images/ka.img');
    if (cluster_commonconf::mysystem->{ARCH} ne "x86_64") {
      if ( -e cluster_serverconf::pxe_data()->{FREEDOSIMAGE}) {
	cp_af(cluster_serverconf::pxe_data()->{FREEDOSIMAGE}, cluster_serverconf::pxe_data()->{FULLCOM} . '/images');
      }
    }
}

#sub add_memtest {
#    print " - add memtest in PXE\n";
#    cp_af(cluster_serverconf::pxe_data()->{KAIMAGE}, cluster_serverconf::pxe_data()->{FULLCOM} . '/images/memtest');
#    append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "test : Test memory\n");
#    append_to_file(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
#label test
#    KERNEL images/memtest
#EOF 
#}


sub prepareKaImage64 {
  print "	- Preparing KA Image\n";
  my $mount = cluster_serverconf::pxe_data()->{TEMPDIR} . '/loopForMDKC';

  cp_af(cluster_serverconf::pxe_data->{REPODIR} . '/images/ka.img', cluster_serverconf::pxe_data()->{NETIMAGE});
  mkdir_p($mount);
  sys('mount ' . cluster_serverconf::pxe_data()->{NETIMAGE} . " $mount -o loop");
  cp_af("$mount/ka.rdz", cluster_serverconf::pxe_data()->{KA64});
  cp_af("$mount/vmlinux", cluster_serverconf::pxe_data()->{KA64});
  sys("umount $mount");
  if (-e $mount) {
    rm_rf($mount);
  }

  my $ETHDHCP_CLIENT = cluster_serverconf::tftp_server_data()->{ETHDHCP_CLIENT};
  append_to_file(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
image=/IA64PC/linux/images/ka/vmlinux
        label=ka
	root=/dev/ram3
	initrd=/IA64PC/linux/images/ka/ka.rdz
	append=" ramdisk_size=120000 automatic=method:ka,interface:$ETHDHCP_CLIENT,network:dhcp root=/dev/ram3 rw rescue"
	read-only
	
EOF

  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "\n------------------------------------------------------------\n");
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "ka64 : Installing a Cluster node64 with ka installation mode");
}

sub prepareKa {
  my ($suffix) = @_;
  my $suffixpxe;
  if ($suffix) { $suffixpxe = "1" }
  print "	- Preparing KA PXE entry $suffix\n";
  my $ETHDHCP_CLIENT = cluster_serverconf::tftp_server_data()->{ETHDHCP_CLIENT};
  append_to_file(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
label kamethod$suffixpxe
MENU LABEL Install a node with ka $suffix
       KERNEL images/vmlinuz
       APPEND initrd=images/all.rdz automatic=method:ka,interface:$ETHDHCP_CLIENT,network:dhcp ramdisk_size=80000 vga=text root=/dev/ram3 rw rescue kamethod
       
EOF
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "\n------------------------------------------------------------\n");
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "kamethod$suffixpxe        : Install a Cluster node with ka clone mode $suffix\n");
}

sub preparedolly {
  my ($suffix) = @_;
  my $suffixpxe;
  if ($suffix) { $suffixpxe = "1" }
  print "	- Preparing Dolly PXE entry $suffix\n";
  my $ETHDHCP_CLIENT = cluster_serverconf::tftp_server_data()->{ETHDHCP_CLIENT};
  append_to_file(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
label dolly$suffixpxe
MENU LABEL Install a node with dolly $suffix
       KERNEL images/vmlinuz$suffix
       APPEND initrd=images/all$suffix.rdz automatic=method:dolly,dolly_timeout:100,interface:$ETHDHCP_CLIENT,network:dhcp ramdisk_size=250000 vga=text root=/dev/ram3 rw rescue dollymethod
       
EOF
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "dolly$suffixpxe     : Install a Cluster node with dolly clone mode $suffix");
}

sub prepare_rescue {
  print " - Preparing rescue mode\n";
  my $ETHDHCP_CLIENT = cluster_serverconf::tftp_server_data()->{ETHDHCP_CLIENT};
  append_to_file(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
label rescue
MENU LABEL Boot in rescue mode
       KERNEL images/vmlinuz
       APPEND initrd=images/all.rdz automatic=method:nfs,interface:$ETHDHCP_CLIENT,network:dhcp ramdisk_size=80000 vga=text root=/dev/ram3 rw rescue
       
EOF
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "\n------------------------------------------------------------\n");
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "rescue    : Boot in rescue mode");
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "\n------------------------------------------------------------\n");
}

sub cp_gnbd() {
  my $dirmodules = "/var/www/html/modules";
  my $kernver = chomp_(`uname -r`);
  if (! -d $dirmodules) { mkdir_p($dirmodules) }
  cp_af("/lib/modules/$kernver/drivers/block/gnbd/gnbd.ko", "$dirmodules/gnbd.ko");
}

sub prepare_gnbdpart {
  print "	- Preparing Gnbd partitions mode\n";
  cp_gnbd();
  my $ETHDHCP_CLIENT = cluster_serverconf::tftp_server_data()->{ETHDHCP_CLIENT};
  append_to_file(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
label gnbdpart
       KERNEL images/vmlinuz
       APPEND initrd=images/all.rdz automatic=method:nfs,interface:$ETHDHCP_CLIENT,network:dhcp ramdisk_size=128000 vga=text root=/dev/ram3 rw rescue gnbdpart
       
EOF
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "\n------------------------------------------------------------\n");
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "gnbdpart  : Gnbd exporting partitions method");
}

sub prepare_gnbddev {
  print "	- Preparing Gnbd devices mode\n";
  cp_gnbd();
  my $ETHDHCP_CLIENT = cluster_serverconf::tftp_server_data()->{ETHDHCP_CLIENT};
  append_to_file(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
label gnbddev
       KERNEL images/vmlinuz
       APPEND initrd=images/all.rdz automatic=method:nfs,interface:$ETHDHCP_CLIENT,network:dhcp ramdisk_size=128000 vga=text root=/dev/ram3 rw rescue gnbddev
       
EOF
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "\n------------------------------------------------------------\n");
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "gnbddev : Gnbd exportinf devices method");
}


sub prepareNetImage64 {
  print "- Preparing Network Boot image\n";

  my $mount = cluster_serverconf::pxe_data()->{TEMPDIR} . '/loopForMdkc';
  cp_af(cluster_serverconf::pxe_data->{REPODIR} . '/images/all.img', cluster_serverconf::pxe_data()->{NETIMAGE});
  mkdir_p($mount);
  sys('mount ' . cluster_serverconf::pxe_data()->{NETIMAGE} . "  $mount -o loop");
  cp_af("$mount/all.rdz", cluster_serverconf::pxe_data()->{NET64});
  cp_af("$mount/vmlinux", cluster_serverconf::pxe_data()->{NET64});
  sys("umount $mount");
  if (-e $mount) {
    rm_rf($mount);
  }

  my $ETHDHCP_CLIENT = cluster_serverconf::tftp_server_data()->{ETHDHCP_CLIENT};
  my $ip_server = cluster_serverconf::system_network()->{IPSERVER};
  my $wwwinstall_dir = cluster_commonconf::install_data()->{WWWINSTALLDIR};
  append_to_file(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
image=/IA64PC/linux/images/net/vmlinux
        label=linux
	root=/dev/ram3
	initrd=/IA64PC/linux/images/net/all.rdz
	append=" ramdisk_size=120000 automatic=method:http,interface:$ETHDHCP_CLIENT,network:dhcp,server:$ip_server,directory:$wwwinstall_dir root=/dev/ram3 rw vga=788"
	read-only

image=/IA64PC/linux/images/net/vmlinux
        label=linux-nofb
	root=/dev/ram3
	initrd=/IA64PC/linux/images/net/all.rdz
	append=" ramdisk_size=120000 automatic=method:http,interface:$ETHDHCP_CLIENT,network:dhcp,server:$ip_server,directory:$wwwinstall_dir root=/dev/ram3 rw"
	read-only

image=/IA64PC/linux/images/net/vmlinux
        label=rescue
	root=/dev/ram3
	initrd=/IA64PC/linux/images/net/all.rdz
	append=" ramdisk_size=120000 automatic=method:http,interface:$ETHDHCP_CLIENT,network:dhcp,server:$ip_server,directory:$wwwinstall_dir root=/dev/ram3 rw rescue"
	read-only
	
EOF
# TAG: net64_END

  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "net64 : Installing a Cluster node64 with net installation mode\n");
}

sub prepareNetImage {
  # retieve all and vmlinuz suffix
  my ($suffix) = @_;
  my $suffixpxe;
  if ($suffix) { $suffixpxe = "1" }
  print " - Preparing Network installation Entry $suffix\n";
  my $ip_server = cluster_serverconf::system_network()->{IPSERVER};
  my $ETHDHCP_CLIENT = cluster_serverconf::tftp_server_data()->{ETHDHCP_CLIENT};
  my $AUTO_INST_FILENAME = cluster_commonconf::install_data()->{AUTO_INST_FILENAME};
  my $acpi;
  if (cluster_commonconf::mysystem->{ARCH} eq "x86_64") {
      $acpi = "acpi=ht";
  } else { $acpi = "" }
# remove display:0 to fix bug on Nocona (internal VGA)
  append_to_file(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
label linuxhttp$suffixpxe
MENU LABEL Install a node via HTTP $suffix
	KERNEL images/vmlinuz$suffix
	APPEND initrd=images/all$suffix.rdz automatic=method:http,interface:$ETHDHCP_CLIENT,network:dhcp,server:$ip_server,directory:/install/ ramdisk_size=120000 root=/dev/ram3 rw vga=788 $acpi

label autohttp$suffixpxe
MENU LABEL Auto Install a node via HTTP $suffix
	KERNEL images/vmlinuz$suffix
	APPEND initrd=images/all$suffix.rdz auto_install=install/stage2/$AUTO_INST_FILENAME automatic=method:http,interface:$ETHDHCP_CLIENT,network:dhcp,server:$ip_server,directory:/install/ ramdisk_size=120000 root=/dev/ram3 rw vga=788 $acpi

label linuxnfs$suffixpxe
MENU LABEL Install a node via NFS $suffix
	KERNEL images/vmlinuz$suffix
	APPEND initrd=images/all$suffix.rdz automatic=method:nfs,interface:$ETHDHCP_CLIENT,network:dhcp,server:$ip_server,directory:/install/ ramdisk_size=120000 root=/dev/ram3 rw vga=788 $acpi

label autonfs$suffixpxe
MENU LABEL Auto Install a node via NFS $suffix
	KERNEL images/vmlinuz$suffix
	APPEND initrd=images/all$suffix.rdz auto_install=install/stage2/$AUTO_INST_FILENAME automatic=method:nfs,interface:$ETHDHCP_CLIENT,network:dhcp,server:$ip_server,directory:/install/ ramdisk_size=120000 root=/dev/ram3 rw vga=788 $acpi

EOF

  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "\n------------------------------------------------------------\n");
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "linuxhttp$suffixpxe : Install a Cluster node via HTTP $suffix\n");
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "autohttp$suffixpxe  : Auto Install a Cluster node via HTTP $suffix\n");
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "linuxnfs$suffixpxe  : Install a Cluster node via NFS $suffix\n");
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "autonfs$suffixpxe   : Auto Install a Cluster node via NFS $suffix");
}

sub get_display() {
  my $ip_server = cluster_serverconf::system_network->{IPSERVER};
  my $PXECONF = cluster_serverconf::pxe_data()->{FULLCOM} . "/" . cluster_serverconf::pxe_data()->{PXEDEFAULT};
  if (any { /display=$ip_server:0/ } cat_($PXECONF)) {
    return 1;
  }
}

sub display_change {
  my ($s) = @_;
  my $ip_server = cluster_serverconf::system_network->{IPSERVER};
  my $PXECONF = cluster_serverconf::pxe_data()->{FULLCOM} . "/" . cluster_serverconf::pxe_data()->{PXEDEFAULT};
  if ($s =~ /A/) {
    substInFile { s/display=.*/display=$ip_server:0/g } $PXECONF;
    # i know this is a really bad way to authorize display...
    system("xhost +");
  } else {
    substInFile { s/display=.*/display=:0/g } $PXECONF;
  }
}

sub prepareFreeDosImage {
  append_to_file(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
label freedos
	KERNEL memdisk
	APPEND initrd=images/freedos.img
	
EOF
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "freedos : FreeDos\n");
}

sub prepareTftpboot {
  print "	- Creating pxe images directories\n";
  if (cluster_commonconf::mysystem->{ARCH} eq "ia64") {
    mkdir_p(cluster_serverconf::pxe_data()->{IMGPATH64});
    mkdir_p(cluster_serverconf::pxe_data()->{NET64});
    mkdir_p(cluster_serverconf::pxe_data()->{KA64});
    sys('chmod a+x ' . cluster_serverconf::pxe_data()->{FULL64});
  } else {
    mkdir_p(cluster_serverconf::pxe_data()->{FULLCOM} . '/images');
    mkdir_p(cluster_serverconf::pxe_data()->{FULLCOM} . '/pxelinux.cfg');
  }
}

sub prepareDefaultPXEMenu {
  print "	- Preparing Default PXE Menu\n";
  output(cluster_serverconf::pxe_data()->{PXEHELP}, "Available images are:\n");
  output(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
PROMPT 0
ALLOWOPTIONS 1
DEFAULT menu311.c32
DISPLAY messages
TIMEOUT 50
MENU TITLE IGGI cluster Boot Menu

label local
	MENU LABEL Local Boot
	LOCALBOOT 0
F1	help.txt

EOF

  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "\n------------------------------------------------------------\n");
  append_to_file(cluster_serverconf::pxe_data()->{PXEHELP}, "local     : Boot local");
}

sub prepareDefaultPXEMenu64 {
  print "	- Preparing Default PXE Menu\n";
  output(cluster_serverconf::pxe_data()->{PXEMENU}, <<EOF);
prompt
timeout=50
default=linuxhttp
EOF

}

sub preparePXEMessage {
  print "	- Preparing PXE Message\n";
  output(cluster_serverconf::pxe_data()->{PXEMESSAGE}, <<EOF);
  ###############################
   Welcome to Cluster PXE Server
  ###############################

Press F1 for available images
EOF

}

sub removeFrameBuffer {
  my ($image) = @_;
  print " 		|- Removing frame buffer in '$image' image\n";
  my $mount = cluster_serverconf::pxe_data()->{TEMPDIR} . '/loopForMdkc';
  mkdir_p($mount);
  sys("mount $image $mount -o loop");
  substInFile {
    s|vga=.*|vga=normal|;
  } "$mount/syslinux.cfg";
  sys("umount $mount");
  if (-e $mount) {
    rm_rf($mount);
  }
}

sub append_image_option {
  my ($image, $opt) = @_;
  print " - Now patching $image with $opt\n";
  my $mount = cluster_serverconf::pxe_data()->{TEMPDIR} . '/loopForMdkc';

  mkdir_p($mount);
  sys("mount $image $mount -o loop");
  substInFile {
    s/vga=(normal|788).*/vga=$1 $opt/;
  } "$mount/syslinux.cfg";
  sys("umount $mount");
  if (-e $mount) {
    rm_rf($mount);
  }

}

sub change_interface {
  my ($eth) = @_;
  my $fcom = cluster_serverconf::pxe_data()->{FULLCOM} . '/images/';
  print " - Now change $eth for dhcp\n";
  
  sub t {
      my ($img, $eth) = @_;
      my $mount = cluster_serverconf::pxe_data()->{TEMPDIR} . '/loopForMdkc';
      map {
	  print "$_\n";
	  mkdir_p($mount);
	  sys("mount $_ $mount -o loop");
	  substInFile {
	      s/interface:(eth0|eth1|eth2)/interface:$eth/;
	  } "$mount/syslinux.cfg";
	  sys("umount $mount");
	  if (-e $mount) {
	      rm_rf($mount);
	  }
      } $img;
  } 
  t("$fcom/ka.img", $eth);
}


sub prepareAutoInst {
  print " - Preparing auto installation file " . cluster_serverconf::pxe_data()->{AUTO_INST} . "\n";
  save_config(cluster_serverconf::pxe_data()->{AUTO_INST}); 
  output(cluster_serverconf::pxe_data()->{AUTO_INST}, <<EOF);
#!/usr/bin/perl -cw
#
# You should check the syntax of this file before using it in an auto-install.
# You can do this with 'perl -cw auto_inst.cfg.pl' or by executing this file
# (note the '#!/usr/bin/perl -cw' on the first line).
\$o = {
       'libsafe' => 0,
       'security_user' => '',
       'default_packages' => [
			       'locales',
			       'locales-en',
			       'msec',
			       'grub',
			       'vim-enhanced',
			       'bootsplash',
			       'man',
			       'eject',
			       'gnupg',
			       'urpmi',
			       'hotplug',
			       'urw-fonts',
			       'lsof',
			       'nfs-utils-clients',
			       'openssh-clients',
			       'bind-utils',
			       'mtools',
			       'tmpwatch',
			       'yp-tools',
			       'ypbind',
			       'OpenIPMI',
			       'acpi',
			       'acpid',
			       'at',
			       'autofs',
			       'coreutils-doc',
			       'devfsd',
			       'dmidecode',
			       'ftp-client-krb5',
			       'hdparm',
			       'hexedit',
			       'ldetect',
			       'lshw',
			       'ntp',
			       'open',
			       'rsync',
			       'rxvt',
			       'strace',
			       'sudo',
			       'xterm',
			       'zip',
			       'mpich',
			       'ka-deploy-source-node',
                               'mandrake_theme',
			       'clusterscripts-client',
			       'oar-node',
			       'oar-user',
			       'dolly',
			       'dolly_plus',
			       'clone',
			       'dhcpd',
			     ],
       'users' => [],
       'locale' => {
		     'country' => 'US',
		     'lang' => 'en_US',
		     'langs' => {
				  'en_US' => 1
				},
		     'utf8' => undef
		   },
       'authentication' => {
			     'shadow' => 1,
			     'local' => '',
			     'md5' => 1
			   },
       'partitions' => [
			 {
			   'mntpoint' => 'swap',
			   'type' => 130,
			   'size' => 2088387
			 },
			 {
			   'mntpoint' => '/',
			   'type' => 1155,
			   'size' => 15840027
			 }
		       ],
       'netcnx' => {
		     'NET_DEVICE' => undef,
		     'type' => 'lan',
		     'lan' => {},
		     'NET_INTERFACE' => undef
		   },
       'mouse' => {
		    'XMOUSETYPE' => 'ExplorerPS/2',
		    'name' => 'Any PS/2 & USB mice',
		    'EMULATEWHEEL' => undef,
		    'device' => 'input/mice',
		    'type' => 'Universal',
   		    'nbuttons' => 7,
		    'MOUSETYPE' => 'ps/2'
		  },
       'autoExitInstall' => '1',
       'keyboard' => {
		       'GRP_TOGGLE' => '',
		       'KBCHARSET' => 'C',
		       'KEYBOARD' => 'us',
		       'unsafe' => 1
		     },
       'manualFstab' => [],
       'X' => {},
       'intf' => {
		   'eth0' => {
			       'isUp' => 1,
			       'BOOTPROTO' => 'dhcp',
			       'DEVICE' => 'eth0',
			       'BROADCAST' => '',
			       'isPtp' => '',
			       'WIRELESS_ENC_KEY' => '',
			       'NETWORK' => '',
			       'ONBOOT' => 'yes',
			       'MII_NOT_SUPPORTED' => 'yes'
			     }
		 },
       'partitioning' => {
			   'auto_allocate' => 'cluster node',
			   'clearall' => 1,
			   'eraseBadPartitions' => 1
			 },
       'postInstall' => "
         /usr/share/bootsplash/scripts/switch-themes clustering
       ",
       'security' => 2,
       'interactiveSteps' => [
       				'selectKeyboard',
				'setRootPassword',
			     ]
     };
EOF
}


sub prepareCommon {
  print " - Preparing common configuration file\n";
  if (cluster_commonconf::mysystem->{ARCH} eq "ia64") {
    prepareDefaultPXEMenu64();
    prepareTftpboot();
    prepareNetImage64();
    prepareKaImage64();
    print "   - IA64 Specific\n";
  } else {
    prepareDefaultPXEMenu();
    preparePXEMessage();
    prepareTftpboot();
    prepareAutoInst();
    prepareNetImage();
    prepareKa();
    preparedolly();
    if ( -e cluster_serverconf::pxe_data()->{ALLRDZ1}) {
	my $kernel_version = basename(glob(dirname(cluster_serverconf::pxe_data()->{ALLRDZ1}) . "/2*"));
	prepareNetImage($kernel_version);
	prepareKa($kernel_version);
	preparedolly($kernel_version);
    }
    prepare_rescue();
#    if (cluster_commonconf::mysystem->{ARCH} ne "x86_64") {
#	prepareFreeDosImage();
#    }
    #prepare_gnbddev();
    #prepare_gnbdpart();
      #removeFrameBuffer(cluster_serverconf::pxe_data()->{KAIMAGE});
  }
}

sub isBuildEnabled {
  if (cluster_commonconf::mysystem->{ARCH} ne 'ia64' ?
      ! -e cluster_serverconf::pxe_data()->{FULLCOM} . "/" . cluster_serverconf::pxe_data()->{PXEDEFAULT} :
      ! -e cluster_serverconf::pxe_data()->{FULL64} . "/" . cluster_serverconf::pxe_data()->{PXEDEFAULT64}) {
    die ' - Please use build mode before';
  }
}

sub get_pxe_labels {
  my $arch = cluster_commonconf::mysystem->{ARCH};
  my ($full, $pxe) = $arch eq 'ia64' ? ('FULL64', 'PXEDEFAULT64') : ('FULLCOM', 'PXEDEFAULT');
  my @pxe_labels = cat_(cluster_serverconf::pxe_data()->{$full} . '/' . cluster_serverconf::pxe_data()->{$pxe}) =~ /label\s+(.+)/g;
  # add pxelinux menu
  push @pxe_labels, "menu311.c32";
  [ @pxe_labels ];
}

sub get_special_labels {
  my @special_labels = qw(apic noapic acpi noacpi all noall);
  [ @special_labels ];
}

sub get_eth {
  my @eth = qw(eth0 eth1 eth2);
  [ @eth ];
}

sub showLabels {
  my ($pxe_labels) = @_;
  print "	- Available labels are : \n";
  print "@$pxe_labels\n\n";
}

sub isLabelExist {
  my ($pxe_labels, $mylabel) = @_;
  if (!member($mylabel, @$pxe_labels)) {
    print "	- Label $mylabel doesn't exist !\n";
    showLabels($pxe_labels);
    exit 1;
  }
}
sub getDefaultLabel {
  my $default;

  if (cluster_commonconf::mysystem->{ARCH} ne "ia64") {
      my $pxe = cluster_serverconf::pxe_data()->{FULLCOM} . '/' . cluster_serverconf::pxe_data()->{PXEDEFAULT};
      ($default) = cat_($pxe) =~ /DEFAULT\s+(\S+)/;
  } else {
      my $pxe = cluster_serverconf::pxe_data()->{FULL64} . '/' . cluster_serverconf::pxe_data()->{PXEDEFAULT64};
      ($default) = cat_($pxe) =~ /default\s+(\S+)/;
  }
  $default;
}

sub setDefaultLabel {
  my ($default_label) = @_;

  if (cluster_commonconf::mysystem->{ARCH} ne "ia64") {
      foreach my $pxe (cluster_serverconf::pxe_data()->{FULLCOM} . '/' . cluster_serverconf::pxe_data()->{PXEDEFAULT}) {
	  print "	- Patching $pxe\n";
	  substInFile {
	      s|DEFAULT.*|DEFAULT $default_label|;
	      s|PROMPT.*|PROMPT 1|;
	  } $pxe;
	  if ($default_label =~ /menu311.c32/) {
	      substInFile {
		  s|PROMPT.*|PROMPT 0|;
	      } $pxe;
	  } else {
	      substInFile {
		  s|PROMPT.*|PROMPT 1|;
	      } $pxe;
	  }
      } 
  } else {
      substInFile {
	  s|default.*|default=$default_label|;
      } cluster_serverconf::pxe_data()->{FULL64} . '/' . cluster_serverconf::pxe_data()->{PXEDEFAULT64};
  }
}

sub setDefaultSpecial {
  my ($defaultspe) = @_;
  system("/usr/bin/setup_pxe_server.pl special $defaultspe");
}

sub rebuild_img {
  system("/usr/bin/setup_pxe_server.pl build");
}


sub main {
  ##########################
  ## MAIN
  #########################

  sub usage {
    print "\nUsage $0 : { build | boot }\n";
    print "	build: Build the pxe default configuration (! reset all conf !)\n";
    print "	boot: Select the default boot Entry\n\n";
    exit;
  }

  usage() if !@ARGV || !$ARGV[0];

  if ($ARGV[0] eq 'build') {
    print " - Entering build mode\n";
    cp_images();
    prepareCommon();
    if (cluster_commonconf::mysystem->{ARCH} ne 'ia64') {
	prepare_pxeconf();
#	cp_images();
    } else {
      prepare_pxeconf64();
    }
    garbage();
  } elsif ($ARGV[0] eq 'boot') {
    print "\n - Entering setup mode\n";
    isBuildEnabled();
    if (!$ARGV[1]) {
      print "	- You must provide the default pxe lablels\n";
      showLabels(get_pxe_labels());
      exit 1;
    }
    isLabelExist(get_pxe_labels(), $ARGV[1]);
    setDefaultLabel($ARGV[1]);
    print "PXE Server is now set to boot on '$ARGV[1]' Entry\n";
  } else {
    usage();
  }

}

1;
