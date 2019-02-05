#!/usr/bin/perl 
# Author : Daniel Viard <dviard@mandrakesoft.com>
# Version 0.1
# please report bug to: cooker@mandrakesoft.com

use add_nodes_to_dhcp_cluster;
use server_cluster;

add_nodes_to_dhcp_cluster::main();
server_cluster::need_after_ar_node();

