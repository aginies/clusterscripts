package cluster_xconfig;

# version 0.1
# GPL like
# aginies at- mandrakesoft.com

use strict;
use MDK::Common;
use cluster_commonconf;
use cluster_fonction_common;

our @ISA = qw(Exporter);
our @EXPORT = qw(icewm_toolbar idesk_config create_xinitrc wm_adjust help_x_config set_xconfig main_xconfig);

sub info_xconfig() {
  print "
 configuration file:
 |------------------------------------------------------
 | files in /etc/X11 are updated to fit cluster config
 |------------------------------------------------------

";
}


sub icewm_toolbar() {
  print " - Configuration of idesk\n";
  mkdir_p("/root/.icewm/");
  my $icons = "/usr/share/pixmaps/cluster";
  output("/root/.icewm/toolbar", <<EOF);
#prog "AutoCluster" "$icons/IC20-MDKC.png" xterm -ls -reverse -e setup_auto_cluster c
#separator
prog "Drakcluster" "$icons/IC20-drakcluster.png" /usr/bin/drakcluster.pl
separator
prog "Userdrake" "$icons/IC20-user.png" /usr/bin/userdrake
separator
prog "Terminal" "$icons/IC20-pconsole.png" xterm -ls -reverse
prog "Emacs" "emacs.png" emacs
prog "Mozilla" "$icons/IC20-ganglia.png" mozilla http://localhost/
EOF
}

sub create_xinitrc() {
  print " - prepare xinitrc of root user\n";
  my $XIRC = "/root/.xinitrc";
  if (! -f $XIRC) {
    output($XIRC, <<EOF);
qiv -z /usr/share/mdk/backgrounds/default.png
idesk &
exec icewm
EOF
  }
}

sub wm_adjust() {
  print " - Avoid red background login as root\n";
  substInFile { s/xsetroot -solid "#B20003"// } "/etc/X11/Xsession";
  my $ICE = "/etc/X11/wmsession.d/07IceWM";
  if (-f $ICE) {
    print	" - Icewm first Window Manager\n";
    system("mv -f $ICE /etc/X11/wmsession.d/01IceWM");
  }
}

sub fix_mdkX_bckg() {
    my $PBCK = "/usr/share/mdk/backgrounds";
    cp_af("/etc/X11/CLUSTER-1024.jpg", "$PBCK/Mandrake.png");
    cp_af("/etc/X11/CLUSTER-1024.jpg", "$PBCK/default.png");
    cp_af("/etc/X11/CLUSTER-1024.jpg", "$PBCK/Mandrake-1280x1024.png");
}


sub idesk_config() {
  print " - Configuring and installing idesk on icewm\n";
  output('/root/.ideskrc', <<EOF);
table Config
 FontName: tahoma
 FontSize: 10
 FontColor: #ffffff
 Locked: true
 Transparency: 30
 Shadow: false
 ShadowColor: #000000
 ShadowX: 10
 ShadowY: 2
 Bold: false
 ClickDelay: 300
 IconSnap: true
 SnapWidth: 55
 SnapHeight: 100
 SnapOrigin: BottomRight
 SnapShadow: true
 SnapShadowTrans: 200
 CaptionOnHover: false
end

table Actions
 Lock: control right doubleClk
 Reload: middle doubleClk
 Drag: left hold
 EndDrag: left singleClk
 Execute[0]: left doubleClk
 Execute[1]: right doubleClk
end
EOF

  mkdir_p('/root/.idesktop');
  output('/root/.idesktop/nis.lnk', <<EOF);
table Icon
 Caption: Userdrake
 Command: /usr/bin/userdrake
 Icon: /usr/share/pixmaps/cluster/IC48-MDKCuser.png
 X: 500
 Y: 24
 end
EOF

  output('/root/.idesktop/docmdkc.lnk', <<EOF);
table Icon
 Caption: Cluster Documentation
 Command: /usr/bin/mozilla /usr/share/doc/mandrake/en/index.html
 Icon: /usr/share/pixmaps/cluster/IC48-docmdkc.png
 X: 30
 Y: 183
end
EOF

  output('/root/.idesktop/drak.lnk', <<EOF);
table Icon
 Caption: Drakcluster
 Command: /usr/bin/drakcluster.pl
 Icon: /usr/share/pixmaps/cluster/IC48-drakcluster-gris.png
 X: 740
 Y: 23
end
EOF

  output('/root/.idesktop/ganglia.lnk', <<EOF);
table Icon
 Caption: Ganglia
 Command: /usr/bin/mozilla http://localhost/ganglia-webfrontend/
 Icon: /usr/share/pixmaps/cluster/IC48-ganglia.png
 X: 420
 Y: 24
end
EOF

  output('/root/.idesktop/xpbs.lnk', <<EOF);
table Icon
 Caption: Xpbs
 Command: /usr/bin/xpbs
 Icon: /usr/share/pixmaps/cluster/IC48-xpbs.png
 X: 660
 Y: 24
end

EOF

  output('/root/.idesktop/xpbsmon.lnk', <<EOF);
table Icon
 Caption: Xpbsmon
 Command: /usr/bin/xpbsmon
 Icon: /usr/share/pixmaps/cluster/IC48-pbsmon.png
 X: 580
 Y: 24
end
EOF

  my $GIVEC="/etc/X11/xdm/GiveConsole";
  if (!any { /idesk/ } cat_($GIVEC)) {
    append_to_file($GIVEC, "/usr/bin/idesk&\n");
  }
}

sub add_xinitd() {
    my $BCK="/etc/X11/xinit.d/bck";
    if (! -f $BCK) {
	print "add a default background"; 
	output($BCK, <<EOF);
#!/bin/sh
qiv -z /etc/X11/CLUSTER-1024.jpg
EOF

    system("chmod 755 $BCK");
    }
}

sub set_xconfig() {
    info_xconfig();
    if (!any { /CLIC/ } cat_('/etc/mandrake-release')) {
	icewm_toolbar();
	idesk_config();
    }
    adjust_icewm_theme();
    fix_mdkX_bckg(); #No more necessary since mandrake-theme-Mandrakeclustering
    create_xinitrc();
    wm_adjust();
    add_bg_xdm();
    add_xinitd();
}


sub help_x_config() {
    print "
 HELP:
 |------------------------------------------------------|
 | idesk         configure idesk                        |
 | wm_adjust     adjust config of default WindowManager |
 | add_xinitd    add background script                  |
 | bg_xdm        modify xdm background                  |
 | xinitrc       create a default xinitrc               |
 | icewmtool     configure toolbar for icewm            |
 | doall         do all above                           |
 |------------------------------------------------------|

";
}

sub main_xconfig() {
  my %opts = (
	      '' => \&help_x_config,
	      bg_xdm => \&add_bg_xdm,
	      add_xinitd => \&add_xinitd,
	      wm_adjust => \&wm_adjust,
	      icewmtool => \&icewm_toolbar,
              idesk => \&idesk_config,
	      xinitrc => \&create_xinitrc,
	      doall => \&set_xconfig,
	     );

    if (my $f = $opts{$ARGV[0]}) {
        $f->();
    } else {
	print " ** Dont know what todo ** \n";
    }
}


1;
