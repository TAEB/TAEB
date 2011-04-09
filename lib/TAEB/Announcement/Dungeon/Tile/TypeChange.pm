package TAEB::Announcement::Dungeon::Tile::TypeChange;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon::Tile';

use constant name => 'tile_type_change';

has '+tile' => (
    default => sub { die "You must provide a tile for TypeChange" },
    lazy => 1,
);

__PACKAGE__->meta->make_immutable;

1;
