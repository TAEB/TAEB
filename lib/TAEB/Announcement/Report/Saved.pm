package TAEB::Announcement::Report::Saved;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Report';

augment as_string => sub { "Saved.\n" };

__PACKAGE__->meta->make_immutable;

1;

