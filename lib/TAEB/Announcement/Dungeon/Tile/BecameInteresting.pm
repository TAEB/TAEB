package TAEB::Announcement::Dungeon::Tile::BecameInteresting;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon::Tile';

use constant name => 'tile_became_interesting';

# XXX should check if the tile really is interesting
has '+tile' => (
    default => sub { die "You must provide a tile for BecameInteresting" },
    lazy => 1,
);

__PACKAGE__->meta->make_immutable;

1;
