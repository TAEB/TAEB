package TAEB::World::Tile::Opendoor;
use Moose;
use TAEB::OO;
extends 'TAEB::World::Tile::Door';

has '+type' => (
    default => 'opendoor',
);

use constant is_locked => 0;

__PACKAGE__->meta->make_immutable;

1;

