#!/usr/bin/perl

use strict;
use MDK::Common;
use cluster_serverconf;
use cluster_commonconf;
use cluster_fonction_common;

##########################
my $hib = "/etc/hosts";
my $mpi_ib = "/etc/sysconfig/mpi_hosts";
my $interface = "eth0";
my $net = "12.12.12";
########################

sub create_mpi_host_config() {
        print " - Creating $mpi_ib for infiniband\n";
        foreach (cat_(cluster_serverconf::cluster_data()->{NODESFILE})) {
        my ($name) = /(\w+)\..*:/;
        if (! any { /$name-ib/ } cat_($mpi_ib)) {
            append_to_file($mpi_ib, "$name-ib\n");
        }
    }
}

sub create_etc_host_config() {
    print " - Creating $hib for infiniband\n";
    foreach (cat_(cluster_serverconf::cluster_data()->{NODESFILE})) {
        my ($name) = /(\w+)\..*:/;
        my ($ipend) = $name =~ /(\d+)/;
        my $ip = "$net.$ipend";
        if (! any { /$ip/ } cat_($hib)) {
            append_to_file($hib, "$ip $name-ib\n");
        }
    }
}

sub create_ibconfig() {
        create_etc_host_config;
        create_mpi_host_config;
}

create_ibconfig;

