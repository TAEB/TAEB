package TAEB::World::Tile::Stairsdown;
use Moose;
use TAEB::OO;
extends 'TAEB::World::Tile::Stairs';

has '+type' => (
    default => 'stairsdown',
);

has '+glyph' => (
    default => '>',
);

sub traverse_command { '>' }

__PACKAGE__->meta->make_immutable;

1;

