package user_common_cluster;

# Author : Daniel Viard <dviard@mandrakesoft.com>
# Version 0.1
# please report bug to: cooker@mandrakesoft.com

use strict;
use Term::ANSIColor;
use MDK::Common;
use User::grent;
use User::pwent;
use cluster_commonconf;
use cluster_serverconf;
use cluster_fonction_common;
use Getopt::Std;
use maui_cluster;

our @ISA = qw(Exporter);
our @EXPORT = qw(create_rhost);

sub addUserToGroup {
  my ($user, $group)=@_;
  my $etc_group = cluster_serverconf::cluster_data()->{GROUP};
  print "Adding $user in $group group.\n";

  getgrnam($group) or warn "$group group not found!\nExiting\n";

  if (member($user, getgrent()->members)) {
    # If the  user  is  already  in  this group
    print "User $user is already a member of $group group.\n";
  } else {
    #Add the user
    substInFile {
      if (my ($users) = /\Q$group\E:x:\S+:(\S*)/) {
	$_ = chomp_($_) . ($users ? ',' : '') . "$user\n";
      }
    } $etc_group;
  }
}

sub read_user {
  my $user;

  while (!$user) {
    print "Login : \n";
    chomp($user = <STDIN>);
  }
  return $user;
}


sub test_user {
  my ($user) = @_;

  if ($user eq 'root') {

    print "Is it a test ?\n";
    print "Or are you MAD ?\n";
    print "Hmm...dont be crazy to test that.......\n";
    exit 1;

  } else {

    if (!(my $user_uid = getpwnam($user))) {
      print " $user not present in NIS base !\n";
      exit 1;

    } else {
      return $user_uid;
    }
  }
}


sub read_group {
  my $group;

  $group = 'users';
  print "Group(s) [$group] (You are member of mpi, oar, pvm by default) : \n";
  chomp($group = <STDIN>);

  if (!$group) {
    $group = 'users';
  } else {
    if (!getgrnam($group)) {
      sys("groupadd $group");
    }
  }
  return $group;
}

sub addUser {
  my ($user, $group, $comment, $passwd) = @_;

  print "----------------------------------------------------------\n";
  print "Login: $user\n";
  print "Group: $group\n";
  print "Comment: $comment\n";

  if ($passwd) {
    sys('useradd', '-p', $passwd, '-c', $comment, '-g', $group, $user, '-d', cluster_serverconf::cluster_data()->{HOMEDIR} . "/$user")
  } else {
    sys('useradd', '-c', $comment, '-g', $group, $user, '-d', cluster_serverconf::cluster_data()->{HOMEDIR} . "/$user");
  }
}

sub set_passwd {
  my ($user) = @_;

  print "passwd $user:\n";
  while (!sys("passwd $user")) {
    print "passwd $user:\n";
  }
}


sub del_user {
  my ($user) = @_;

  my @nfs_mount = `showmount -a --no-headers`;
  my $home_user = cluster_serverconf::cluster_data()->{HOMEDIR} . "/$user";

  if (!any { /$home_user/i } @nfs_mount) {

    print " - Making Backup of home user\n";
    sys("/usr/bin/sauvegarde $user $home_user");
    if (!getopts("u:")) {
     print " - Deleting user\n";
     sys("/usr/sbin/userdel -r $user");
    }
    rm_rf($home_user);

  } else {

    print "\n";
    print " !!!! WARNING !!!!\n";
    print "\n";
    print " You can't delete the user $user before you delete this user\n";
    print ' Umount ' . cluster_serverconf::cluster_data()->{HOMEDIR} . "/$user from:\n";
    print foreach grep { /$home_user/i } @nfs_mount;
  }
}


sub create_ssh_key {
  my ($user) = @_;

  my $home_user = cluster_serverconf::cluster_data()->{HOMEDIR} . "/$user";

  print " - Creating ssh key for user $user\n";
  sys(qq(su $user -c "mkdir ~/.ssh"));
  sys(qq(su $user -c "chmod 755 ~/.ssh")); 
#  sys(qq(su $user -c "ssh-keygen -t dsa -f ~/.ssh/id_dsa"));
  open(KEYGEN, '|' . qq(su $user -c "ssh-keygen -t dsa -f ~/.ssh/id_dsa"));
  print KEYGEN "\n";
  print KEYGEN "\n";
  close KEYGEN;
  print "\n";

  print " - Authorize user to ssh himself\n";
  sys("cat $home_user/.ssh/id_dsa.pub > $home_user/.ssh/authorized_keys");
  sys("chmod 644 $home_user/.ssh/authorized_keys");
}

sub create_rhost {
  my ($user) = @_;
  my $home_user = cluster_serverconf::cluster_data()->{HOMEDIR} . "/$user";
  if (-d $home_user) {
    print " - Setting .rhosts file for $user\n";
    output("$home_user/.rhosts", cluster_commonconf::mysystem()->{SHORTHOSTNAME} . '.' . cluster_serverconf::dns_data()->{DOMAINNAME} . "\t$user\n");
    # compute
    foreach my $line (cat_(cluster_serverconf::cluster_data()->{NODESFILE})) {
      my ($node) = $line =~ /([^: \t\n]*):\S+:\S+:\S+:\S+:/;
      if (! any { /$node\t$user/ } cat_("$home_user/.rhosts")) {
	append_to_file("$home_user/.rhosts", "$node\t$user\n");
      }
    }
  }
}

sub set_xinitrc {
  my ($user) = @_;
  my $home_user = cluster_serverconf::cluster_data()->{HOMEDIR} . "/$user";
  print " - Setting default .xinitrc for user\n";
  output("$home_user/.xinitrc", <<EOF);
xhost +
/usr/X11R6/bin/xsetbg /usr/share/mdk/backgrounds/default.png
if [ -f /usr/X11R6/bin/icewm ]; then
	exec icewm
else
	exec twm
fi
EOF

}

sub set_muttrc {
  my ($user) = @_;
  my $home_user = cluster_serverconf::cluster_data()->{HOMEDIR} . "/$user";
  print " - Create mutt config\n";
  mkdir_p("$home_user/Mail");
  mkdir_p("$home_user/.mutt");
  cp_af('/etc/muttrc', "$home_user/.muttrc");
}

sub adjust_owner {
  my ($user, $group) = @_;
  my $home_user = cluster_serverconf::cluster_data()->{HOMEDIR} . "/$user";
  print " - Setting permission on file\n";
  system("chown -R $user.$group $home_user/");
}

sub adjust_mod_rhost {
  my ($user) = @_;
  my $home_user = cluster_serverconf::cluster_data()->{HOMEDIR} . "/$user";
  print " - Adjust chmod to 0644 on .rhost key\n";
  system("chmod 0644 $home_user/.rhosts");
}

sub usage_del {
  die "usage: $0 [-h] -l Login
    -h          : this (help) message
    -l Login    : Login of the user to del
    -u 		: Ask $0 to not remove the user itself

    EXAMPLE: $0 -l guibo
    ";
}

sub main_del {

  my %opt;
  getopts("l:u:h", \%opt);

  $opt{h} and usage_del();

  return if member($opt{l}, maui_cluster::get_maui_users());
  print "\n";
  print " - Remove user from NIS Map\n";
  print "\n";
  my $user = defined  $opt{l} ? $opt{l} : read_user();

  if (test_user($user)) {
    del_user($user);
#    print " - Removing user in maui\n";
#    maui_cluster::del_user_from_maui($user);
  }
  # tell drakcluster to update user tab
#  system("killall -USR1 drakcluster.pl 2>/dev/null");
}

sub usage_add {
  die "usage: $0 [-h] -l Login [-p Password] [-g Group] [-c Comment] [-C]
    -h          : this (help) message
    -l Login    : Login of new user
    -p Password : The encrypted password of new user, as returned by crypt
    -g Group    : Group of new user (he is member of mpi, pbs, pvm by default)
    -c Comment  : Comment of new user
    -C          : Do functions nedeed by cluster (rhost, ssh, maui, mutt)
    EXAMPLE: $0 -l guibo -p \$1\$pNpuzDnO\$iZIgCN/LNI41GhqY9son50
    ";
}

sub main_add {

  my %opt;
  getopts("l:p:g:c:Ch", \%opt);

  my $read;

  $opt{l} and $opt{C} or $opt{l} and $opt{p} or $read=1;
  $opt{h} and usage_add();

  print "-----------------------------------------------------------\n";
  print "Add New user in cluster environnement on\n";
  print "user with an uid > 500 are NIS user\n";
  print "-----------------------------------------------------------\n";

  my $user;
  my $group;
  my $comment;
  my $password;

  if ($read) {
    $user = read_user();
    $group = read_group();
    $comment = '';
  } else {
    $user = $opt{l};
    $password = $opt{p};
    $group = defined $opt{g} ? $opt{g} : 'users';
    $comment = defined $opt{c} ? $opt{c} : '';
  }
  die "User $user existe already, please choose another login." if !$opt{C} && getpw($user);


  save_config(cluster_serverconf::cluster_data()->{GROUP}) if !$opt{C};

  addUserToGroup($user, "mpi");
  addUserToGroup($user, "pvm");
  addUserToGroup($user, "oar");

  addUser($user, $group, $comment, $password) if !$opt{C};

  if ($read) {
    set_passwd($user);
  }

  create_ssh_key($user);
  create_rhost($user);
#  set_xinitrc($user);
  set_muttrc($user);

  adjust_owner($user, $group) if !$opt{c};
  adjust_mod_rhost($user);
#  print " - Adding user in maui (partition1) \n";
#  maui_cluster::add_user_in_partition($user, 'partition1');
  # tell drakcluster to update user tab
  if (-f '/usr/bin/drakcluster.pl') {
    system("killall -USR1 drakcluster.pl 2>/dev/null");
  }
}

1;
