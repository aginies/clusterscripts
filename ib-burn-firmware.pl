#!/usr/bin/perl
# BEGIN_ICS_COPYRIGHT8 ****************************************
#   
#   Copyright 2004 Mercury Computer Systems - All Rights Reserved
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, Inc., 675 Mass Ave, Cambridge MA 02139,
#   USA; version 2 of the License; incorporated herein by reference.
#
#   A copy of the GNU General Public License, version 2
#   can also be found in the GPL_LICENSE file at the base of this source tree
#
# END_ICS_COPYRIGHT8   ****************************************

# [ICS VERSION STRING: @(#) ./INSTALL 3_0_0_1_5G [03/04/05 10:31]

#

#++
# "This software program is available to you under a choice of one of two 
# licenses.  You may choose to be licensed under either the GNU General Public 
# License (GPL) Version 2, June 1991, available at 
# http://www.fsf.org/copyleft/gpl.html, or the Intel BSD + Patent License, 
# the text of which follows:
# 
# "Recipient" has requested a license and Intel Corporation ("Intel") is willing
# to grant a license for the software entitled InfiniBand(tm) System Software 
# (the "Software") being provided by Intel Corporation.

# The following definitions apply to this License: 

# "Licensed Patents" means patent claims licensable by Intel Corporation which 
# are necessarily infringed by the use or sale of the Software alone or when 
# combined with the operating system referred to below.

# "Recipient" means the party to whom Intel delivers this Software.
# "Licensee" means Recipient and those third parties that receive a license to 
# any operating system available under the GNU Public License version 2.0 or 
# later.

# Copyright (c) 1996-2002 Intel Corporation. All rights reserved. 

# The license is provided to Recipient and Recipient's Licensees under the 
# following terms.  

# Redistribution and use in source and binary forms of the Software, with or 
# without modification, are permitted provided that the following conditions are 
# met: 
# Redistributions of source code of the Software may retain the above copyright 
# notice, this list of conditions and the following disclaimer. 

# Redistributions in binary form of the Software may reproduce the above 
# copyright notice, this list of conditions and the following disclaimer in the 
# documentation and/or other materials provided with the distribution. 

# Neither the name of Intel Corporation nor the names of its contributors shall 
# be used to endorse or promote products derived from this Software without 
# specific prior written permission.

# Intel hereby grants Recipient and Licensees a non-exclusive, worldwide, 
# royalty-free patent license under Licensed Patents to make, use, sell, offer 
# to sell, import and otherwise transfer the Software, if any, in source code 
# and object code form. This license shall include changes to the Software that 
# are error corrections or other minor changes to the Software that do not add 
# functionality or features when the Software is incorporated in any version of 
# a operating system that has been distributed under the GNU General Public 
# License 2.0 or later.  This patent license shall apply to the combination of 
# the Software and any operating system licensed under the GNU Public License 
# version 2.0 or later if, at the time Intel provides the Software to Recipient, 
# such addition of the Software to the then publicly available versions of such 
# operating system available under the GNU Public License version 2.0 or later 
# (whether in gold, beta or alpha form) causes such combination to be covered by 
# the Licensed Patents. The patent license shall not apply to any other 
# combinations which include the Software. No hardware per se is licensed 
# hereunder. 

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL INTEL OR ITS CONTRIBUTORS BE LIABLE FOR ANY 
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
#--
use strict;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
use File::Basename;
use Math::BigInt;

#Setup some defaults
my $KEY_ESC=27;
my $KEY_CNTL_C=3;
my $KEY_ENTER=13;

# version string is filled in by prep, special marker format for it to use
my $CUR_OS_VER = `uname -r`;
chomp $CUR_OS_VER;

my $VERSION = "THIS_IS_THE_ICS_VERSION_NUMBER:@(#)3.0.0.1.5G% 000B000";
$VERSION =~ s/THIS_IS_THE_ICS_VERSION_NUMBER:@\(#\)//;
$VERSION =~ s/%.*//;
my $INT_VERSION = "THIS_IS_THE_ICS_INTERNAL_VERSION_NUMBER:@(#)3_0_0_1_5G% 000B000";
$INT_VERSION =~ s/THIS_IS_THE_ICS_INTERNAL_VERSION_NUMBER:@\(#\)//;
$INT_VERSION =~ s/%.*//;
my $BRAND = "THIS_IS_THE_ICS_BRAND:Mercury Computer Systems, Inc.%          ";
# backslash before : is so patch_brand doesn't replace string
$BRAND =~ s/THIS_IS_THE_ICS_BRAND\://;
$BRAND =~ s/%.*//;
my $SRC_FILE_DIR = ".";
my $MODULE_CONF_FILE = "/etc/modules.conf";
my $FF_CONF_FILE = "/etc/sysconfig/fastfabric.conf";
if (substr($CUR_OS_VER,0,3) eq "2.6")
{
	# keep using /etc/modules.conf
	#  $MODULE_CONF_FILE = "/etc/modprobe.conf";
}
if (-f "$(MODULE_CONF_FILE).local")
{
	$MODULE_CONF_FILE = "$(MODULE_CONF_FILE).local";
}
my $UVP_CONF_FILE = "/etc/sysconfig/iba/uvp.conf";
my $NETWORK_CONF_DIR = "/etc/sysconfig/network-scripts";
my $ROOT = "/";

#This string is compared in verify_os_rev for correct revision of
#kernel release. The version of modutils 
my $CUR_DISTRO_VER = "";
my $INSTALL_CHOICE=2;
my $IBA_CONF="modules.conf";	## additions to modules.conf
my $TMP_CONF="/tmp/conf.$$";
my $ARCH = `uname -m | sed -e s/i.86/IA32/ -e s/ia64/IA64/ -e s/x86_64/X86_64/`;
chomp $ARCH;
my $ARCH_VENDOR=`grep vendor_id /proc/cpuinfo | tail -1`;
chomp $ARCH_VENDOR;
if ($ARCH eq "X86_64")
{
	if ((-f "$ROOT/etc/redhat-release" || -f "$ROOT/etc/rocks-release") && $ARCH_VENDOR =~ /.*GenuineIntel.*/ && substr($CUR_OS_VER,0,3) eq "2.4")
	{
		$ARCH = "EM64T";
	}
}
my $DRIVER_SUFFIX=".o";
if (substr($CUR_OS_VER,0,3) eq "2.6")
{
	$DRIVER_SUFFIX=".ko";
}
my $DBG_FREE="release";
#Fixed the problem of copying modules.conf repeatedly while installing 
#drivers during the same INSTALL script invocation.
my $DidConfig=0;
my $RunDepmod=0;
my $RunLdconfig=0;
my @supported_kernels = <./bin/$ARCH/*>;
my %KeepConfig = ();
# Components and Sub-Components which user has asked to stop
# these could be utilities or drivers
my %StopFacility = ();
my @module_dirs = ();
my $Default_Install=0;	# -a option used to select default install of All
my $Default_Upgrade=0;	# -U option used to select default upgrade of installed
my $Default_FirmwareUpgrade=0;	# -F option used to select default firmware upgrade
my $Default_Uninstall=0;	# -u option used to select default uninstall of All
my $Default_Autostart=0;	# -s option used to select default autostart of All
my $Default_SameAutostart=0; # -n option used to default install, preserving autostart values
my $Default_Prompt=0;	 # use default values at prompts, non-interactive
my $Default_CompInstall=0;	# -i option used to select default install of Default_Components
my $Default_CompUninstall=0;	# -e option used to select default uninstall of Default_Components
my %Default_Components = ();		# components selected by -i or -e

	# Names of supported install components
	# must be listed in depdency order such that prereqs appear 1st
	# kDAPL disabled for now, if enable also visit kdapl uninstall in
	# install_iba and uninstall_iba
sub installed_kdapl;
sub uninstall_kdapl;
#my @Components = ( "iba", "ibdev", "fastfabric", "ifibre", "inic", "ipoib",
#					"mpi", "mpidev", "mpisrc", "udapl", "kdapl", "sdp");
my @Components = ( "iba", "ibdev", "fastfabric", "ifibre", "inic", "ipoib",
					"mpi", "mpidev", "mpisrc", "udapl", "sdp");
	# full name of component for prompts
my %ComponentName = (
 				"iba" => "IB Network Stack",
				"ibdev" => "IB Development",
				"fastfabric" => "Fast Fabric",
				"ifibre" => "InfiniFibre",
				"inic" => "InfiniNIC",
				"ipoib" => "IP over IB",
				"mpi" => "MPI Runtime",
				"mpidev" => "MPI Development",
				"mpisrc" => "MPI Source",
				"udapl" => "uDAPL",
				"kdapl" => "kDAPL",
				"sdp" => "SDP"
				);

	# full name of sub-components for prompts
	# iba_mon is a tool with startup and config, but is part of iba
my %SubComponentName = (
 				"iba_mon" => "IB Port Monitor"
				);
	# other components which are prereqs of a given component
		# need space before and after each component name to facilitate compares
		# so that compares do not mistake names such as mpidev for mpi
my %ComponentPreReq = (
				"iba" => "",
				"ibdev" => " iba ",
				"fastfabric" => "",
				"ifibre" => " iba ",
				"inic" => " iba ",
				"ipoib" => " iba ",
				"mpi" => " iba ",
				"mpidev" => " iba mpi ",
				"mpisrc" => " iba ibdev mpi ",
				"udapl" => " iba ipoib ",
				"kdapl" => " iba ipoib udapl ",
				"sdp" => " iba ipoib ",
				);
	# components which have autostart capability
my %ComponentHasStart = (
 				"iba" => 1,
				"ibdev" => 0,
				"fastfabric" => 0,
				"ifibre" => 1,
				"inic" => 1,
				"ipoib" => 1,
				"mpi" => 1,
				"mpidev" => 0,
				"mpisrc" => 0,
				"udapl" => 1,
				"kdapl" => 1,
				"sdp" => 1
			);
	# has component been loaded since last configured autostart
my %Loaded = (
 				"iba" => 0,
				"ibdev" => 0,
				"fastfabric" => 0,
				"ifibre" => 0,
				"inic" => 0,
				"ipoib" => 0,
				"mpi" => 0,
				"mpidev" => 0,
				"mpisrc" => 0,
				"udapl" => 0,
				"kdapl" => 0,
				"sdp" => 0
			);

	# Names of fabric setup steps
my @FabricSetupSteps = ( "config", "pingall", "checkrsh", "setupssh",
				"copyhosts", "showuname", "install",
				"configipoib", "buildmpi", "reboot", "refreshssh",
				"cmdall", "copyall", "viewres"
					);
	# full name of steps for prompts
my %FabricSetupStepsName = (
 				"config" => "Edit Config and Select/Edit Hosts Files",
				"pingall" => "Verify Hosts via Ethernet ping",
				"checkrsh" => "Verify rsh/rcp Configured",
				"setupssh" => "Setup Password-less ssh/scp",
				"copyhosts" => "Copy /etc/hosts to all hosts",
				"showuname" => "Show uname -a for all hosts",
				"install" => "Install/Upgrade InfiniServ Software",
				"configipoib" => "Configure IPoIB IP Address",
				"buildmpi" => "Build MPI Test Apps and Copy to Hosts",
				"reboot" => "Reboot Hosts",
				"refreshssh" => "Refresh ssh Known Hosts",
				"cmdall" => "Run a command on all hosts",
				"copyall" => "Copy a file to all hosts",
				"viewres" => "View ibtest result files"
				);
	# Names of fabric admin steps
my @FabricAdminSteps = ( "config", "pingall", "fabric_info",
				"showallports", "sacache", "ipoibping",
				"refreshssh", "mpiperf", "captureall", "cmdall",
				"viewres"
					);
	# full name of steps for prompts
my %FabricAdminStepsName = (
 				"config" => "Edit Config and Select/Edit Hosts Files",
				"pingall" => "Verify Hosts via Ethernet ping",
				"fabric_info" => "Summary of Fabric Components",
				"showallports" => "Show Status of Host IB Ports",
				"sacache" => "Verify Hosts see Eachother",
				"ipoibping" => "Verify Hosts ping via IPoIB",
				"refreshssh" => "Refresh ssh Known Hosts",
				"mpiperf" => "Check MPI Performance",
				"captureall" => "Generate all Hosts Problem Report Info",
				"cmdall" => "Run a command on all hosts",
				"viewres" => "View ibtest result files"
				);
my @FabricChassisSteps = ( "config", "pingall", 
				"showallports", "reboot", "cmdall", "viewres"
					);
my %FabricChassisStepsName = (
 				"config" => "Edit Config and Select/Edit Chassis Files",
				"pingall" => "Verify Chassis via Ethernet ping",
				"showallports" => "Show Status of Chassis IB Ports",
				"reboot" => "Reboot Chassis",
				"cmdall" => "Run a command on all chassis",
				"viewres" => "View ibtest result files"
				);
my $FabricSetupHostsFile="/etc/sysconfig/iba/hosts";
# HOSTS_FILE overrides default
if ( "$ENV{HOSTS_FILE}" ne "" ) {
	$FabricSetupHostsFile="$ENV{HOSTS_FILE}";
}
my $FabricSetupScpFromDir=".";
my $FabricAdminHostsFile="/etc/sysconfig/iba/allhosts";
# HOSTS_FILE overrides default
if ( "$ENV{HOSTS_FILE}" ne "" ) {
	$FabricAdminHostsFile="$ENV{HOSTS_FILE}";
}
my $FabricChassisFile="/etc/sysconfig/iba/chassis";
# CHASSIS_FILE overrides default
if ( "$ENV{CHASSIS_FILE}" ne "" ) {
	$FabricChassisFile="$ENV{CHASSIS_FILE}";
}
my $Editor="$ENV{EDITOR}";
if ( "$Editor" eq "" ) {
	$Editor="vi";
}

# Assume a single HCA for now.
my $NUM_HCA_PORTS=2;
my $MAX_IB_PORTS=20;	# maximum valid ports
my $allow_install;

sub HitKeyCont;

if ( basename($0) ne "INSTALL" )
{
	if ( basename($0) eq "ics_ib" )
	{
		printf("Warning: ics_ib is depricated, use iba_config\n");
		HitKeyCont;
	}
	$allow_install=0;
} else {
	$allow_install=1;
	$FabricSetupScpFromDir="..";
}


sub getch
{
	my $c;
	system("stty -echo raw");
	$c=getc(STDIN);
	system("stty echo -raw");
	print "\n";
	return $c;
}

sub print_separator
{
	print "-------------------------------------------------------------------------------\n";
}

# remove any directory prefixes from path
sub basename
{
	my($path) = "$_[0]";

	$path =~ s/.*\/(.*)$/$1/;
	return $path
}

sub GetYesNo
{
	my($retval) = 1;
	my($answer) = 0;

	my($Question) = $_[0];
	my($default) = $_[1];

	if ( $Default_Prompt ) {
		print "$Question -> $default\n";
		print LOG_FD "$Question -> $default\n";
		if ( "$default" eq "y") {
			return 1;
		} elsif ("$default" eq "n") {
			return 0;
		}
		# for invalid default, fall through and prompt
	}

	while ($answer == 0)
	{
		print "$Question [$default]: ";
		chomp($_ = <STDIN>);
		#$_ = getch();
		if ("$_" eq "") {
			$_=$default;
		}
		if (/[Nn]/) 
		{
			print LOG_FD "$Question -> n\n";
			$retval = 0;
			$answer = 1;
		} elsif (/[Yy]/ ) {
			print LOG_FD "$Question -> y\n";
			$retval = 1;
			$answer = 1;
		}
	}        
	return $retval;
}


sub HitKeyCont
{
	if ( $Default_Prompt )
	{
		return;
	}

	print "Hit any key to continue...";
	#$_=<STDIN>;
	getch();
	return;
}


# is the given driver available on the install media
# is the given driver available on the install media
sub available_driver
{
	my($WhichDriver) = $_[0];
	$WhichDriver .= $DRIVER_SUFFIX;
	return ( -e "./bin/$ARCH/$CUR_OS_VER/$DBG_FREE/$WhichDriver" );
}



sub getTavorDeviceInfo
{
	my $device = $_[0];
	my $image  = $_[1];
	my %hdi;   
	my $option = "--flash-info";
	my $key;
	my $value;

	if ($image)
	{
		$option = "--image-info";
	}

	#print "-d $device $option $image\n";

	open(up,"mstfwupdate -d $device $option $image|");

	chomp($hdi{"imagetype"}=<up>);
	$hdi{"imagetype"}=~s/.* : //;

	chomp($hdi{"hardrev"}=<up>);
	$hdi{"hardrev"}=~s/.*0x//;

	chomp($hdi{"company"}=<up>);
	$hdi{"company"}=~s/.* : //;

	chomp($hdi{"creationdate"}=<up>);
	$hdi{"creationdate"}=~s/.* : //;

	chomp($hdi{"firmver"}=<up>);
	$hdi{"firmver"}=~s/.* : //;

	chomp($hdi{"firmwareaddress"}=<up>);
	$hdi{"firmwareaddress"}=~s/.* : //;

	chomp($hdi{"nodeguidoffset"}=<up>);
	$hdi{"nodeguidoffset"}=~s/.* : //;

	chomp($hdi{"nodeguid"}=<up>);
	$hdi{"nodeguid"}=~s/.* : //;

	chomp($hdi{"port1guid"}=<up>);
	$hdi{"port1guid"}=~s/.* : //;

	chomp($hdi{"port2guid"}=<up>);
	$hdi{"port2guid"}=~s/.* : //;

	close(up);

	#while (($key,$value) = each %hdi)
	#{
	#	print"$key=$value\n";
	#} 

	return %hdi;
}

sub getTavorPCIHcaHardwareRevision
{
	my $device = $_[0];
	my @lines;
	my $line;
	my @pci_info;
	my $busdevfn;
	my $addrreg;
	my $datareg;
	my $rev;

	open(d,"< $device");

	@lines=<d>;

	close(d);

	foreach $line (@lines)
	{
		if ($line =~m/bus:dev.fn=/)
		{
	    	$line =~ s/^ +//g;
	    	($busdevfn,$addrreg,$datareg)=split(/\s/,$line);
	    	$busdevfn =~ s/.*=//g;
	    	$addrreg  =~ s/.*=//g; 
	    	$datareg  =~ s/.*=//g;          
		}
	}    

	open(lpipe, "lspci -m -s $busdevfn|");
	$rev=<lpipe>;
	close(lpipe);
	$rev=~s/"/;/g;

        @pci_info=split(/;/,$rev);
	$rev=$pci_info[6];
	$rev=~s/.*-[r]//;
	chop($rev);
	 
	return $rev;
}

sub burn_hca_firmware
{
	my $file;
	my $firmware;
	my $dirpath;
	my @fwlist;
	my @Validfwlist;
	my $rev;
	my $x;
	my $choice;
	my $type = $_[0];
	my $device = $_[1];
	my $deviceNo = $_[2];
	my $NoOfFiles;
	my $HcaModel;
	my $HcaPciHardwareRev;
	my %FlashInfo;
	my %ImageInfo;
	my $CurrentSearchPath="/etc/sysconfig/iba/$_[0]";
	my $F_FirmVer;
	my $I_FirmVer;
	my $F_ImageType;
	my $I_ImageType;
	my $F_HardVer;
	my $I_HardVer;
	my $AlsoFindOthers=0;
	my $burn=0;
	my @list1;
	my @list2;
	my $res;
	my $burnoptions;        
	# lower 32 bits of guid ranges
	my %guid_range = ( 
		'cougar'  => { 'start' => hex "0x98002800", 'end' => hex "0x980033BF"},
		'sanmina' => { 'start' => hex "0x980033C0", 'end' => hex "0x98003F7F"},
		'cougarcub' => { 'start' => hex "0x98003F80", 'end' => hex "0x98006690"},

	);
	# upper 32 bits of guid ranges, same for all
	my $upperguid = hex "0x00066a00";


	$HcaPciHardwareRev = getTavorPCIHcaHardwareRevision($device);
	$HcaPciHardwareRev = uc($HcaPciHardwareRev);

	%FlashInfo = getTavorDeviceInfo($device);

	if ( $type eq "mt25208")
	{
		# Arbel has a different model number
		$HcaModel="InfiniServEx";
	} elsif ($FlashInfo{"company"} eq "InfiniCon Systems, Inc.")
	{
		# low 32 bits of hex number
		my $NODEGUID_LOWER = hex substr($FlashInfo{"nodeguid"}, -8);
		my $NODEGUID_UPPER = hex substr($FlashInfo{"nodeguid"}, 0, -8);

		if ( $NODEGUID_UPPER == $upperguid
			 && $NODEGUID_LOWER >= $guid_range{cougar}{start}
			 && $NODEGUID_LOWER <= $guid_range{cougar}{end})
		{
			$HcaModel="InfiniServC";
		} elsif ( $NODEGUID_UPPER == $upperguid
			 && $NODEGUID_LOWER >= $guid_range{sanmina}{start}
			 && $NODEGUID_LOWER <= $guid_range{sanmina}{end})
		{
			$HcaModel="InfiniServS";
		}elsif ( $NODEGUID_UPPER == $upperguid
			 && $NODEGUID_LOWER >= $guid_range{cougarcub}{start}
			 && $NODEGUID_LOWER <= $guid_range{cougarcub}{end})
		{
			$HcaModel="InfiniServCC";		
		}else {       
			$HcaModel="InfiniServ";
		}
	} elsif ($FlashInfo{"company"} eq "Mellanox, Inc")
	{
		$HcaModel="TavorEval";
	} else {
		$HcaModel="InfiniServ";
		if (! $FlashInfo{"nodeguid"} =~ m/0x00066[aA]009/) 
		{
			$AlsoFindOthers=1;
		}
	}

	printf("\n\nUpdating firmware on HCA $deviceNo ($HcaModel Rev $HcaPciHardwareRev):\n");
	print LOG_FD "Updating firmware on HCA $deviceNo ($HcaModel Rev $HcaPciHardwareRev):\n";

	$dirpath=$CurrentSearchPath;
	opendir(DNAME,"$dirpath");
	@list1 = grep /$HcaModel.$HcaPciHardwareRev.bin/, readdir(DNAME);	
	closedir(DNAME);

	# We use GUIDs to attempt to tell the difference between an HCA Tavor A0 and InfiniServ A0
	# with a Short image.  if guids are not InfiniCon Style,then find all TavorEval and
	# InfiniServ bin files.  The code below will remove non short images from the list.  
	if ($AlsoFindOthers == 1) 
	{
		opendir(DNAME,"$dirpath");
		@list2 = grep /TavorEval.$HcaPciHardwareRev.bin/, readdir(DNAME);
		@fwlist = (@list1,@list2);
		closedir(DNAME);
	} else {
		@fwlist = @list1;
	}

	# If it's an A0 rev Hca then only allow short image to be selected.
	if ("$type" eq "mt23108" and "$HcaPciHardwareRev" eq "A0") 
	{
		$x=0;
		foreach $firmware (@fwlist) 
		{        
			%ImageInfo = getTavorDeviceInfo("$device","$dirpath/$firmware");          
			#print "$x Checking $firmware ";
			if ($ImageInfo{"imagetype"} eq "Short") 
			{                  
				#print "Valid\n";
				$Validfwlist[$x]= $firmware;
				$x=$x+1;
			} #else {
			#   print "Invalid\n";
			#}        
		}
		#print "@Validfwlist \n";
	} else {
		@Validfwlist = @fwlist;
	}

START:

	$burn=0;
	$NoOfFiles=$#Validfwlist + 1;
	print "Found $NoOfFiles firmware file(s):\n";
	if ( $#Validfwlist == -1 )
	{
		print "The following directories appear to be void of any valid firmware files:\n";
		print "  $dirpath\n";
		print "Aborting operation.\n";
		print LOG_FD "The following directories appear to be void of any valid firmware files:\n";
		print LOG_FD "  $dirpath\n";
		print LOG_FD "Aborting operation.\n";
		HitKeyCont;
		return 0;
	} elsif ($#Validfwlist == 0) {
		# if we only find one valid firmware file, then use it!
		$file = "$dirpath/$Validfwlist[0]";
		print("1) $file\n");
	} elsif ( $#Validfwlist >= 1) {
		$x=0;

		foreach $firmware (@Validfwlist)
		{
			$x=$x+1;
			%ImageInfo = getTavorDeviceInfo("$device","$dirpath/$firmware");
			$I_ImageType = $ImageInfo{"imagetype"};
			$I_FirmVer   = $ImageInfo{"firmver"};
			$I_HardVer   = $ImageInfo{"hardrev"};
			print("$x) $dirpath/$firmware\n        (for Rev $I_HardVer, Type: $I_ImageType, Version: $I_FirmVer)\n");
		}

		# too dangerous to default
		if ($x != 0)
		{
			print "Select Firmware File (q to quit): ";
			$choice = <STDIN>;
			chomp $choice;
			$_ = $choice;

			if (/[Qq]/) {
				return 0;
			}
			if ($choice < 1 || $choice > $x) 
			{
				printf ("Invalid choice...Try again\n");
				goto START;
			} 
		}      
		$file = "$dirpath/$Validfwlist[$choice-1]";
		print LOG_FD "Select Firmware File: -> $file\n";

	} 

	if ( -e $file )
	{	
		%ImageInfo = getTavorDeviceInfo("$device","$file");
		$F_ImageType = $FlashInfo{"imagetype"};
		$F_FirmVer   = $FlashInfo{"firmver"};
		$I_ImageType = $ImageInfo{"imagetype"};
		$I_FirmVer   = $ImageInfo{"firmver"};
		$F_HardVer   = getTavorPCIHcaHardwareRevision("$device");
		$F_HardVer   = uc($F_HardVer);
		$I_HardVer   = $ImageInfo{"hardrev"};

		print("Examining ..\n");
		print("File   : " . basename($file) . " (for Rev $I_HardVer, Type: $I_ImageType, Version: $I_FirmVer)\n");
		print("Device : HCA $deviceNo (Rev $F_HardVer) Firmware: (Type: $F_ImageType, Version: $F_FirmVer)\n");
		print LOG_FD "File   : " . basename($file) . " (for Rev $I_HardVer, Type: $I_ImageType, Version: $I_FirmVer)\n";
		print LOG_FD "Device : HCA $deviceNo (Rev $F_HardVer) Firmware: (Type: $F_ImageType, Version: $F_FirmVer)\n";

		if ($F_HardVer =~ m/Invalid/ or ( $F_FirmVer =~ m/Unknown/ and $F_HardVer eq "A1" ))
		{
			print("HCA $deviceNo firmware is corrupted!  You must use the mstfwupdate tool manually.\n");
			print LOG_FD "HCA $deviceNo firmware is corrupted!  You must use the mstfwupdate tool manually.\n";
			HitKeyCont;
		} elsif ($I_HardVer =~ m/Invalid/) {
			print("The firmware file $file is corrupted!\n");
			print LOG_FD "The firmware file $file is corrupted!\n";
			HitKeyCont;
		} elsif ( "$F_ImageType" eq "Fail Safe" &&  "$I_ImageType" eq "Short" )
		{
			print("The HCA has a Fail Safe firmware ($F_FirmVer), Selected file is short image.\n");
			print LOG_FD  "The HCA has a Fail Safe firmware ($F_FirmVer), Selected file is short image.\n";
			$burn = GetYesNo("Do you wish to perform the update?", "n");
		} elsif ( $I_FirmVer =~ m/Unknown/ ) {
			print("Unable to confirm if this is a valid firmware file for HCA $deviceNo.\n");
			print LOG_FD "Unable to confirm if this is a valid firmware file for HCA $deviceNo.\n";
			$burn = GetYesNo("Do you wish to perform the update?", "y");
		} elsif ( "$F_FirmVer" ge "$I_FirmVer") {
			print("Firmware on HCA $deviceNo is up to date\n"); 
			print LOG_FD "Firmware on HCA $deviceNo is up to date\n"; 
			$burn = GetYesNo("Do you wish to perform the update?", "n");
			if ($burn) {
	            $burnoptions = "--burn-invariant";
			}
		} else {
			print("Firmware on HCA $deviceNo is out of date, performing update\n"); 
			print LOG_FD "Firmware on HCA $deviceNo is out of date, performing update\n"; 
			$burn=1;
		}

		if ($burn) {
			$res = system "mstfwupdate --no-prompts --device $device $burnoptions --burn $file";
			print LOG_FD "mstfwupdate --no-prompts --device $device $burnoptions --burn $file -> $res\n";
		}
	} else {
		print "Can not locate a valid firmware file for this HCA.\n";
		print LOG_FD "Can not locate a valid firmware file for this HCA.\n";
		HitKeyCont;
	}
	return $burn
}


# is the given driver installed on this system
sub installed_driver
{
	my($WhichDriver) = $_[0];
	$WhichDriver .= $DRIVER_SUFFIX;
	return (-e "$ROOT/lib/modules/$CUR_OS_VER/iba/$WhichDriver" );
}

sub check_depmod
{
	if ($RunDepmod == 1 )
	{
		print_separator;
		print "Generating module dependencies...\n";
		system "chroot $ROOT /sbin/depmod -aev > /dev/null 2>&1";
		$RunDepmod=0
	}
}

sub update_tavor_hca_firmware {
	my @devicelist;
	my $dirpath = "/dev/mst";
	my $choice;
	my $device;
	my $all = 0;
	my $result;
	my $rev;
	my $x;
	my $type;
	my $burnedFirmware=0;

	if ( "$ROOT" ne "/" )
	{
		# don't update firmware when building image for diskless client
		return;
	}

	#if ( ! installed_tavorhca() )
	#{
		#print("Firmware Update unnecessary\n");
		#HitKeyCont;
		#return;
	#}

START:    
	check_depmod;
	$result = system("/sbin/modprobe mst > /dev/null 2>&1");

	print("Updating HCA Firmware ...\n");
	if ($result != 0)
	{
		print "Unable to load mst driver\n";
		HitKeyCont;
		return;
	}
	print("Select HCAs to Update:\n");
	opendir(DNAME,$dirpath);
	@devicelist = grep /_pciconf/, readdir(DNAME);

	closedir(DNAME);
	$x=0;
	foreach $device (@devicelist)
	{
		$x=$x+1;
		#print "$x) $dirpath/$device\n";
		$type = substr($device, 2, 5);
		$rev = getTavorPCIHcaHardwareRevision("$dirpath/$device");
		print "$x) HCA $x ($type Rev $rev)\n";	
	}
	if ( $x == 0)
	{
	    print("No HCA device(s) found!\n");
	    HitKeyCont;
	    return;
	}

	#printf "a) Update ALL HCA devices\n";

	if ( $Default_Prompt )
	{
		$all=1;
		$choice="a";
		print "Selection (a for all, n for none) -> a\n"; 
	} else {
		print "Selection (a for all, n for none) [a]: "; 
		$choice = <STDIN>;
		chomp $choice;
		$_ = $choice;
		if (/[Nn]/) {
		    return;
		}
		if (/[Aa]/) {
		    $all=1;
		} elsif ( $choice eq "" ) {
		    $all=1;
		} elsif ($choice < 1 || $choice > $x ) {
			printf ("Invalid choice...Try again\n");
			goto START;
		} 
	}
	print LOG_FD "Select HCAs to Update: -> $choice\n";
	$x=1;
	foreach $device (@devicelist)
	{
		if ($all || $choice == $x) 
		{	
	    	$burnedFirmware |= burn_hca_firmware(substr($device,0,7),"$dirpath/$device","$x");		
		}
		$x=$x+1;
	}
	if ($burnedFirmware)
	{
	    print "\n\nAfter completing your installation and configuration changes,\n";
		print "You must reboot to activate the new firmware\n";
	    HitKeyCont;
	}
}

sub available_tavorhca
{
	return available_driver("mt23108vpd");
}

sub installed_tavorhca
{
	return installed_driver("mt23108vpd");
}

update_tavor_hca_firmware;
