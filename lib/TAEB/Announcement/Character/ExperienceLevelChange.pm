package TAEB::Announcement::Character::ExperienceLevelChange;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Character';

has old_level => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has new_level => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

__PACKAGE__->meta->make_immutable;

1;
