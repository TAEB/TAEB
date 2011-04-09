package TAEB::Announcement::Report::CouldNotStart;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Report';

sub as_string { "Cannot start game; please check NetHack is working properly.\n" }

__PACKAGE__->meta->make_immutable;

1;

