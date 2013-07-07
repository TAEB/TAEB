package TAEB::World::Tile::Secretdoor;
use Moose;
use TAEB::OO;
use TAEB::Util::Colors;
extends 'TAEB::World::Tile';

has '+type' => (
    default => 'secretdoor',
);

override debug_color => sub {
    return COLOR_BROWN;
};

__PACKAGE__->meta->make_immutable;

1;
