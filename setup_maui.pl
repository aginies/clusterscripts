#!/usr/bin/perl 
# v 0.1
# GPL like
# aginies@mandrakesoft.com

use strict;
use MDK::Common;
use cluster_serverconf;
use cluster_commonconf;
use maui_cluster;


#my $part = 'pcluster';
#my $users = users_in_partition($part);
#print " - users list affected to partition $part:\n";
#foreach (@$users) { print "  $_\n" }

main_maui();

#my $user = 'guibo';
#if (remove_user_from_partition($user, $part)) {
#    print " - Removing user $user from $part\n";
#} else {
#    print " - No $user found in $part\n";
#}

#if (add_user_in_partition($user, $part)) {
#  print " - Adding user $user in $part\n";
#} else {
#  print " - Unable to find user section\n";
#}
#my $node = 'cnode2.domcomp';
#$part = 'pcluster2';
#if (change_partition_of_node($node, $part)) {
#  print " - Changing $node to $part\n";
#} else {
#  print " - No $node found\n";
#}
