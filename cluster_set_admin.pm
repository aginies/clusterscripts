package cluster_set_admin;
# version 0.6
# GPL like
# aginies -a- mandriva.com

use strict;
use MDK::Common;
use cluster_serverconf;
use cluster_commonconf;
use user_common_cluster;
use nis_cluster;
use cluster_fonction_common;

our @ISA = qw(Exporter);
our @EXPORT = qw(basic_clusterit gexec_modif rshp_var urpmipp_default urpmipp_add_group urpmipp_remove_group urpmipp_ar_change urpmipp_chg_node_group set_admin test_nodesfileadmin help_admin main_admin clusterit_file drak_ar_admin nka_from_urpmig node_ad_admin regenerate_rhosts);


sub print_info() {
  system('clear');
  print "
 Setting up Cluster Admin server with this configuration

 |-----------------------------------------------------------
 | Hostname               | " . cluster_commonconf::mysystem()->{HOSTNAME} . "
 |-----------------------------------------------------------
 | IP of DNS server       | " . cluster_serverconf::system_network()->{IPSERVER} . "
 |-----------------------------------------------------------
 | Domain Admin:          | " . cluster_commonconf::mysystem()->{DOMAINNAME} . "
 |-----------------------------------------------------------
 | urpmi parallel:        | " . cluster_serverconf::urpmi_data()->{URPMICFG} . "
 |-----------------------------------------------------------
 | Urpmi Group:           | " . cluster_serverconf::urpmi_data()->{URPMIGROUP} . "
 |-----------------------------------------------------------

";
}


sub nka_from_urpmig {
    # get list of node from urpmi group for NKA
    # if no urpmigroup provided, using all nodes
    my ($urpmigroup) = @_;
    if (any { /^\b$urpmigroup\b:/ } cat_(cluster_serverconf::urpmi_data()->{URPMICFG})) {
	my @list; push @list , "-c ssh ";
	foreach (cat_(cluster_serverconf::cluster_data()->{NODESFILE})) {
	    if (my ($a) = /([^: \t\n]*):\d:\w:A:\b$urpmigroup\b/) {
		push @list, "-m $a ";
	    }
	}
	foreach (@list) { print $_ };
	@list;
    } elsif ($urpmigroup =~ //) {
	my $all = "-c ssh " . value_set("-m");
	print $all;
    } else {
	print " - no urpmi group name $urpmigroup exist\n please provide a good one";
  }
}

sub test_nodesfile() {
    if (!-f cluster_serverconf::cluster_data()->{NODESFILE}) {
	die ' - There is no ' . cluster_serverconf::cluster_data()->{NODESFILE} . ", exiting !\n";
    }
}


sub basic_clusterit() {
  clusterit_file();
  my ($CONF) = cluster_serverconf::remote_cmd_data();
  print " - Setting basic conf for Clusterit\n";
  if (any { /CLUSTER/ } cat_(cluster_commonconf::mysystem()->{PROFILE})) {
    substInFile {
      s/export (CLUSTER|RCMD_CMD|RCP_CMD).*/export $1=$CONF->{$1}/;
    } cluster_commonconf::mysystem()->{PROFILE}
  } else {
    append_to_file(cluster_commonconf::mysystem()->{PROFILE}, map { "export $_=$CONF->{$_}\n" } qw(CLUSTER RCMD_CMD RCP_CMD));
  }
  create_profile_csh;
}

sub regenerate_rhosts {
  print " - Now adjusting .rhosts for all users\n";
  my @users = @{nis_cluster::get_nis_users()};
  foreach (@users) { user_common_cluster::create_rhost($_) }
}

sub clusterit_file() {
  print " - Creating Clusterit list node file\n";
  output('/etc/clusterit', join("\n", map { s/([^: \t\n]*):\d:\w:(\w):\S*/$1/; $2 =~ /A/ ? chomp_($_) : () } cat_(cluster_serverconf::cluster_data()->{NODESFILE})));
}

sub value_set {
  my ($par) = @_;
  join(' ', map { s/([^: \t\n]*):\d:\w:(\w):\S*/$par $1/; $2 =~ /A/ ? chomp_($_) : () } cat_(cluster_serverconf::cluster_data()->{NODESFILE}));
}

sub gsh_config() {
    print " - Creating Gsh configuration file\n";
    output('/etc/ghosts', "# Macros\n# Name  Group Hardware OS\n");
    append_to_file('/etc/ghosts', join("\n", map { s/([^: \t\n]*):\d:\w:(\w):(\S*)/$1 $3 intel iggi/; $2 =~ /A/ ? chomp_($_) : () } cat_(cluster_serverconf::cluster_data()->{NODESFILE})));
}


# gexec
sub gexec_modif() {
  print " - Reseting basic conf for GEXEC\n";
  my $a = ' ' . value_set('');
  if (any { /export GEXEC_SVRS/ } cat_(cluster_commonconf::mysystem()->{PROFILE})) {
    substInFile { s/export GEXEC_SVRS.*/export GEXEC_SVRS="$a"/ } cluster_commonconf::mysystem()->{PROFILE};
  } else {
    append_to_file(cluster_commonconf::mysystem()->{PROFILE}, "export GEXEC_SVRS=\"$a\"\n");
  }
  create_profile_csh;
}

# rshp et mput
sub rshp_var() {
  print " - Reseting rshp and mput\n";
  my $a = value_set('-m');
  if (any { /export NKA/ } cat_(cluster_commonconf::mysystem()->{PROFILE})) {
    substInFile { s/export NKA.*/export NKA="-c ssh $a"/ } cluster_commonconf::mysystem()->{PROFILE};
  } else {
    append_to_file(cluster_commonconf::mysystem()->{PROFILE}, "export NKA=\"-c ssh $a\"\n");
  }
  create_profile_csh;
}

sub tentakel_conf() {
    print " - Configuring tentakel\n";
    my $a = join(' ', map { s/([^: \t\n]*):\d:\w:(\w):\S*/\+$1/; $2 =~ /A/ ? chomp_($_) : () } cat_(cluster_serverconf::cluster_data()->{NODESFILE}));
    if (any { /group default/ } cat_(cluster_serverconf::remote_cmd_data()->{TENTAKEL})) {
      substInFile {
	s/group default.*/group default (method="ssh", user="root") $a/;
      } cluster_serverconf::remote_cmd_data()->{TENTAKEL};
    } else {
      output(cluster_serverconf::remote_cmd_data()->{TENTAKEL}, "group default (method=\"ssh\", user=\"root\") $a");
    }
}

 

sub dssh_config() {
    print " - Configuring dssh\n";
    my $a = value_set('-w');
    if (any { /export DSSH/ } cat_(cluster_commonconf::mysystem()->{PROFILE})) {
	substInFile { s/export DSSH.*/export DSSH="$a"/ } cluster_commonconf::mysystem()->{PROFILE};
    } else {
	append_to_file(cluster_commonconf::mysystem()->{PROFILE}, "export DSSH=\"$a -e\"\n");
    }
  create_profile_csh;
}

sub pssh_config() {
    print " - Configuring pssh\n";
    if (any { /export PSSH_HOSTS/ } cat_(cluster_commonconf::mysystem()->{PROFILE})) {
	print "    ENV ok\n";
    } else {
	append_to_file(cluster_commonconf::mysystem()->{PROFILE}, "export PSSH_HOSTS=\"/etc/pssh_hosts\"
export PSSH_USER=\"root\"
export PSSH_PAR=\"32\"
export PSSH_OUTDIR=\"/tmp\"
export PSSH_VERBOSE=\"0\"
export PSSH_OPTIONS=
");
    }
    output('/etc/pssh_hosts', join("\n", map { s/([^: \t\n]*):\d:\w:(\w):\S*/$1/; $2 =~ /A/ ? chomp_($_) : () } cat_(cluster_serverconf::cluster_data()->{NODESFILE})));
    create_profile_csh;
}

sub wulfstat_conf() {
  print " - Configure wulfstat\n";
  my $nodea = cluster_serverconf::cluster_data()->{NODESFILE};
  my $SERVER = cluster_commonconf::mysystem()->{HOSTNAME};
  my $wulfconf = cluster_serverconf::wulfstat_data()->{WULFCONF};
  output($wulfconf, <<EOF);
<?xml version="1.0"?>
<wulfstat>
	<host>
		<name>$SERVER</name>
	</host>
EOF

  foreach (cat_($nodea)) {
        my ($n, $S, $urpmig) = /([^: \t\n]*):\d:\w:(\w):(\S+):/;
        if ($S =~ /A/) {
	  append_to_file($wulfconf ,<<EOF);
<host>
   <name>$n</name>
</host>
EOF
       }
      }
  append_to_file($wulfconf , "\<\/wulfstat\>\n");
}

sub urpmipp_default() {
    my $urpmicfg = cluster_serverconf::urpmi_data()->{URPMICFG};
    my $nodea = cluster_serverconf::cluster_data()->{NODESFILE};
    foreach (cat_($nodea)) {
	my ($n, $S, $urpmig) = /([^: \t\n]*):\d:\w:(\w):(\S+):/;
	if ($S =~ /A/) {
	    print " - add $n from $urpmig urpmi group\n";
	    if (! any { /^$urpmig:ka-run/ } cat_($urpmicfg)) {
	      append_to_file($urpmicfg, "$urpmig:ka-run:-c ssh\n");
	    }
	    substInFile {
	      s/\s-m $n//s;
	      s/($urpmig.*)/$1 -m $n/;
	    } $urpmicfg;
	  } else {
	    print " - remove $n from $urpmig urpmi group\n";
	    substInFile {
	      s/-m $n//s;
	    } $urpmicfg;
	  }
      }
}

sub urpmipp_add_group {
  my ($urpmigroup) = @_;
  if (any { /^\b$urpmigroup\b:/ } cat_(cluster_serverconf::urpmi_data()->{URPMICFG})) {
    print " - Seems $urpmigroup group is already in urpmi parallel configuration file\n";
  } else {
    append_to_file(cluster_serverconf::urpmi_data()->{URPMICFG}, "$urpmigroup:ka-run:-c ssh\n");
  }
}

sub urpmipp_ar_change {
  my ($node) = @_;
  my $urpmicfg = cluster_serverconf::urpmi_data()->{URPMICFG};
  my $nodea = cluster_serverconf::cluster_data()->{NODESFILE};
  foreach (cat_($nodea)) {
      my ($n, $S, $urpmig) = /([^: \t\n]*):\d:\w:(\w):(\S+):/;
      if ($n =~ /$node/) {
	  if ($S =~ /A/) {
	      print " - add $node from $urpmig urpmi group\n";
	      substInFile {
		  s/-m $node//s;
		  s/($urpmig.*)/$1 -m $node/;
	      } $urpmicfg;
	  } else {
	      print " - remove $node from $urpmig urpmi group\n";
	      substInFile {
		  s/-m $node//s;
	      } $urpmicfg;
	  }
      }
  }
}

sub urpmipp_remove_group {
  my ($urpmigroup) = @_;
  if (!any { /^\b$urpmigroup\b:/ } cat_(cluster_serverconf::urpmi_data()->{URPMICFG})) {
    print " - Seems there is no $urpmigroup group in urpmi parallel configuration file\n";
  } elsif (any { /^\b$urpmigroup\b:ka-run:-c ssh\S+-m/ } cat_(cluster_serverconf::urpmi_data()->{URPMICFG})) {
    print " - urpmi group already in use (can't remove it)\n";
  } else {
    substInFile { s/^\b$urpmigroup\b:.*//sx } cluster_serverconf::urpmi_data()->{URPMICFG};
  }
}

sub node_ad_admin {
  my ($node, $status) = @_;
  my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
  if ($status == "D") {
    substInFile { s/($node.$domainname:\d:\w:)\w(:\S+:\n)/$1D$2/g; } cluster_serverconf::cluster_data()->{NODESFILE};
  } else {
    substInFile { s/($node.$domainname:\d:\w:)\w(:\S+:\n)/$1A$2/g; } cluster_serverconf::cluster_data()->{NODESFILE};
  }
  drak_ar_admin();
  urpmipp_ar_change($node);
}


sub urpmipp_chg_node_group {
    my ($node, $new_grp) = @_;
    my $domainname = cluster_serverconf::dns_data()->{DOMAINNAME};
    my $nodea = cluster_serverconf::cluster_data()->{NODESFILE};
    if ($new_grp != // && any { /\b$new_grp\b:/ } cat_(cluster_serverconf::urpmi_data()->{URPMICFG})) {
	substInFile {
	    s/($node\.$domainname:\d:\w:\w:)\S+:\n/$1$new_grp:\n/g;
	} $nodea;
	urpmipp_ar_change("$node.$domainname");
#	substInFile {
#	    s/(\S+:\S+:.*?)\s+-m\s+$node\.$domainname(.*?)\n/$1$2\n/g;
#	    s/(\b$new_grp\b:\S+:.*?)\n/$1 -m $node.$domainname\n/g;
#	} cluster_serverconf::urpmi_data()->{URPMICFG};
    } else {
	print " - $new_grp doesnt exist !\n";
    }
}

sub node_status() {
    # print active node
    my $o = cluster_serverconf::cluster_data()->{NODESFILE};
    foreach (cat_($o)) {
	my ($n, $s) = /([^: \t\n]*):\d:\w:(\w):\S/;
	if ($s =~ /A/) {
	    print "$n is ACTIVE\n";
	}
    }
}

sub set_admin() {
  print_info();
  test_nodesfile();
  basic_clusterit();
  gsh_config();
  gexec_modif();
  tentakel_conf();
  pssh_config();
  rshp_var();
  wulfstat_conf();
  dssh_config();
  urpmipp_default();
  node_status();
}

sub drak_ar_admin() {
  basic_clusterit();
  wulfstat_conf();
  dssh_config();
  gexec_modif();
  tentakel_conf();
  pssh_config();
  gsh_config();
  rshp_var();
}

sub help_admin() {
    print "
 HELP:
 |---------------------------------------------------------|
 | clusterit       configre clusterit environement (dsh..) |
 | gexec           configure gexec environement            |
 | gsh             configure gsh remote command            |
 | dssh            configure dssh remote command           |
 | tentakel        configure tentakel remote command       |
 | rshp            set rshp environement (ka-tools)        |
 | pssh            pssh env and conf                       |
 | wulf            configure wulfstat                      |
 | urpmi           configure urpmi parallel (reset)        |
 | rhost           regenerate the rhosts file              |
 | node_status     display node status in admin mode       |
 | info            display info of configuration           |
 | doall           do all above                            |
 |---------------------------------------------------------|

";
}

sub main_admin() {
    my %opts = (
		'' => \&help_admin,
		info => \&print_info,
		clusterit => \&basic_clusterit,
		gexec => \&gexec_modif,
		gsh => \&gsh_config,
		tentakel => \&tentakel_conf,
		pssh => \&pssh_config,
		dssh => \&dssh_config,
		rshp => \&rshp_var,
		wulf => \&wulfstat_conf,
		urpmi => \&urpmipp_default,
		rhost => \&regenerate_rhosts,
		node_status => \&node_status,
		doall => \&set_admin,
		);

    if (my $f = $opts{$ARGV[0]}) {
	$f->();
    } else { 
	print " ** Dont know what todo ** \n";
    }
}

1;
