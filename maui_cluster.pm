package maui_cluster;

# version 0.2
# GPL like
# aginies at_ mandrakesoft.com
# dviard at_ mandrakesoft.com
# please report bug to: cooker at- mandrakesoft.com

use strict;
use MDK::Common;
use cluster_serverconf;
use cluster_commonconf;
use cluster_fonction_common;

our @ISA = qw(Exporter);
our @EXPORT = qw(maui_config users_in_partition partitions_list add_user_in_partition remove_user_from_partition maui_node change_partition_of_node add_node_in_partition remove_node_from_partition del_user_from_maui main_maui maui_help);

# maui
sub maui_node() {
  save_config(cluster_serverconf::maui_data()->{MAUICFG});
  print " - Resetting maui node configuration\n";
  substInFile {
      s/NODECFG\[.*//s;
  } cluster_serverconf::maui_data()->{MAUICFG};
  append_to_file(cluster_serverconf::maui_data()->{MAUICFG},
		 (map { s/'(\S*)':\d:(\w):(\S*):\d:\d/NODECFG[$1] PARTITION=$3/g; my $a = $1; if ($2 =~ /A/ && !any { /^NODECFG[$a]/ } cat_(cluster_serverconf::maui_data()->{MAUICFG})) { $_ } } cat_(cluster_serverconf::cluster_data()->{NODESFILE})));
}

sub maui_config() {
  cp_af(cluster_serverconf::maui_data()->{MAUICFG}  . '.sample', cluster_serverconf::maui_data()->{MAUICFG});
  my $sh = cluster_commonconf::mysystem()->{SHORTHOSTNAME};
  my $dc = cluster_serverconf::dns_data()->{DOMAINCOMP};
  my $H = cluster_commonconf::mysystem()->{HOSTNAME};
  print " - Configuration of Maui with $H as Ressource Manager\n";
  substInFile { s/SERVERHOST.*/SERVERHOST $H/;
		s/RMSERVER\[0\].*/RMSERVER[0] $sh.$dc/;
		s/RMNAME\[0\].*/RMNAME[0] $sh.$dc/;
	      } cluster_serverconf::maui_data()->{MAUICFG};
}

sub del_user_from_maui {
  my ($user) = @_;

  my $maui_conf = cluster_serverconf::maui_data()->{MAUICFG};
  my $was_there;
  substInFile { $was_there = 1 if s/USERCFG\[$user\]\s+PLIST=.*\n// } $maui_conf;
  $was_there;
}

sub del_grp_from_maui {
  my ($grp) = @_;
  my $maui_conf = cluster_serverconf::maui_data()->{MAUICFG};
  my $was_there;
  substInFile { $was_there = 1 if s/GROUPCFG\[$grp\]\s+PLIST=.*\n// } $maui_conf;
  $was_there;
}

sub users_in_partition {
    my ($part) = @_;
    my $maui_conf = cluster_serverconf::maui_data()->{MAUICFG};
    my @users = cat_($maui_conf) =~ /USERCFG\[(\S+)\]\s+PLIST=[\S+:]*$part[:\S+]*\n/g;
    [ uniq(@users) ];
}

sub grp_in_partition {
    my ($part) = @_;
    my $maui_conf = cluster_serverconf::maui_data()->{MAUICFG};
    my @grps = cat_($maui_conf) =~ /GROUPCFG\[(\S+)\]\s+PLIST=[\S+:]*$part[:\S+]*\n/g;
    [ uniq(@grps) ];
}

sub get_maui_users() {
  my $maui_conf = cluster_serverconf::maui_data()->{MAUICFG};
  my @users = cat_($maui_conf) =~ /USERCFG\[(\S+)\]\s+PLIST=\S*\n/g;
  [ uniq(@users) ];
}

sub partitions_of_user {
  my ($user) = @_;
  my $maui_conf = cluster_serverconf::maui_data()->{MAUICFG};
  #    my @parts = cat_($maui_conf) =~ /USERCFG\[$user\]\s+PLIST=(\S+)[:(\S+)]*\n/g;
  my @parts = cat_($maui_conf) =~ /USERCFG\[$user\]\s+PLIST=([\S+:]*)\n/g ? split(':', $1) : ();
  [ uniq(@parts) ];
}

sub partitions_list() {
    my $maui_conf = cluster_serverconf::maui_data()->{MAUICFG};

    my @partitions = cat_($maui_conf) =~ /\[\S+\]\s+PARTITION=(\S+)/g;
    [ uniq(@partitions) ];
}

my %comments = (
  USERCFG => [ '^# Standing Reservations - PBS queue configuration' => '^$' ],
  NODECFG => [ '^# node partition' => '^$' ],
  SRCFG => [ '^# SRRESOURCES' => '^$' ],
);

sub get_maui_conf {
    my ($field, $key) = @_;
    cat_(cluster_serverconf::maui_data()->{MAUICFG}) =~ /$field\[\Q$key\E\]\s+(.*)/ && $1;
}

sub set_maui_conf {
    my $has_val = @_ > 2;
    my ($field, $key, $val) = @_;
    my $line = $has_val && $field . "[$key] $val";
    my $field_boundaries = $comments{$field} or die "can't use $field, missing boundaries\n";
    substInFile {
	$_ = '' if /$field\[\Q$key\E\]/;
	my $v = /$field_boundaries->[0]/ .. /$field_boundaries->[1]/;
	if ($has_val && ($v =~ /E0/ || eof)) {
	    $_ = "$line\n$_";
	    $has_val = '';
	}
    } cluster_serverconf::maui_data()->{MAUICFG};
    $line;
}

sub add_partition {
  my ($partition) = @_;

  my $partitions = partitions_list();
  die "Partition $partition already exist!" if member($partition, @$partitions);

#  my $cmd = set_maui_conf(SRCFG => $partition, "PARTITION=$partition");
#  sys(qq(su - maui -c "changeparam $cmd"));
}

sub remove_partition {
  my ($partition) = @_;

  my $partitions = partitions_list();
  die "Partition $partition do not exist!" if !member($partition, @$partitions);

  my $maui_conf = cluster_serverconf::maui_data()->{MAUICFG};
#  my $cmd = "SRCFG[$partition] PARTITION=$partition";
  substInFile { s/SRCFG\[$partition\] PARTITION=$partition\n// } $maui_conf;
#  sys(qq(su - maui -c "changeparam $cmd"));
# remove user in partition
  foreach (@{maui_cluster::users_in_partition($partition)}) {
      remove_user_from_partition($_, $partition);
  }
}

sub get_maui_usercfg_plist {
    my ($user) = @_;
    get_maui_conf(USERCFG => $user) =~ /PLIST=(.+)/ ? split(':', $1) : ();
}

sub set_maui_usercfg_plist {
    my ($user, @plists) = @_;
    set_maui_conf(USERCFG => $user, "PLIST=" . join(':', @plists));
}

sub add_user_in_partition {
    my ($user, $part) = @_;
#    my $param = 
    set_maui_usercfg_plist($user, get_maui_usercfg_plist($user), $part);
    print " - Dynamic Change for user $user in $part\n";
#    sys(qq(su - maui -c "changeparam $param"));
    service_do('maui', 'restart');
}

sub remove_user_from_partition {
    my ($user, $part) = @_;
#    my $param = 
    set_maui_usercfg_plist($user, grep { $_ ne $part } get_maui_usercfg_plist($user));
#    sys(qq(su - maui -c "changeparam $param")) if $param;
    service_do('maui', 'restart');
}

sub get_maui_grp_plist {
  my ($grp) = @_;
  get_maui_conf(GROUPCFG => $grp) =~ /PLIST=(.+)/ ? split(':', $1) : ();
}

sub set_maui_grp_plist {
    my ($grp, @plists) = @_;
    set_maui_conf(GROUPCFG => $grp, "PLIST=" . join(':', @plists));
}

sub add_grp_in_partition {
    my ($grp, $part) = @_;
    my $param = set_maui_grp_plist($grp, get_maui_grp_plist($grp), $part);
    print " - Dynamic Change for group $grp in $part\n";
    sys(qq(su - maui -c "changeparam $param"));
}

sub remove_grp_from_partition {
    my ($grp, $part) = @_;
    my $param = set_maui_grp_plist($grp, grep { $_ ne $part } get_maui_grp_plist($grp));
    sys(qq(su - maui -c "changeparam $param")) if $param;
}


sub add_node_in_partition {
  my ($node, $part) = @_;

  my $maui_conf = cluster_serverconf::maui_data()->{MAUICFG};
  my $conf = cat_($maui_conf) . "#EndOfFile";
  if (my ($conf_beg, $node_bloc, $conf_end) = $conf =~ /(.*?# node partition\s*)(.*?\n)#EndOfFile/g) {
    $node_bloc .= "NODECFG[$node] PARTITION=$part\n";
    output($maui_conf, $conf_beg, $node_bloc, $conf_end);
    1;
  }
  #service_do('maui', 'restart');
}

sub remove_node_from_partition {
  my ($node) = @_;
  set_maui_conf(NODECFG => $node);
}

sub change_partition_of_node {
  my ($node, $new_part) = @_;
  my $nodea = cluster_serverconf::cluster_data()->{NODESFILE};
  foreach (cat_($nodea)) {
      my ($n, $S) = /(\S+):\d:(\w):/;
      if ($n =~ /$node/ && $S =~ /A/) {
	#	  my $cmd = 
	set_maui_conf(NODECFG => $node, "PARTITION=$new_part");
	print " move $node in $new_part partition\n";
	#service_do('maui', 'restart');
	#  sys(qq(su - maui -c "changeparam $cmd"));
      }
  }
}

sub maui_help() {
   print "
 HELP:
 |-----------------------------------------------------------|
 | mauinode           add node from /etc/node_list           |
 | showpart           show all partition                     |
 | config             reset maui configuration (be carefull) |
 | doall              do all above                           |
 |-----------------------------------------------------------|

";
}

sub main_maui() {
    my %opts = (
		'' => \&maui_help,
		mauinode => \&maui_node,
		showpart => \&partitions_list,
		config => \&maui_config,
		doall => sub { maui_config(); maui_node(); partitions_list(), service_do('maui', 'restart') },
		);

    if (my $f = $opts{$ARGV[0]}) {
        $f->();
    } else { 
	print " ** Dont know what todo ** \n";
    }
}

1;
