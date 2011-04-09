package TAEB::World::Room;
use Moose;
use TAEB::OO;

has tiles => (
    is       => 'ro',
    isa      => 'ArrayRef[TAEB::World::Room]',
    weak_ref => 1, # weak because levels contain all the tiles
);

has level => (
    is       => 'ro',
    isa      => 'TAEB::World::Level',
    weak_ref => 1,
);

__PACKAGE__->meta->make_immutable;

1;

