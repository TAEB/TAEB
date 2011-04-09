package TAEB::Announcement::Turn;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement';

has turn_number => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

__PACKAGE__->meta->make_immutable;

1;

