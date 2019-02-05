package dns_cluster;

# version 0.91
# GPL like
# aginies@mandriva.com

use strict;
use MDK::Common;
use cluster_serverconf;
use cluster_fonction_common;

our @ISA = qw(Exporter);
our @EXPORT = qw(print_info check_hostname check_domain
		 check_range_ip crea_db_local crea_named_common
                 crea_named_master crea_named_slave help_dns
		 crea_hints crea_iprev crea_ipnorm set_dns main_dns
		 crea_127 crea_rndc save_old_config set_resolv
		 set_hosts check_config copy_good 
                 add_srv_alias_node get_spe_ip crea_trusted_network);


# print info of wath todo
sub print_info() {
  my $ip = cluster_serverconf::system_network()->{IPSERVER};
  print "
 Setting up DNS server with this configuration

 |-----------------------------------------------------------
 | Short Hostname         | " . cluster_commonconf::mysystem()->{SHORTHOSTNAME} . "
 |-----------------------------------------------------------
 | IP of DNS server:      | " . cluster_serverconf::system_network()->{IPSERVER} . "
 |-----------------------------------------------------------
 | IP External:           | " . cluster_serverconf::system_network()->{IPEXT} . "
 |-----------------------------------------------------------
 | Add search:            | " . cluster_serverconf::dns_data()->{ADDSEARCH} . "
 |-----------------------------------------------------------
 | Domainname:            | " . cluster_serverconf::dns_data()->{DOMAINNAME} . "
 |-----------------------------------------------------------
 | Admin nodename:        | " . cluster_serverconf::cluster_data()->{NODENAME} . "
 |-----------------------------------------------------------";

  if (check_empty_ipforwarder() =~ /1/) {
print "
 | Forwarder:             | " . cluster_serverconf::dns_data()->{IPOFFORWARDER} . "
 |-----------------------------------------------------------";
}

print "
 | First node:            | " . cluster_serverconf::cluster_data()->{NODENAME} . cluster_serverconf::cluster_data()->{STARTNODE} . "
 |-----------------------------------------------------------
 | Last node:             | " . cluster_serverconf::cluster_data()->{NODENAME} . cluster_serverconf::cluster_data()->{FINISHNODE} . "
 |-----------------------------------------------------------
 | IP range in DNS:       | " . get_spe_ip('ipnor', $ip) . "." . cluster_serverconf::cluster_data()->{STARTNODE} . " - " . get_spe_ip('ipnor', $ip) . "." . cluster_serverconf::cluster_data()->{FINISHNODE} . "
 |-----------------------------------------------------------
 | File of DNS server:    | " . cluster_serverconf::dns_data()->{ZONE_DIR} . "
 |-----------------------------------------------------------
 | Work dir:              | " . cluster_serverconf::dns_data()->{WDIR} . "
 |-----------------------------------------------------------

";
}
# end printinfo
sub check_empty_ipforwarder() {
    if (cluster_serverconf::dns_data()->{IPOFFORWARDER} ne '') { return 1 } else { return 0 };
}

sub get_spe_ip {
  # waiting iprev, ipnorm or ipend
  my ($att, $ip) = @_;
  my @o = split(/\./, $ip);
  if ($att =~ /iprev/) {
    my $iprev = $o[2] . "." . $o[1] . "." . $o[0];
    return $iprev;
  } elsif ($att =~ /ipnor/) {
    my $ipnor = $o[0] . "." . $o[1] . "." . $o[2];
    return $ipnor;
  } elsif ($att =~ /ipend/) {
    my $ipend = $o[3];
    return $ipend;
 }
}


# check that hostnmae is != from localhost
sub check_hostname() {
  if (cluster_commonconf::mysystem()->{HOSTNAME} =~ /localhost/) {
    die "
Strange name for a DNS server ?
cant configure a DNS server with such a name: " .
cluster_commonconf::mysystem()->{HOSTNAME} . "
EXITING ...
";
    }
}
# end check that hostnmae

# check domainame != localdomain
sub check_domain() {
  if (member(cluster_serverconf::dns_data()->{DOMAINNAME}, qw(localdomain (none)))) {
    die "
Strange DOMAIN for a DNS server ?
cant configure a DNS server with such a DOMAINNAME: " .
cluster_serverconf::dns_data()->{DOMAINNAME} . "
please edit /etc/sysconfig/network
and choose a corect DOMAINNAME
or set a correct dommainname
EXITING ...
";
   }
}
# end check domainame

# check ip of server not in range of node ip
sub check_range_ip() {
  my $ip = cluster_serverconf::system_network()->{IPSERVER};
  print " - Checking IP of SERVER in RANGE IP\n";

  if (cluster_serverconf::cluster_data()->{STARTNODE} >= cluster_serverconf::cluster_data()->{FINISHNODE}) {
    die qq(
	       STARTNODE is greater than FINISHNODE !!);
  }

  if (cluster_serverconf::cluster_data()->{FINISHNODE} > 254) {
    die qq(
	       Be carefull ! IP out of 1 to 254 RANGE !\n);
  }

  if (member(get_spe_ip('ipend', $ip), cluster_serverconf::cluster_data()->{STARTNODE} .. cluster_serverconf::cluster_data()->{FINISHNODE})) {
    die qq(
       !!!! WARNING !!!!
       IP of DNS Server found twice in DNS !!
       change the range ip of nodes\n);
  }
}
# end checkrange


# create db.localhost file
sub crea_db_local() {
    print " - Creating " . cluster_serverconf::dns_data()->{WDIR} . "/db.localhost\n";
    my $h = cluster_commonconf::mysystem()->{HOSTNAME};
    my $s = cluster_serverconf::dns_data()->{SERIAL};
    output(cluster_serverconf::dns_data()->{WDIR} . "/db.localhost", <<EOF);
\$TTL 3D
\@       IN      SOA     $h. root.$h. (
         $s  ; Serial
	 8H  ; Refresh
	 2H  ; Retry
	 4W  ; Expire
	 1D) ; Minimum TTL
         NS      $h.
1        IN PTR   localhost.
EOF
}
# end of db.local

sub crea_trusted_network {
  my $ip = cluster_serverconf::system_network()->{IPSERVER};
      my $ipnor = get_spe_ip('ipnor', $ip);
      print " - Creating " . cluster_serverconf::dns_data()->{WDIR} . "/trusted_networks_acl.conf\n";
      output(cluster_serverconf::dns_data()->{WDIR} ."/trusted_networks_acl.conf", <<EOF);
acl "trusted" {
      // Place our internal and DMZ subnets in here so that
      // intranet and DMZ clients may send DNS queries.  This
      // also prevents outside hosts from using our name server
      // as a resolver for other domains.
      $ipnor/24;
      localhost; 
};
EOF
}

sub crea_bogon_acl {
  my $ip = cluster_serverconf::system_network()->{IPSERVER};
      print " - Creating " . cluster_serverconf::dns_data()->{WDIR} . "/bogon_acl.conf\n";
      output(cluster_serverconf::dns_data()->{WDIR} ."/bogon_acl.conf", <<EOF);
   acl "bogon" {
       // Filter out the bogon networks.  These are networks
       // listed by IANA as test, RFC1918, Multicast, experi-
       // mental, etc.  If you see DNS queries or updates with
       // a source address within these networks, this is likely
       // of malicious origin. CAUTION: If you are using RFC1918
       // netblocks on your network, remove those netblocks from
       // this list of blackhole ACLs!
       0.0.0.0/8;
       1.0.0.0/8;
       2.0.0.0/8;
       5.0.0.0/8;
       7.0.0.0/8;
       //10.0.0.0/8;
       23.0.0.0/8;
       27.0.0.0/8;
       31.0.0.0/8;
       36.0.0.0/8;
       37.0.0.0/8;
       39.0.0.0/8;
       41.0.0.0/8;
       42.0.0.0/8;
       49.0.0.0/8;
       50.0.0.0/8;
       58.0.0.0/8;
       59.0.0.0/8;
       60.0.0.0/8;
       70.0.0.0/8;
       71.0.0.0/8;
       72.0.0.0/8;
       73.0.0.0/8;
       74.0.0.0/8;
       75.0.0.0/8;
       76.0.0.0/8;
       77.0.0.0/8;
       78.0.0.0/8;
       79.0.0.0/8;
       83.0.0.0/8;
       84.0.0.0/8;
       85.0.0.0/8;
       86.0.0.0/8;
       87.0.0.0/8;
       88.0.0.0/8;
       89.0.0.0/8;
       90.0.0.0/8;
       91.0.0.0/8;
       92.0.0.0/8;
       93.0.0.0/8;
       94.0.0.0/8;
       95.0.0.0/8;
       96.0.0.0/8;
       97.0.0.0/8;
       98.0.0.0/8;
       99.0.0.0/8;
       100.0.0.0/8;
       101.0.0.0/8;
       102.0.0.0/8;
       103.0.0.0/8;
       104.0.0.0/8;
       105.0.0.0/8;
       106.0.0.0/8;
       107.0.0.0/8;
       108.0.0.0/8;
       109.0.0.0/8;
       110.0.0.0/8;
       111.0.0.0/8;
       112.0.0.0/8;
       113.0.0.0/8;
       114.0.0.0/8;
       115.0.0.0/8;
       116.0.0.0/8;
       117.0.0.0/8;
       118.0.0.0/8;
       119.0.0.0/8;
       120.0.0.0/8;
       121.0.0.0/8;
       122.0.0.0/8;
       123.0.0.0/8;
       124.0.0.0/8;
       125.0.0.0/8;
       126.0.0.0/8;
       127.0.0.0/8;
       169.254.0.0/16;
       172.16.0.0/12;
       192.0.2.0/24;
       192.168.0.0/16;
       197.0.0.0/8;
       201.0.0.0/8;
       //224.0.0.0/3;
   };
EOF
}

# create named.conf file
sub crea_named_common() {
    print " - Creating " . cluster_serverconf::dns_data()->{WDIR} . "/named.conf\n";
    my $ipserv = cluster_serverconf::system_network()->{IPSERVER};
    my $k = cluster_serverconf::dns_data()->{DNSKEY};
    my $fr = cluster_serverconf::dns_data()->{IPOFFORWARDER};
    output(cluster_serverconf::dns_data()->{WDIR} . "/named.conf", <<EOF);

include "/etc/bogon_acl.conf";
include "/etc/trusted_networks_acl.conf";

controls {
    inet 127.0.0.1 port 953
    allow { 127.0.0.1; $ipserv; };
};

options {
    version "";
    directory "/var/named";
    dump-file "/var/tmp/named_dump.db";
    pid-file "/var/run/named.pid";
    statistics-file "/var/tmp/named.stats";
    zone-statistics yes;
    auth-nxdomain yes;
    query-source address * port *;
    listen-on port 53 { any; };
    cleaning-interval 120;
    transfers-in 20;
    transfers-per-ns 2;
    lame-ttl 0;
    max-ncache-ttl 10800;
    notify no;
    transfer-format many-answers;
    max-transfer-time-in 60;
    interface-interval 0;
    allow-query { any; };
    allow-recursion { any; };
    allow-transfer { any; };
EOF


    if (check_empty_ipforwarder() =~ /1/) {
	append_to_file(cluster_serverconf::dns_data()->{WDIR} . "/named.conf", "forwarders { $fr; };");
    }

    append_to_file(cluster_serverconf::dns_data()->{WDIR} . "/named.conf", <<EOF);
};

zone "ac" { type delegation-only; };
zone "cc" { type delegation-only; };
zone "com" { type delegation-only; };
zone "cx" { type delegation-only; };
zone "lv" { type delegation-only; };
zone "museum" { type delegation-only; };
zone "net" { type delegation-only; };
zone "nu" { type delegation-only; };
zone "ph" { type delegation-only; };
zone "sh" { type delegation-only; };
zone "tm" { type delegation-only; };
zone "ws" { type delegation-only; };

zone "." IN {
        type hint;
        file "named.ca";
};

zone "localdomain" IN {
        type master;
        file "master/localdomain.zone";
        allow-update { none; };
};

zone "localhost" IN {
        type master;
        file "master/localhost.zone";
        allow-update { none; };
};

zone "0.0.127.in-addr.arpa" IN {
        type master;
        file "reverse/named.local";
        allow-update { none; };

};

zone "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa" IN {
        type master;
        file "reverse/named.ip6.local";
        allow-update { none; };
};

zone "255.in-addr.arpa" IN {
        type master;
        file "reverse/named.broadcast";
        allow-update { none; };
};

zone "0.in-addr.arpa" IN {
        type master;
        file "reverse/named.zero";
        allow-update { none; };
};
EOF
}
# end named.conf

sub crea_named_master {
  my ($ip, $d) = @_;
  my $iprev = get_spe_ip('iprev', $ip);
  append_to_file(cluster_serverconf::dns_data()->{WDIR} . "/named.conf", <<EOF);
zone "$iprev.in-addr.arpa" {
    type master;
    file "zone/db.$iprev.hosts";
    forwarders { };
};

zone "$d" {
    type master;
    file "zone/db.$d.hosts";
    forwarders { };
};
EOF
}

sub crea_named_slave {
  my ($ip, $d, $IPM) = @_;
  my $iprev = get_spe_ip('iprev', $ip);
  append_to_file(cluster_serverconf::dns_data()->{WDIR} . "/named.conf", <<EOF);
zone "$iprev.in-addr.arpa" {
    type slave;
    masters { $IPM; };
    file "bak.db.$iprev.hosts";
};

zone "$d" {
    type slave;
    masters { $IPM; };
    file "bak.db.$d.hosts";
};
EOF
}

# create hints
sub crea_hints() {
    print " - Creating " . cluster_serverconf::dns_data()->{WDIR} . "/root.hints\n";
    output(cluster_serverconf::dns_data()->{WDIR} . "/root.hints", <<EOF);
; <<>> DiG 8.1 <<>> \@A.ROOT-SERVERS.NET.
; (1 server found)
;; res options: init recurs defnam dnsrch
;; got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 10
;; flags: qr aa rd; QUERY: 1, ANSWER: 13, AUTHORITY: 0, ADDITIONAL: 13
;; QUERY SECTION:
;;      ., type = NS, class = IN

;; ANSWER SECTION:
.                       6D IN NS        G.ROOT-SERVERS.NET.
.                       6D IN NS        J.ROOT-SERVERS.NET.
.                       6D IN NS        K.ROOT-SERVERS.NET.
.                       6D IN NS        L.ROOT-SERVERS.NET.
.                       6D IN NS        M.ROOT-SERVERS.NET.
.                       6D IN NS        A.ROOT-SERVERS.NET.
.                       6D IN NS        H.ROOT-SERVERS.NET.
.                       6D IN NS        B.ROOT-SERVERS.NET.
.                       6D IN NS        C.ROOT-SERVERS.NET.
.                       6D IN NS        D.ROOT-SERVERS.NET.
.                       6D IN NS        E.ROOT-SERVERS.NET.
.                       6D IN NS        I.ROOT-SERVERS.NET.
.                       6D IN NS        F.ROOT-SERVERS.NET.

;; ADDITIONAL SECTION:
G.ROOT-SERVERS.NET.     5w6d16h IN A    192.112.36.4
J.ROOT-SERVERS.NET.     5w6d16h IN A    198.41.0.10
K.ROOT-SERVERS.NET.     5w6d16h IN A    193.0.14.129
L.ROOT-SERVERS.NET.     5w6d16h IN A    198.32.64.12
M.ROOT-SERVERS.NET.     5w6d16h IN A    202.12.27.33
A.ROOT-SERVERS.NET.     5w6d16h IN A    198.41.0.4
H.ROOT-SERVERS.NET.     5w6d16h IN A    128.63.2.53
B.ROOT-SERVERS.NET.     5w6d16h IN A    128.9.0.107
C.ROOT-SERVERS.NET.     5w6d16h IN A    192.33.4.12
D.ROOT-SERVERS.NET.     5w6d16h IN A    128.8.10.90
E.ROOT-SERVERS.NET.     5w6d16h IN A    192.203.230.10
I.ROOT-SERVERS.NET.     5w6d16h IN A    192.36.148.17
F.ROOT-SERVERS.NET.     5w6d16h IN A    192.5.5.241
;; Total query time: 215 msec
;; FROM: roke.uio.no to SERVER: A.ROOT-SERVERS.NET.  198.41.0.4
;; WHEN: Sun Feb 15 01:22:51 1998
;; MSG SIZE  sent: 17  rcvd: 436
EOF
}
# end roots.hints

# create ipreverse
sub crea_iprev {
  my ($ip, $d, $nn) = @_;
  my $sh = cluster_commonconf::mysystem()->{SHORTHOSTNAME};
  my $s = cluster_serverconf::dns_data()->{SERIAL};
  my $nb = cluster_serverconf::cluster_data()->{STARTNODE};
  my $ne = cluster_serverconf::cluster_data()->{FINISHNODE};
  my $iprev = get_spe_ip('iprev', $ip);
  my $ipend = get_spe_ip('ipend', $ip);
  print " - Creating " . cluster_serverconf::dns_data()->{WDIR} . "/db." . $iprev . ".hosts\n";
  output(cluster_serverconf::dns_data()->{WDIR} . "/db." . $iprev . ".hosts", <<EOF);
\$TTL 3D
@       IN      SOA     $sh.$d.        $sh.$d. (
		$s ; serial
                10800   ; Refresh
                3600    ; Retry
                604800  ; Expire
                86400) ; Minimum TTL
                NS      $sh.$d.
$ipend       IN      PTR     $sh.$d.
EOF

append_to_file(cluster_serverconf::dns_data()->{WDIR} . "/db." . $iprev . ".hosts", map { "$_     IN      PTR   $nn$_.$d. \n" } $nb .. $ne);

}
# end create iprev

# create  ipnormal
sub crea_ipnorm {
  my ($ip, $d, $nn, $alias) = @_;
  my $sh = cluster_commonconf::mysystem()->{SHORTHOSTNAME};
  my $s = cluster_serverconf::dns_data()->{SERIAL};
  my $ti = cluster_serverconf::dns_data()->{TEXTINFO};
  my $nb = cluster_serverconf::cluster_data()->{STARTNODE};
  my $ne = cluster_serverconf::cluster_data()->{FINISHNODE};
  my $ipnor = get_spe_ip('ipnor', $ip);
  print " - Creating " . cluster_serverconf::dns_data()->{WDIR} . "/db.$d.hosts\n";
  output(cluster_serverconf::dns_data()->{WDIR} . "/db.$d.hosts", <<EOF);
\$TTL 3D
@       IN      SOA     $sh.$d. root.$sh.$d. (
               $s       ; Serial
               8H   ; Refresh
               2H   ; Retry
               4W  ; Expire
               1D)  ; Minimum TTL
               TXT     $ti
               IN      NS      $sh.$d.
localhost              A       127.0.0.1
dns                    IN      CNAME   $sh.$d.
smtp                   IN      CNAME   $sh.$d.
mail                   IN      CNAME   $sh.$d.
$sh.$d.        IN      A      $ip
EOF
    append_to_file(cluster_serverconf::dns_data()->{WDIR} . "/db.$d.hosts", map { "$nn$_   IN      A       $ipnor.$_\n
$alias$_     IN      CNAME   $nn$_.$d. \n" } $nb .. $ne);
}
# end of ipnorm


# create 127.0.
sub crea_127() {
  my $d = cluster_serverconf::dns_data()->{DOMAINNAME};
  my $s = cluster_serverconf::dns_data()->{SERIAL};
  my $h = cluster_commonconf::mysystem()->{HOSTNAME};
  print " - Creating " . cluster_serverconf::dns_data()->{WDIR} . "/db.127.0.0.1\n";
  output(cluster_serverconf::dns_data()->{WDIR} . "/db.127.0.0.1", <<EOF);
\$TTL 3D
\@               IN      SOA     $d. root.$d. (
                $s       ; Serial
                28800   ; Refresh
                7200    ; Retry
                604800  ; Expire
                86400)  ; Minimum TTL
                NS      $h.
localhost      IN       A     127.0.0.1
EOF
}
# end create 127

# create rndc.conf
sub crea_rndc() {
  my $k = cluster_serverconf::dns_data()->{DNSKEY};
  print " - Creating " . cluster_serverconf::dns_data()->{WDIR} . "/rndc.conf\n";
  output(cluster_serverconf::dns_data()->{WDIR} . "/rndc.conf", <<EOF);
/*
* Copyright (C) 2000, 2001  Internet Software Consortium.
*
* Permission to use, copy, modify, and distribute this software for any
* purpose with or without fee is hereby granted, provided that the above
* copyright notice and this permission notice appear in all copies.
*
* THE SOFTWARE IS PROVIDED "AS IS" AND INTERNET SOFTWARE CONSORTIUM
* DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL
* INTERNET SOFTWARE CONSORTIUM BE LIABLE FOR ANY SPECIAL, DIRECT,
* INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING
* FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
* NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION
* WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*/
/* Id: dns_cluster.pm,v 1.18 2003/04/10 16:01:47 aginies Exp */
/*
* Sample rndc configuration file.
*/

options {
    default-server  localhost;
    default-key     "mykey";
};

server localhost {
    key     "mykey";
};

key "mykey" {
    algorithm       hmac-md5;
    secret "$k";
};
EOF
}
# end of create rndc

# save old config files
sub save_old_config() {
  if (-d cluster_serverconf::dns_data()->{ZONE_DIR}) {
    print " - Backup of current configuration in " . cluster_serverconf::cluster_data()->{REP_SAVE} . "\n";
  }
  mkdir_p(cluster_serverconf::cluster_data()->{REP_SAVE} . '/dns');
  cp_af($_, $_ . '-' . cluster_commonconf::mysystem()->{DATE} . '.sauv') foreach glob_(cluster_serverconf::dns_data()->{ZONE_DIR} . "/*");
  if (-e "/etc/named.conf") {
    save_config("/etc/named.conf");
  }
}
# end save old config

sub generate_rndc() {
  my $wdir = cluster_serverconf::dns_data()->{WDIR};
  mkdir_p($wdir);
  sys("rndc-confgen -a -c $wdir/rndc.key");
  my ($key) = cat_("$wdir/rndc.key") =~ /secret "(\S*)";/;
  print " - Value of rndc.key: $key\n";
  $key;
}


# reinit resolv.conf
sub set_resolv() {
  my $d = cluster_serverconf::dns_data()->{DOMAINNAME};
  my $ad = cluster_serverconf::dns_data()->{ADDSEARCH};
  my $ip = cluster_serverconf::system_network()->{IPSERVER};
  print " - Setting " . cluster_serverconf::dns_data()->{WDIR} . "/resolv.conf\n";
  output(cluster_serverconf::dns_data()->{WDIR} . "/resolv.conf", <<EOF);
domain $d
search $d $ad
nameserver $ip
EOF
}
# end set resolv.conf

# set /etc/hosts
sub set_hosts {
  my ($ip, $h) = @_;
  print " - Setting " . cluster_serverconf::dns_data()->{WDIR} . "/hosts\n";
  if (!any { /$ip\s* $h/ } cat_(cluster_serverconf::dns_data()->{WDIR} . "/hosts")) {
    append_to_file(cluster_serverconf::dns_data()->{WDIR} . "/hosts", <<EOF);
$ip        $h
EOF
  }
}
# end set hosts

# check config of dns
sub check_config() {
  print ' - Checking that config file in ' . cluster_serverconf::dns_data()->{WDIR} . " are good\n";
  sys('named-checkconf', cluster_serverconf::dns_data()->{WDIR} . '/named.conf');
}
# end check config

# copy file correct place
sub copy_good() {
  print " - Copying DNS server files in correct place\n";
  mkdir_p(cluster_serverconf::dns_data()->{ZONE_DIR});
  cp_af(cluster_serverconf::dns_data()->{WDIR} . '/named.conf', cluster_serverconf::dns_data()->{NAMED_DIR} . '/etc/named.conf');
#  cp_af(cluster_serverconf::dns_data()->{WDIR} . '/rndc.conf', '/etc/rndc.conf');
  cp_af(cluster_serverconf::dns_data()->{WDIR} . '/hosts', '/etc/hosts');
  cp_af(cluster_serverconf::dns_data()->{WDIR} . '/resolv.conf', '/etc/resolv.conf');
  cp_af(cluster_serverconf::dns_data()->{WDIR} . '/trusted_networks_acl.conf', cluster_serverconf::dns_data()->{NAMED_DIR} . '/etc/trusted_networks_acl.conf');
  cp_af(cluster_serverconf::dns_data()->{WDIR} . '/bogon_acl.conf', cluster_serverconf::dns_data()->{NAMED_DIR} . '/etc/bogon_acl.conf');
#  cp_af(cluster_serverconf::dns_data()->{WDIR} . '/root.hints', cluster_serverconf::dns_data()->{ZONE_DIR} . '/');
  cp_af(glob(cluster_serverconf::dns_data()->{WDIR} . '/db*'), cluster_serverconf::dns_data()->{ZONE_DIR} . '/');
}
# end copy goodplace

sub add_srv_alias_node {
    print " - Add serveur in DNS, with node alias\n";
  my ($ipa, $ipc) = @_;
  my $node_name = cluster_serverconf::cluster_data()->{NODENAME};
  my $d = cluster_serverconf::dns_data()->{DOMAINNAME};
  my $SH = cluster_commonconf::mysystem()->{SHORTHOSTNAME};
#  my $ipnora = get_spe_ip('ipnor', $ipa);
  my $ipenda = get_spe_ip('ipend', $ipa);
  my $zone_dir = cluster_serverconf::dns_data()->{ZONE_DIR};
    if (!any { /$node_name$ipenda/ } cat_("$zone_dir/db.$d.hosts")) {
	append_to_file("$zone_dir/db.$d.hosts", "$node_name$ipenda                   IN      CNAME   $SH.$d.\n");
	append_to_file("$zone_dir/db.$d.hosts", "n$ipenda                   IN      CNAME   $SH.$d.\n");
	#append_to_file(cluster_serverconf::dns_data()->{ZONE_DIR} . "db.$ipnora.hosts", "");
    }
    service_do('named', 'reload');
}

sub set_dns {
# parameter should be master to set a Master DNS_server
# other it will be a Slave DNS.
  my ($st) = @_;
  system('clear');
  crea_wdir(cluster_serverconf::dns_data()->{WDIR});
  # print info of dns
  print_info();
  check_domain();
  check_hostname();
  check_range_ip();
  # create files
  crea_db_local();
  crea_127();
  crea_trusted_network();
  crea_bogon_acl();
  crea_named_common();
  # set host configuration
  if (-f cluster_serverconf::dns_data()->{WDIR} . '/hosts')  { rm_rf(cluster_serverconf::dns_data()->{WDIR} . '/hosts') }
  set_hosts('127.0.0.1', 'localhost.localdomain localhost');
  set_hosts(cluster_serverconf::system_network()->{IPSERVER}, cluster_commonconf::mysystem()->{HOSTNAME});

  if ($st =~ /master/) {
    print " - Will be a Master DNS :-) \n";
    crea_iprev(cluster_serverconf::system_network()->{IPSERVER}, cluster_serverconf::dns_data()->{DOMAINNAME}, cluster_serverconf::cluster_data()->{NODENAME});
    crea_ipnorm(cluster_serverconf::system_network()->{IPSERVER}, cluster_serverconf::dns_data()->{DOMAINNAME}, cluster_serverconf::cluster_data()->{NODENAME}, 'n');
    crea_named_master(cluster_serverconf::system_network()->{IPSERVER}, cluster_serverconf::dns_data()->{DOMAINNAME});

  } else {
    print " - A host Will be a Slave DNS (no power on zone :-( ) \n"; sleep 2;
    print " - Enter IP Of DNS master server:\n";
    my $o = chomp_(get_an_ip());
    crea_named_slave(cluster_serverconf::system_network()->{IPSERVER}, cluster_serverconf::dns_data()->{DOMAINNAME} ,$o);
  }

  #crea_hints();
  crea_rndc();
  # set configuration files on server
  set_resolv();
  # check generated config file are good
#  check_config();
  # create backup
  save_old_config();
  # copy in correct place
  copy_good();
  # start or restart the service
  system('rndc', 'stop');
  service_do('named', 'start');
}

sub get_an_ip() {
  local $_;
  while (<STDIN>) {
    return $_ if is_ip($_);
    warn " enter an Ip address, not nimporte koi !\n";
  }
}


sub help_dns() {
   print "
 HELP:
 |---------------------------------------------------------|
 | resolv              adjust resolv.conf                  |
 | rndckey             generate a rndc.key                 |
 | hosts               adjust hosts with ip and hostname   |
 | checkdomain         check the domainname                |
 | checkhostname       check the hostname                  |
 | info                print info of current configuration |
 | master              set a dns master server             |
 |---------------------------------------------------------|

";
}

sub main_dns() {
    my %opts = (
		'' => \&help_dns,
		resolv => \&set_resolv,
		rndckey => \&generate_rndc,
		hosts => \&set_hosts,
		checkdomain => \&check_domain,
		checkhostname => \&check_hostname,
		info => \&print_info,  
		master => sub { set_dns('master') },
		);

    if (my $f = $opts{$ARGV[0]}) {
        $f->();
    } else { 
	print " ** Dont know what todo ** \n";
    }
}

1;

