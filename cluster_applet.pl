#!/usr/bin/perl -w

use Gtk2::TrayIcon;
use Gtk2::NotificationBubble;
use strict;
use lib qw(/usr/lib/libDrakX);
use ugtk2 qw(:create :helpers :wrappers :dialogs);
use mygtk2 qw(gtknew);
use interactive;
use pxe_server_cluster;
use server_cluster;
use common;

my ($img, $icon, $bubble, $bubble_oar, $eventbox);
my $iconspath = "/usr/share/pixmaps/cluster";
my $d_img = "$iconspath/IC20-MDKC.png";
my $pxe_img = "$iconspath/IC32-docpxe.png";

# create needed bubble notification
sub create_bubble {
    my ($bubble_title, $text, $image, $icon) = @_;
    my $bubble = Gtk2::NotificationBubble->new();
    $bubble->attach($icon);
    $bubble->set($bubble_title, $image, $text);
    $bubble->show(3000);
    $bubble->signal_connect(clicked =>
			    sub {
			      get_info();
			    }
			   );
}

sub get_info {
  my $pxe_d = pxe_server_cluster::getDefaultLabel();
  my @node_alive = server_cluster::list_alive_node();
  my $nodeA;
  foreach (@node_alive) { $nodeA = $nodeA . $_; }
  my $text;
  if ($nodeA) {
      $text = "Default PXE boot: $pxe_d" . "\n--------\n" . "OAR Node(s) Alive:\n$nodeA";
  } else {
      $text = "Default PXE boot: $pxe_d";
  }
  create_bubble("Cluster report",
		$text,
		Gtk2::Image->new_from_file($d_img),
		$icon,
		);
}


# add mdkc icon
gtkadd($icon = Gtk2::TrayIcon->new("Cluster"),
       gtkadd($eventbox = Gtk2::EventBox->new,
              gtkpack($img = Gtk2::Image->new)
	      )
       );

$img->set_from_pixbuf(gtkcreate_pixbuf("$iconspath/IC20-MDKC.png")->scale_simple(24, 24, 'hyper'));
$icon->show_all;

# all eventbox
$eventbox->signal_connect(button_press_event => sub {
				 if ($_[1]->button == 1) {
				   get_info();
				 }
			       });

Gtk2->main;
