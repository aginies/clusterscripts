

#!/usr/bin/perl 
# v 0.1
# aginies at mandrakesoft.com

use strict;
use cluster_serverconf;
use cluster_commonconf;
use cluster_fonction_common;
use MDK::Common;

our @ISA = qw(Exporter);
our @EXPORT = qw(info_pbs create_queue set_manager set_operator set_user_admin_op configure_pbs
                 main_pbs set_maui_admin_op set_acl_hosts start_queue adjust_xpbs create_slink);


sub info_pbs() {
  print "
 Using those values to setup the PBS:
 |---------------------------------------------------|
 | server name       " . cluster_commonconf::mysystem()->{HOSTNAME} . "
 |---------------------------------------------------|
 | pbs directory     " . cluster_commonconf::pbs_data()->{PBS_HOME} . "
 |---------------------------------------------------|
 | default operator  " . cluster_serverconf::pbs_data()->{USERADMIN} . "
 |---------------------------------------------------|

";
}

sub create_slink() {
  my $pbsh = cluster_commonconf::pbs_data()->{PBS_EXEC};
  map { symlink("$pbsh/bin/$_", "/usr/sbin/$_"); $_ } qw(qmgr qstart qrun qstop qsub pbs_wish qenable);
  map { symlink("$pbsh/sbin/$_", "/usr/sbin/$_"); $_ } qw(pbs_server pbs_sched pbs_mom pbs_iff pbs_rcp);
}

# create default queue on the server
sub create_queue() {
  my $pbsh = cluster_commonconf::pbs_data()->{PBS_HOME};
  my $d = cluster_serverconf::dns_data()->{DOMAINNAME};
  print " - Creating default queue with $pbsh/pbs_config\n";
  cp_af($pbsh . '/pbs_config.sample', $pbsh . '/pbs_config');
  substInFile {
    s/DOMAINNAME/'$d'/;
  } $pbsh . '/pbs_config';
  service_do('pbs_server', 'start');
  system("cat $pbsh/pbs_config | qmgr");
  service_do('pbs_server', 'stop');
}

sub chg_any {
  # user, domain, file
  my ($u, $d, $f) = @_;
  if (!-e $f) { system('touch', $f) }
  if (!any { /$u\@\*.$d/ } cat_($f)) {
    append_to_file($f, "$u\@*.$d\n");
  }
}

# wich user on wich node can administrate the PBS Server
sub set_manager {
  my ($user, $dom) = @_;
  my $pbsh = cluster_commonconf::pbs_data()->{PBS_HOME};
  print " - Setting $user at $dom as PBS admin\n";
  chg_any($user, $dom, $pbsh . '/server_priv/acl_svr/managers');
}

sub set_operator {
  my ($user, $dom) = @_;
  my $pbsh = cluster_commonconf::pbs_data()->{PBS_HOME};
  print " - Setting $user at $dom as PBS operator\n";
  chg_any($user, $dom, "$pbsh/server_priv/acl_svr/operators");
}

sub set_user_admin_op {
  my ($user) = @_;
  print " - Setting $user manager and operator for PBS\n";
  my $pbsh = cluster_commonconf::pbs_data()->{PBS_HOME};
  service_do('pbs_server', 'stop');
  if (!-d $pbsh . '/server_priv/acl_svr/') { mkdir_p("$pbsh/server_priv/acl_svr/") }
  map { chg_any($user, cluster_serverconf::dns_data()->{DOMAINNAME}, $_) } "$pbsh/server_priv/acl_svr/managers", "$pbsh/server_priv/acl_svr/operators";
}

sub set_acl_hosts {
  my ($dom) = @_;
  my $pbsh = cluster_commonconf::pbs_data()->{PBS_HOME};
  my $f = "$pbsh/server_priv/acl_svr/acl_hosts";
  if (!-e $f) { system('touch', $f) }
  if (!any { /\*\.$dom/ } cat_($f)) {
    append_to_file($f, "*.$dom\n");
  }
}

# create queue
sub start_queue() {
  print " - Starting queue\n";
  service_do('pbs_server', 'start');
  map { system("$_ default small medium long verylong") } qw(qstart qenable);
}

sub adjust_xpbs() {
  my $h = cluster_commonconf::mysystem()->{HOSTNAME};
  map { save_config($_) } cluster_commonconf::pbs_data()->{PBS_LIB} . '/xpbs/xpbsrc',  cluster_commonconf::pbs_data()->{PBS_LIB} . '/xpbsmon/xpbsmonrc';
  print " - Adjusting xpbsmon environement\n";
  substInFile {
    s/\*sitesInfo:.*/\*sitesInfo: \{Local;ICON;$h;$h;$h;MOM\;\{\{\( \( totmem - availmem \) \/ totmem \) \* 100\} \{Memory Usage:\} SCALE\} \{\{\( loadave \/ ncpus \) \* 100\} \{Cpu Usage:\} SCALE\} \{nusers \{Number of Users:\} TEXT\}\}/;
  }  cluster_commonconf::pbs_data()->{PBS_LIB} . '/xpbsmon/xpbsmonrc';
  print " - Adjusting xpbs environement\n";
  substInFile {
    s/^\*serverHosts:.*/*serverHosts: $h/;
      s/^\*selectHosts:.*/*selectHosts: $h/;
      s/^\*timeoutSecs:.*/*timeoutSecs: 10/;
      s/^\*selectQueues:.*/*selectQueues: default\@$h/;
    }  cluster_commonconf::pbs_data()->{PBS_LIB} . '/xpbs/xpbsrc';
}

# adjust pbs config
sub configure_pbs() {
  if (test_pbs_version() =~ /1/) {
    pbspro_common_config();
    # add needed PBS group
    my $ph = cluster_commonconf::pbs_data()->{PBS_HOME};
    map { crea_dir_chmod("$ph/server_priv/$_", '0750'); $_ } qw(acl_groups acl_hosts acl_svr acl_users jobs resvs queues);
    crea_dir_chmod("$ph/sched_priv", '0750');
    map { crea_dir_chmod("$ph/$_", '0755'); $_ } qw(server_logs server_priv/accounting sched_logs);
    output('/etc/pbs.conf', <<EOF);
#!/bin/sh
# init of some var needed by pbs service
# config: /etc/pbs.conf
PBS_HOME=/var/spool/PBS
PBS_EXEC=/usr/pbs
# set 1 to start the service
start_server=1
start_sched=1
start_mom=1
EOF

    my $pexec = cluster_commonconf::pbs_data()->{PBS_EXEC};
    if (!-f "$ph/server_priv/license_file") {
      print "
*** To get a license, please visit
www.pbspro.com/license.html
*** or call PBS Pro at 650-967-4675 or
*** US toll free at 877-905-4PBS
*** and have the following information handy:
***
$pexec/bin/pbs_hostid
***site id from the PBSPro package
***number of cpus you purchased
***
*** Once this is done, type:
***
*** $pexec/etc/pbs_setlicense
***
";
    }
    my $pi = cluster_commonconf::pbs_data()->{PBS_EXEC} . '/etc';
    map { cp_af("$pi/pbs_$_", "$ph/sched_priv/$_") if !-e "$ph/sched_priv/$_"; $_ } qw(holidays sched_config resource_group);
    cp_af("$pi/pbs_dedicated", "$ph/sched_priv/dedicated_time");
    # adjusting right to PBS group
    # system("chown -R .pbs $ph");
  } else {
    set_pbs_var();
  }
}

# main
sub help_pbs() {
print "
 HELP:
 |--------------------------------------------------|
 | info      display inf oon configuration          |
 | maui      configure maui as manager and operator |
 | root      configure root as manager and operator |
 | queue     create queue on server                 |
 | startq    start default queue                    |
 | xpbs      adjust files xpbsrc xpbsmon            |
 | serverpbs set server_name for pbs server         |
 | doall     do all above                           |
 |--------------------------------------------------|

";
}


sub main_pbs() {
    my %opts = (
                '' => \&help_pbs,
		serverpbs => sub { set_pbs_servername(cluster_commonconf::mysystem()->{SHORTHOSTNAME}, cluster_serverconf::dns_data()->{DOMAINNAME}) },
		maui => sub { set_user_admin_op('maui') },
		root => sub { set_user_admin_op(cluster_serverconf::pbs_data()->{USERADMIN}) },
		info => \&info_pbs,
		queue => \&create_queue,
		startq => \&start_queue,
		xpbs => \&adjust_xpbs,
		doall => sub { create_slink(); info_pbs(); configure_pbs(), set_pbs_servername(cluster_commonconf::mysystem()->{SHORTHOSTNAME}, cluster_serverconf::dns_data()->{DOMAINNAME});
			       set_user_admin_op(cluster_serverconf::pbs_data()->{USERADMIN}); set_user_admin_op('maui'); set_acl_hosts(cluster_serverconf::dns_data()->{DOMAINNAME}); create_queue(); start_queue(); adjust_xpbs(); service_do('openpbs', 'restart') },
	       );

    if (my $f = $opts{$ARGV[0]}) {
	$f->();
    } else {
        print " ** Dont know what todo ** \n";
    }
}

1;
