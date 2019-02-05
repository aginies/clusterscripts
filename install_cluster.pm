package install_cluster;

# version 0.4
# GPL like
# aginies@mandriva.com


use cluster_serverconf;
use cluster_fonction_common;
use MDK::Common;
use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(add_ftpuser add_nfsexport call_cpcd copy_data copy_cd set_install help_inst main_inst add_install_http);

our $inst = cluster_commonconf::install_data()->{INSTALLDIR};
-d $inst or system("mkdir -p $inst");

sub print_info() {
  print "
 install mode with this configuration
 |-----------------------------------------------------------
 | Short Hostname    | " . cluster_commonconf::mysystem()->{SHORTHOSTNAME} . "
 |-----------------------------------------------------------
 | Install dir       | " . cluster_commonconf::install_data()->{INSTALLDIR} . "
 |-----------------------------------------------------------
 | Cdrom             | " . cluster_serverconf::cluster_data()->{CDROM} . "
 |-----------------------------------------------------------
 | Http install      | " . cluster_serverconf::doc()->{VARHTML} . '/install' . "
 |-----------------------------------------------------------
";
}


# ftp setup
sub add_ftpuser() {
    print " - Add user FTP install, with no password\n";
    system("/usr/sbin/useradd -u 12383 -d $inst -r -s /bin/bash install");
}

sub proftpd_anonymous() {
  print " - Anonymous can store files in /var/ftp";
  substInFile {
    s/DenyAll//;
  } "/etc/proftpd-anonymous.conf";
  service_do('proftpd', 'restart');
}

# nfs setup
sub add_nfsexport() {
  my $inst = cluster_commonconf::install_data()->{INSTALLDIR};
    if (any { /$inst/ } cat_(cluster_serverconf::system_network()->{NFSEXPORTS})) {
        print " - " . cluster_serverconf::system_network()->{NFSEXPORTS} . " ready\n";
    } else {
        print " - Adjusting " . cluster_serverconf::system_network()->{NFSEXPORTS} . "\n";
	append_to_file(cluster_serverconf::system_network()->{NFSEXPORTS}, "$inst 	*(async,rw)\n");
	service_do('nfs-server', 'restart');
	service_do('nfs-common', 'reload');
	symlink($inst, '/install');
    }
}

sub add_install_http() {
  my $varh = cluster_serverconf::doc()->{VARHTML};
  print " - Creating link for acces rpm through HTTP\n";
  symlink($inst, $varh . '/install');
}

sub copy_cd {
  my ($cdnb) = @_;
  my $mcd = "/mnt/cdrom";
  my $msg = "Please insert CDROM $cdnb,
close the cdrom
and press 'y [enter]' when ready
";

  print $msg;
  while (<STDIN> !~ /y/) {
    print $msg;
  }

  print "mount $mcd\n";
  system("mount $mcd");
  sleep(4);

  if (-d "$mcd/Mandrake") {
    print "copy $mcd to $inst\n";
    system("cp -avf $mcd/\* $inst");
    system("umount $mcd");
    system("eject");
  } else {
    print "incorrect cdrom !! please insert CD $cdnb\n";
    copy_cd($cdnb);
  }
}

sub call_cpcd() {
  my $nb = "4";
  system("eject");
  for (my $i = "1"; $i <= $nb; $i++) {
    copy_cd($i);
  }
}

sub copy_data() {
    if (-e '/tmp/nocd') { rm_rf('/tmp/nocd') }
    mkdir_p($inst);
    my $cd = cluster_serverconf::cluster_data()->{CDROM};
    my $V = $inst . "/VERSION";
    if (! -f $V) {
	if (-f $cd . "/VERSION") {
	    print " - Copying CD to " . $inst . "\n";
	    sys("cp -av $cd/* $inst");
	} else {
	    print " ! WARNING !\n";
	    print " Can't copy CDROM from " . $cd . "\n";
	    print " try to do a: eject ; eject -t ";
	    sys('touch /tmp/nocd');
	}
    } else {
	print " - Cluster install dir in version:\n";
	print cat_($V);
	print "  ** Please remove it if you want to upgrade\n";
    }
}

sub set_install() {
#  add_ftpuser();
  proftpd_anonymous();
  copy_data();
#  call_cpcd();
## add urpmi.addmedia rpm base
  print " - Removing old installation media\n";
  system('urpmi.removemedia', '-a');
  print " - Adding media " . $inst . "\n";
  sys('urpmi.addmedia', '--distrib', 'cluster_m', "file://" . $inst);
#############
  add_nfsexport();
  add_install_http();
}

sub help_inst() {
  print "
 HELP
 |---------------------------------------------|
 | info        print info on configuration     |
 | ftpuser     add user install                |
 | nfs         export install directory        |
 | copycd      copy cdrom to install directory |
 | doall       do all above                    |
 |---------------------------------------------|

";
}

sub main_inst() {
  my %opts = (
	      '' => \&help_inst, 
	      ftpuser => \&add_ftpuser,
	      info => \&print_info,
	      nfs => \&add_nfsexport,
	      copycd => \&call_cpcd,
	      doall => \&set_install,
	     );
  if (my $f = $opts{$ARGV[0]}) {
      $f->();
  } else { 
      print " ** Dont know what todo ** \n";
  }
}


1;
