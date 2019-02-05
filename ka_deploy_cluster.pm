package ka_deploy_cluster;

# Author : Daniel Viard <dviard@mandrakesoft.com>
# Version 0.1
# please report bug to: cooker@mandriva.com [IGGI] subject

use strict;
use Term::ANSIColor;
use MDK::Common;
use cluster_clientconf;
use cluster_commonconf;
use cluster_fonction_common;

# test root capa
AmIRoot();

###################################################################################
# retrieve rescue stage from SERVER
###################################################################################
sub retrieve_rescue {
  print '- Downloading rescue stage from server (' . cluster_clientconf::catch_dhcp()->{NEXT_SERVER} . ")\n";
  my $WORK_DIR = cluster_commonconf::ka_data()->{WORK_DIR};
  my $tftpserver = cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP};
  my $rescue2 = cluster_commonconf::ka_data()->{RESCUECLP};
  open(FTP_CMD, "| cd $WORK_DIR ; tftp $tftpserver");
  print FTP_CMD "get $rescue2\n";
  print FTP_CMD "quit\n";
  close FTP_CMD;
  print "\n";
}


###################################################################################
# Rescue
###################################################################################
sub clp_to_iso {
  print "- convert clp to iso file\n";
  sys('extract_compressed_fs' . ' ' . cluster_commonconf::ka_data()->{WORK_DIR} . '/' . cluster_commonconf::ka_data()->{RESCUECLP} . ' > ' . cluster_commonconf::ka_data()->{WORK_DIR} . '/' . cluster_commonconf::ka_data()->{RESCUE} . ".iso");
}



###################################################################################
# mount ka
###################################################################################
sub mount_ka {
  print "- Mounting rescue stage in loopback\n";
  sys('mkdir -p ' . cluster_commonconf::ka_data()->{KA_TEMP});
  sys('mount ' . cluster_commonconf::ka_data()->{WORK_DIR} . '/' . cluster_commonconf::ka_data()->{RESCUE} . ".iso" . ' ' . cluster_commonconf::ka_data()->{KA_TEMP} . ' -o loop');
}

sub copy_ka {
  sys('mkdir -p ' . cluster_commonconf::ka_data()->{KA_MNT});
	sys('cp -a ' . cluster_commonconf::ka_data()->{KA_TEMP} . '/* ' . cluster_commonconf::ka_data()->{KA_MNT} . '/'); 
}

sub horrible_fix_CS4 {
  my $bug_install = cluster_commonconf::ka_data()->{KA_MNT} . "/ka/install.sh";
  if (any { /\sgen_modprobe_conf/ } cat_($bug_install)) {
    substInFile {
      s/\sgen_modprobe_conf/gen_modprobe_conf/;
    } $bug_install;
  }
}

sub make_partition_bootable {
  my $install = cluster_commonconf::ka_data()->{KA_MNT} . "/ka/install.sh";
  substInFile {
    s/^umount_partitions\s/umount_partitions\nruncom \"Set \$drive with a bootable flag\" \/ka\/bootable_flag.sh \$drive \|\| fail \n/g;
  } $install;
}

sub create_script_bootable {
  output(cluster_commonconf::ka_data()->{KA_MNT} . "/ka/bootable_flag.sh", <<EOF);
#!/bin/sh
# first arg is the drive device
# detect if there is a bootable partition
TEST=`fdisk -l /dev/\$1 | grep /dev/$1 | grep "*"`
if [ -z "\$TEST" ];then
fdisk /dev/\$1 <<REF
a
1
w
REF
fi
EOF

  chmod(0755, cluster_commonconf::ka_data()->{KA_MNT} . "/ka/bootable_flag.sh");
  my $install = cluster_commonconf::ka_data()->{KA_MNT} . "/ka/install.sh";
  substInFile {
      s/trap int_shell SIGINT/trap int_shell SIGINT\n\/ka\/store_log.sh/;
      s/echo -n Rebooting.*/echo -n Rebooting\.\.\.\n\/ka\/store_log.sh/;
  } $install;
  
}

sub create_script_log {
    my $tftpserver = cluster_clientconf::catch_dhcp()->{NEXT_SERVERIP};
    output(cluster_commonconf::ka_data()->{KA_MNT} . "/ka/store_log.sh", <<EOF);
#!/bin/sh

echo 'default login anonymous password user' > ~/.netrc
ftp -i $tftpserver <<REF
cd incoming
lcd /tmp
mput ka*
quit
REF
EOF

chmod(0755, cluster_commonconf::ka_data()->{KA_MNT} . "/ka/store_log.sh");  
}

sub patch_log_ka {
    my $DATE =	cluster_commonconf::mysystem()->{DATE};
    substInFile {
	    s/\.\/install.sh/DATE=\`date +\%Y\%m\%d\%H\%M\`\n\.\/install.sh \> \/tmp\/ka_log-\$HOSTNAME-\$DATE 2\>\&1 \&\ntail -f \/tmp\/ka_log-\$HOSTNAME-\$DATE/;
    } cluster_commonconf::ka_data()->{KA_MNT} . "/etc/rc.sysinit";
}

###################################################################################
# umount ka
###################################################################################
sub umount_ka {
  print "- Umounting ka\n";
  eval { sys('umount ' . cluster_commonconf::ka_data()->{KA_TEMP} . ' 2>/dev/null') };
}

sub clean_ka_dir {
  print "- Rm ka dir\n";
  eval { sys ('rm -rf ' . cluster_commonconf::ka_data()->{KA_MNT}) }
}

###################################################################################
# Checking path
###################################################################################
sub check_path {
  print "- Checking path\n";
  if (! -e cluster_commonconf::ka_data()->{KA_MNT}) {
    mkdir_p(cluster_commonconf::ka_data()->{KA_MNT});
  }
}

###################################################################################
# Remove old version of rescue
###################################################################################
sub remove_old {
  print "- Removing old version\n";
  if (-e cluster_commonconf::ka_data()->{WORK_DIR} . cluster_commonconf::ka_data()->{RESCUE}) {
    rm_rf(cluster_commonconf::ka_data()->{WORK_DIR} . cluster_commonconf::ka_data()->{RESCUE});
  } else {
    print cluster_commonconf::ka_data()->{WORK_DIR} . cluster_commonconf::ka_data()->{RESCUE} . " does not exist.\n";
  }
}

###################################################################################
# MAIN program
###################################################################################
sub main {
  check_path();
  umount_ka();
  clean_ka_dir();
  remove_old();
  retrieve_rescue();
  clp_to_iso();
  mount_ka();
  copy_ka();
  horrible_fix_CS4();
  make_partition_bootable();
  create_script_bootable();
  create_script_log();
  patch_log_ka();
  umount_ka();
  print " !!! KA is now ready to deploy !!!\n";
}

1;
