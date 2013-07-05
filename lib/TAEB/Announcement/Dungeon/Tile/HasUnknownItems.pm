package TAEB::Announcement::Dungeon::Tile::HasUnknownItems;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon::Tile';

use constant name => 'tile_has_unknown_items';

# XXX should check if the tile really has_unknown_items
has '+tile' => (
    default => sub { die "You must provide a tile for HasUnknownItems" },
    lazy => 1,
);

__PACKAGE__->meta->make_immutable;

1;
