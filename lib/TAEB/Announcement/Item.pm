package TAEB::Announcement::Item;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement';

has item => (
    is       => 'ro',
    isa      => 'NetHack::Item',
    required => 1,
);

__PACKAGE__->meta->make_immutable;

1;

