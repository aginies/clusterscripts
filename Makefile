#############################################################################
# File		: Makefile
# Package	: clusterscrtips and drakcluster
# Author	: Antoine Ginies
#############################################################################

PREFIX=/usr
BINDIR=$(PREFIX)/bin
SBINDIR=$(PREFIX)/sbin
ETCDIR=/etc
PERLVENDOR=$(shell rpm -q --eval '%{perl_vendorlib}')
INITRDDIR=$(ETCDIR)/rc.d/init.d
ICONS=/usr/share/pixmaps/cluster
SHAREDOC=
#PBSPRO_HOME=/var/spool/PBS
PBS_HOME=/var/spool/pbs
DESTRPM=~/rpm
DESTRPM2=$(HOME)/mdvsys
VERSION=devel

USER=guibo
IP=localhost
#IP=10.0.1.33
SCPPORT=22

FILESCL=  *.pm *.pl clusterautosetup-client Makefile \
	clusterscripts.spec dhcpnode clusterserver.conf \
	clusternode.conf \
	dhcpd.conf.pxe.single setup_auto_cluster \
	dhcpd.conf.cluster \
        sauvegarde muttrc ldap_base.ldif sldap_cluster.conf \
	pbs_config.sample setup_test_user rapidnat prepare_diskless_image rc.sysinit_diskless

FILESDRK= drakcluster cluster_applet.pl drakka draktab_pxe draktab_config icons Makefile drakcluster.pl interface_cluster.pm art

PACKAGE=clusterscripts
PACKAGED=drakcluster
#VERSION:=$(shell rpm -q --qf %{VERSION} --specfile $(PACKAGE).spec)

VERSION_SCRIPTS=$(shell cat clusterscripts.spec | grep "%define version" | cut -d " " -f 3)
RELEASE_SCRIPTS=$(shell cat clusterscripts.spec | grep "%define release" | cut -d " " -f 3)

all: 	cleandist clean tar

clean: 	
	rm -rf *~

version: 
	@echo "$(VERSION)-$(RELEASE)"

build:
	$(MAKE) -C drakcluster/po

install: 
	mkdir -p $(DESTDIR)$(PERLVENDOR) $(DESTDIR)$(BINDIR) $(DESTDIR)$(INITRDDIR) \
	$(DESTDIR)$(ETCDIR)/X11/ $(DESTDIR)$(SBINDIR) $(DESTDIR)$(PBS_HOME)
	cp -p *.pm $(DESTDIR)$(PERLVENDOR)
	cp -p *.pl sauvegarde rapidnat prepare_diskless_image $(DESTDIR)$(BINDIR)
	# remove drakcluster.pl and interface_cluster.pm
	rm -rf $(DESTDIR)$(BINDIR)/drakcluster.pl
	rm -rf $(DESTDIR)$(BINDIR)/cluster_applet.pl
	rm -rf $(DESTDIR)$(PERLVENDOR)/interface_cluster.pm
	mv $(DESTDIR)$(BINDIR)/deluserNis.pl $(DESTDIR)$(BINDIR)/adduserNis.pl $(DESTDIR)$(SBINDIR)
	cp -p clusterautosetup-client $(DESTDIR)$(INITRDDIR)
	cp -p clusterserver.conf muttrc clusternode.conf dhcpd.conf.cluster dhcpd.conf.pxe.single rc.sysinit_diskless $(DESTDIR)$(ETCDIR)
	cp -p dhcpnode setup_test_user $(DESTDIR)$(BINDIR)
	cp -p setup_auto_cluster $(DESTDIR)$(SBINDIR)
	cp -p pbs_config.sample $(DESTDIR)$(PBS_HOME)

installd:
	mkdir -p $(DESTDIR)$(PERLVENDOR)/drakcluster $(DESTDIR)$(ICONS) $(DESTDIR)$(SBINDIR) $(DESTDIR)$(BINDIR) $(DESTDIR)$(ICONS)
	cp -p icons/* $(DESTDIR)$(ICONS)
	cp -pv art/png/drakcluster-splash.png $(DESTDIR)$(ICONS)
	cp -p drakcluster/*.pm $(DESTDIR)$(PERLVENDOR)/drakcluster
	cp -pv drakcluster.pl $(DESTDIR)$(SBINDIR)/drakcluster.pl
	cp -pv cluster_applet.pl $(DESTDIR)$(BINDIR)/cluster_applet.pl
	cp -pv draktab_pxe $(DESTDIR)$(SBINDIR)/draktab_pxe
	cp -pv draktab_config $(DESTDIR)$(SBINDIR)/draktab_config
	cp -pv drakka $(DESTDIR)$(SBINDIR)/drakka
	cp -p interface_cluster.pm $(DESTDIR)$(PERLVENDOR)/interface_cluster.pm
	$(MAKE) -C drakcluster/po install

cleandist:
	rm -rf $(PACKAGE)-$(VERSION) $(PACKAGE)-$(VERSION).tar.bz2
	rm -rf $(PACKAGED)-$(VERSION) $(PACKAGED)-$(VERSION).tar.bz2

tar:	cleandist clean
	mkdir $(PACKAGE)-$(VERSION)
	cp -av $(FILESCL) $(PACKAGE)-$(VERSION)
	mkdir $(PACKAGED)-$(VERSION)
	cp -av $(FILESDRK) $(PACKAGED)-$(VERSION)
	find $(PACKAGE)-$(VERSION)/ -name "CVS" | xargs rm -rf
	tar cvfj $(PACKAGE)-$(VERSION).tar.bz2 $(PACKAGE)-$(VERSION)
	rm -rf $(PACKAGE)-$(VERSION)
	find $(PACKAGED)-$(VERSION)/ -name "CVS" | xargs rm -rf
	tar cvfj $(PACKAGED)-$(VERSION).tar.bz2 $(PACKAGED)-$(VERSION)
	rm -rf $(PACKAGED)-$(VERSION)

comp:	tar
	cp -vf $(PACKAGE)-$(VERSION).tar.bz2 $(PACKAGED)-$(VERSION).tar.bz2 $(DESTRPM)/SOURCES
	cp -vf $(PACKAGE).spec $(PACKAGED).spec $(DESTRPM)/SPECS
	rpm -ba $(DESTRPM)/SPECS/$(PACKAGE).spec ;rpm -ba $(DESTRPM)/SPECS/$(PACKAGED).spec

mdvsys:	tar
	cp -vf $(PACKAGE)-$(VERSION).tar.bz2 $(DESTRPM2)/$(PACKAGE)/SOURCES
	cp -vf $(PACKAGED)-$(VERSION).tar.bz2 $(DESTRPM2)/$(PACKAGED)/SOURCES
	cp -vf $(PACKAGE).spec $(DESTRPM2)/$(PACKAGE)/SPECS
	cp -vf $(PACKAGED).spec $(DESTRPM2)/$(PACKAGED)/SPECS
