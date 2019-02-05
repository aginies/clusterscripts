#!/usr/bin/perl

use lib '/usr/lib/libDrakX';
use strict;

BEGIN { push @::textdomains, 'drakcluster' }

use standalone;
use common;
use ugtk2 qw(:wrappers :create);
use interactive::gtk;
use cluster_commonconf;
use Data::Dumper;

require_root_capability();


my $window_splash = Gtk2::Window->new('popup');
$window_splash->signal_connect(delete_event => \&quit_global);
$window_splash->set_position('center_always');
my $filename = "/usr/share/pixmaps/cluster/drakcluster-splash.png";
my $image = Gtk2::Image->new_from_file($filename);
$window_splash->add($image);
$window_splash->show_all;
gtkflush();


use drakcluster::actions;
use drakcluster::nodes;
use drakcluster::users;
use drakcluster::server_conf_ui;
use drakcluster::pxe_conf;
use drakcluster::common;
use drakcluster::menu;
use drakcluster::help;
use interface_cluster;


my $nodes = interface_cluster::get_node_list();
my $group = interface_cluster::get_group_list();
my $partitions = interface_cluster::get_partition_list();


my $categories = { 
	group => $group,
	};

################################################################################

$::in = interactive::gtk->new;
my ($expert, $nohelp);
if ($ARGV[0] eq "expert" || $ARGV[0] eq "e") {
    $window_splash->destroy;
  $::in->ask_warn('', N("\n\tWARNING !!\n
You launch drakcluster in expert mode.

It's used to reconfigure all /etc/clusterserver.conf VAR

You can BREAK your conf !
Use with care please\n"));
  $expert = 1;
} elsif ($ARGV[0]) { $nohelp = 1 }


my $window = ugtk2->new(N("drakcluster"));
$::main_window = $window->{real_window};
$window->{rwindow}->set_size_request(675, 500);
$window->{rwindow}->set_position('center');
my $W = $window->{window};
$W->signal_connect(delete_event => sub { ugtk2->exit });


my $icon_path = "/usr/share/pixmaps/cluster";
my $node = "$icon_path/IC20-ganglia.png";
my $log = "$icon_path/IC20-xpbs.png";
my $pxeimage = "$icon_path/IC-Dhost-20.png";
my $conf = "$icon_path/IC20-drakcluster.png";
my $doc = "$icon_path/IC20-docxpbs.png";
my $help = "$icon_path/IC20-docmdkc.png";

# log tab
my $logL = Gtk2::Label->new();
$logL->set_markup('<span foreground="black"><b>System Log</b></span>');
my $command = "tail -f /var/log/messages /var/log/auth.log";
my $boxa = gtkpack_(Gtk2::VBox->new,
		   1, my $log_scroll = create_scrolled_window(my $log_w = gtkset_editable(Gtk2::TextView->new, 0)),
		   );
my $stop_running = gtktext_get_log($command, $log_w, $log_scroll, "1");

# node tab
my $box = Gtk2::VBox->new;
my $nodeL = Gtk2::Label->new();
$nodeL->set_markup('<span foreground="black"><b>Nodes</b></span>');
my $tree_view = drakcluster::nodes::create($nodes);

my $tabhelp = drakcluster::help::create();
my $hpaned = Gtk2::HPaned->new;
my $vpaned = Gtk2::VPaned->new;
$vpaned->pack1(create_scrolled_window($tree_view), 1, 0);
# don't show help in expert mode
$nohelp != "1" and $vpaned->pack2(create_scrolled_window($tabhelp), 1, 1);
$hpaned->pack1($vpaned, 0, 1);
gtkpack_($box, 1, $hpaned);
drakcluster::nodes::handle_selection_change($tree_view, $nodes, 
					    my $selection = [], my $buttons_set_sensitive = [],
                                            drakcluster::actions::popup_menus($categories),
					    );
(my $buttons, @$buttons_set_sensitive) = drakcluster::actions::create_buttons($selection);
$_->() foreach @$buttons_set_sensitive;
gtkpack_($box, 0, $buttons);


# 30000 -> 30 seconds
Glib::Timeout->add(30000, sub { drakcluster::nodes::update_nodes_up($tree_view, $nodes); 1 });


gtkappend_page(my $nb = Gtk2::Notebook->new, gtkpack_(gtkset_border_width(Gtk2::HBox->new, 0),
						      1, $box,
						      ),
               gtkshow(gtkpack_(Gtk2::HBox->new(0,0),
                                0, Gtk2::Image->new_from_file($node),
                                0, $nodeL,
				),
		       ),
               );

gtkappend_page($nb, gtkpack_(gtkset_border_width(Gtk2::HBox->new, 0),
			     1, $boxa,
		     ),
	       gtkshow(gtkpack_(Gtk2::HBox->new(0,0),
				0, Gtk2::Image->new_from_file($log),
				0, $logL,
				),
		       ),
	       );

sub add2nb {
    my ($n, $title, $image, $book) = @_;
    my $titleL = Gtk2::Label->new($title);
    $titleL->set_markup('<span foreground="black"><b>' . $title . '</b></span>');
    $n->append_page($book, gtkshow(gtkpack_(Gtk2::HBox->new(0,0),
					    0, Gtk2::Image->new_from_file($image),
					    0, $titleL,
					    ),
				   ),
		    );
    # not available :/
    #$n->set_tab_detachable($book, 0);
    $book->show;
}

# PXE
my $pxe_conf = drakcluster::pxe_conf::read();
add2nb($nb, N("PXE Configuration"), $pxeimage, drakcluster::pxe_conf::create($pxe_conf));

# server configuration if expert mode
if ($expert == 1) {
    my $server_conf = drakcluster::server_conf::read();
    add2nb($nb, N("Server Configuration"), $conf, drakcluster::server_conf_ui::create($server_conf));
}

print "you can remove help in nodes page by adding any parameter to drakcluster:
drakcluster.pl g
";

# main interface
$nb->set_show_border(0);
$W->add(gtkpack_(Gtk2::VBox->new(0,0),
                 1, $nb,
		 ),
	);

$window_splash->destroy;
$W->show_all;
Gtk2->main;
