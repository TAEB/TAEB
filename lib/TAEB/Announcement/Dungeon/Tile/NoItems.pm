package TAEB::Announcement::Dungeon::Tile::NoItems;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon::Tile';

use constant name => 'tile_noitems';

__PACKAGE__->parse_messages(
    "There is nothing here to pick up." => {},
    qr/^You (?:see|feel) no objects here\./ => {},
);

__PACKAGE__->meta->make_immutable;

1;

